# Editable NFT in Leo (Aleo)

This is an implementation of the Editable NFT use case on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language.

## Implementation Notes

The implementation supports the four actions described in the specification: minting a new token, editing its data, transferring it to another owner, and sealing it permanently. The design leverages Aleo's record system to make every aspect of NFT ownership and content fully private by default, a substantial departure from the Solidity reference, where ownership, balances, and data are all publicly readable.

### Record-Based NFTs: Privacy by Construction

The Solidity reference inherits from OpenZeppelin's ERC-721, which maintains several public mappings: `_owners` (token id → owner address), `_balances` (owner → token count), `_tokenApprovals`, `_operatorApprovals`. The contract under test then adds its own `_tokens` mapping for custom data and `lastTokenId` as a public counter. Every read of `ownerOf(id)`, `balanceOf(addr)`, or `getTokenData(id)` returns information accessible to any observer.

In Leo I implement the NFT as a single private record:

```leo
record NFT {
    owner: address,
    id: u64,
    data: nft_data,
    sealed: bool,
}
```

The record lives in the owner's wallet and is invisible on-chain. There is no public mapping recording who owns what, no enumerable list of token IDs per address, no `ownerOf` function. The act of providing the record as input to a function is itself the cryptographic proof of ownership: only the holder of the record can spend it, verified by the protocol via the record's serial number.

The Solidity implementation, even excluding the inherited ERC-721 code, is roughly 60 lines. The Leo implementation is roughly 50 lines and is fully self-contained. The simplicity reflects an architectural difference: Solidity must simulate ownership through public state and explicit permission checks, while Leo treats records as cryptographic capabilities verified by the protocol itself.

### Sequential IDs and the `next_id` Counter

The specification states that the first minted token has `ID = 1`, the second `ID = 2`, and so on. To enforce this, the contract maintains a public counter using Leo's `storage` keyword:

```leo
storage next_id: u64;
```

The `buy` function takes an `id_proposed: u64` parameter. The client reads the current `next_id` value via the REST API, increments it by one, and passes the result as a parameter. The on-chain `final { }` block asserts that `id_proposed == next_id + 1` and then updates `next_id` to the new value. This pattern is necessary because the record must be constructed off-chain (where storage is not readable), and the new token's `id` field must be known at that point.

A race condition exists: if two clients call `buy` concurrently, both read the same `next_id`, both propose the same incremented value, but only the first transaction to land succeeds. The other reverts and must retry with the next value. This is a normal trade-off in blockchain systems and matches the behaviour of the Solidity reference, where `lastTokenId += 1` could similarly conflict between concurrent transactions.

### Considered Alternative: Hash-Based IDs

A different design would derive the token ID as `Poseidon2::hash_to_field(self.signer, nonce)` eliminating the global counter entirely. This approach has two significant advantages:

- **No race conditions**: each user has their own ID space, so concurrent mints never conflict.
- **Privacy**: the public counter `next_id` leaks the total number of NFTs minted across the entire collection. A hash-based ID reveals nothing about the collection's size.

The hash-based approach is strictly preferable in a production context where the specific ID values don't matter. I adopted the sequential counter only for fidelity to the specification, which requires `ID = 1` for the first token.

### Data Encoding: `[field; 4]` Following ARC-721

The specification describes the token data as "arbitrary long data". Leo does not support dynamic arrays, so a fixed-size representation is required. I chose `[field; 4]` for the content field:

```leo
struct nft_data {
    content: [field; 4],
}
```

This decision follows the Aleo NFT standard (ARC-721), which uses `[field; 4]` for string-like data such as metadata URIs. Each Aleo `field` is approximately 254 bits, so four fields hold roughly 124 bytes of effective data, enough for an IPFS hash, a URL, or compact metadata. This is the canonical encoding for NFT data in the Aleo ecosystem.

The standard's rationale is that `field` types are more efficient than `u8` arrays in the proving circuit: fields offer close to twice the data capacity per constraint compared to `u128`. This matters because every NFT operation generates a zero-knowledge proof, and the cost scales with the data size.

### Considered Alternative: `[u8; 256]` Byte Array

A more direct interpretation of "arbitrary byte sequence" from the specification would use `[u8; 256]`. This gives 256 bytes of capacity, more than `[field; 4]`, and is more intuitive when the data is genuinely byte-oriented. I considered this design and ultimately rejected it for two reasons: alignment with the ARC-721 standard, and a compiler bug encountered when building with `[u8; 256]`. The `[field; 4]` choice is both more idiomatic and more reliable.

For use cases requiring larger capacity, `[field; 8]` (~248 bytes) or `[field; 16]` (~496 bytes) extend the same encoding scheme.

### The Seal Mechanism

The `sealed` boolean is one-way: once `true`, it remains `true` for the lifetime of the token. The `edit` function asserts `nftRecord.sealed == false` and rejects any attempt to modify a sealed token. The `seal` function additionally asserts that the token is not already sealed, matching the explicit guard in the Solidity reference (`require(_tokens[tokenId].isSealed == false, ...)`).

Importantly, the `transfer` function does **not** check the seal state and preserves it as-is in the output record:

```leo
return NFT {
    owner: new_owner,
    id: nftRecord.id,
    data: nftRecord.data,
    sealed: nftRecord.sealed, 
};
```

A sealed NFT can be transferred between owners, but its data remains immutable for everyone.

### Relationship to ARC-721

The Aleo NFT standard ARC-721 defines a canonical structure for NFTs on Aleo, including the `data` struct, edition-based commits, public/private ownership transitions, and approval systems. This implementation **does not fully implement ARC-721** for three reasons that stem from the specification:

1. **Editable in-place data**: ARC-721 assumes immutable data per edition; modifying it requires creating a new edition with a new commit. The specification here requires direct in-place editing while keeping the same identifier.
2. **Sequential public IDs**: ARC-721 uses cryptographic commits as identifiers (opaque hashes). The specification requires sequential IDs starting from 1.
3. **No `edition` field**: the re-obfuscation pattern (used by ARC-721 to break public linkability between an NFT's old and new state) is not part of the specification.

Where compatible, I adopted ARC-721 conventions, specifically the `[field; 4]` encoding for the data content.

---

## Contract Design

### State

| Variable | Type | Description |
|---|---|---|
| `next_id` | `storage u64` | Counter of the last minted token. Default: `0`. Incremented to `1` on first mint. |

### Records

| Record | Fields | Description |
|---|---|---|
| `NFT` | `owner: address`, `id: u64`, `data: nft_data`, `sealed: bool` | Private representation of a single token. Possessing the record is proof of ownership. |

### Structs

| Struct | Fields | Description |
|---|---|---|
| `nft_data` | `content: [field; 4]` | The editable data field of an NFT. ~124 bytes of capacity, following ARC-721 conventions. |

### Functions

#### `buy(id_proposed)`

Called by **any user** to mint a new NFT. Returns a fresh `NFT` record with the caller as owner, empty data, and `sealed = false`. Increments the public `next_id` counter.

| Parameter | Type | Description |
|---|---|---|
| `id_proposed` | `u64` | The ID for the new token. Must equal `next_id + 1`. |

On-chain checks:
- `id_proposed == next_id + 1u64` (the client must propose the correct next sequential ID).

#### `edit(nftRecord, new_data)`

Called by **the owner** to modify the data of an NFT. Consumes the input record and produces a new one with updated data. Fails if the token is sealed.

| Parameter | Type | Description |
|---|---|---|
| `nftRecord` | `NFT` | The token to edit, proving ownership. |
| `new_data` | `nft_data` | The new content to store. |

On-chain checks: none.

Off-chain checks:
- `nftRecord.sealed == false`.

#### `transferTo(nftRecord, new_owner)`

Called by **the owner** to transfer the NFT to a new owner. Consumes the input record and produces a new one with the same id, data, and sealed state, but the new owner.

| Parameter | Type | Description |
|---|---|---|
| `nftRecord` | `NFT` | The token to transfer. |
| `new_owner` | `address` | The address of the new owner. |

On-chain checks: none.

Off-chain checks: none (sealed state is preserved, not blocked).

#### `seal(nftRecord)`

Called by **the owner** to permanently lock the NFT data. Consumes the input record and produces a new one with `sealed = true`.

| Parameter | Type | Description |
|---|---|---|
| `nftRecord` | `NFT` | The token to seal. |

On-chain checks: none.

Off-chain checks:
- `nftRecord.sealed == false` (sealing an already-sealed token is rejected, matching the Solidity reference).