# Anonymous Data in Leo (Aleo)

This is an implementation of the Anonymous Data use case on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language.

## Implementation Notes

The implementation supports the three actions described in the specification: obtaining a deterministic ID from a nonce, storing data under that ID, and retrieving stored data.

### Anonymity Through Hash Opacity, not Through Privacy

The Solidity reference uses a public mapping `mapping(bytes32 => bytes) storedData`. Anyone can read any entry; what makes the design "anonymous" is that the keys are cryptographic hashes of `(msg.sender, nonce)`. Observers see opaque `bytes32 => bytes` pairs and cannot determine which user stored which data, because they do not know the `(address, nonce)` preimage.

The Aleo implementation preserves this exact model. The data is in a public mapping, fully visible to anyone reading the chain state via REST API. What is hidden is the link between an entry and its owner. This is fundamentally different from Aleo's record system, where the data itself would be invisible to anyone except the owner.

I considered implementing the contract using records instead: each `store_data` would produce a private `DataRecord { owner, nonce, data }` that lives only in the owner's wallet. This would offer **stronger** privacy than the specification requires: not even the existence of the data would be observable. I rejected this alternative because:

1. The specification explicitly describes a model where data is "stored on-chain" and accessible via a hash.
2. The record-based design would make the data unrecoverable if the owner loses the record. The hash-indexed design lets the user re-derive their hash at any time from their address and nonce.

### Internal ID Computation: A Deviation from the Solidity Reference

The Solidity reference exposes `storeData(bytes memory data, bytes32 id)`: accepting the ID as a parameter. This is convenient but introduces a serious vulnerability: any caller can pass any `id`, including hashes computed from another user's address with a guessed nonce. 

I deviated from this pattern. In my implementation, `store_data(nonce_, data_)` accepts the nonce, not the ID. The contract computes the ID internally as `Poseidon2::hash_to_field({ addr: self.signer, nonce: nonce_ })`. Because `self.signer` is verified cryptographically by the protocol and cannot be forged, no one can write to another user's slot:

```leo
fn store_data(nonce_: field, data_: StoredData) -> Final {
    let input: HashInput = HashInput {
        addr: self.signer,
        nonce: nonce_,
    };
    let id: field = Poseidon2::hash_to_field(input);

    return final {
        assert(data_storage.contains(id) == false);
        data_storage.set(id, data_);
    };
}
```

A second deviation: the Solidity reference does not enforce the specification's own requirement that data only be stored "if data is not already associated". The reference's `storeData` overwrites existing entries silently. I added the `assert(data_storage.contains(id) == false)` check to align with what the specification actually says. To overwrite, a user must use a different nonce, producing a different ID and a different slot.

### The `get_id` Helper: Kept for Fidelity to the Specification

The specification lists `getID(nonce)` as one of the contract's three actions. In practice, the function is functionally redundant in this implementation:

- `store_data` does not need it: it computes the ID internally from `self.signer + nonce`.
- `get_my_data` does not need it: same reason.
- An off-chain client that needs the hash can compute it with the Aleo JavaScript SDK without calling the contract.

Nevertheless, I kept `get_id` in the contract as a pure helper, returning `Poseidon2::hash_to_field({ addr: self.signer, nonce })`. This preserves fidelity to the specification, which presents it as a first-class action.

### Data Field Size: `[field; 4]`

The specification calls for "binary data" of unspecified length. Leo does not support dynamic arrays, so a fixed size is required. I chose `[field; 4]`, giving approximately 124 bytes of effective capacity. This matches the convention adopted in my Editable NFT implementation and aligns with the Aleo NFT standard (ARC-721), which uses `[field; 4]` for string-like content. The encoding favours zero-knowledge proof efficiency over raw byte count: each `field` carries roughly 254 bits, more data per circuit constraint than equivalent `u8` arrays.

For applications requiring larger blobs, `[field; 8]` (~248 bytes) or `[field; 16]` (~496 bytes) extend the same scheme. In practice, on-chain storage of large binary data is impractical on any blockchain, the typical pattern is to store an off-chain URI that fits comfortably in `[field; 4]`, and keep the actual content off-chain.

### Data Retrieval: REST API, Not the Contract

The `get_my_data` function follows the same pattern used in the Decentralized Identity contract's `valid_delegate`: a `final { }` block cannot return values computed from on-chain state to the caller. To express "return the stored data if it exists", I used the `(bool, Final)` revert-as-failure pattern:

```leo
fn get_my_data(nonce_: field) -> (bool, Final) {
    let success: bool = true;
    let input: HashInput = HashInput { addr: self.signer, nonce: nonce_ };
    let id: field = Poseidon2::hash_to_field(input);

    return (success, final {
        assert(data_storage.contains(id));
    });
}
```

The caller learns "data exists" if the transaction succeeds, and "data does not exist" if it reverts. To actually retrieve the data, the client computes the hash off-chain (or calls `get_id`) and reads the mapping value directly via REST API.

### What is Public, What is Anonymous

The privacy profile of this implementation:

**Public** (visible to any observer):
- The complete mapping `data_storage`: all hash keys and all stored `StoredData` values
- The fact that someone called `store_data` or `get_my_data` at any block height

**Anonymous** (computationally hidden):
- Which address stored which entry (requires guessing or knowing the `nonce`)
- Whether two entries in the mapping belong to the same user
- The total number of entries owned by a specific address (no enumeration is possible without knowing all their nonces)

This profile is exactly what the specification requires. It is weaker than Aleo's record-based privacy (where the data itself is invisible) but stronger than naive public storage (where ownership is transparent). The trade-off is the right one when the data needs to be publicly accessible to anyone who knows the hash, but not associable to specific users by observers.

---

## Contract Design

### Structs

| Struct | Fields | Description |
|---|---|---|
| `HashInput` | `addr: address`, `nonce: field` | Internal struct used to deterministically derive an ID from the caller's address and a user-chosen nonce. |
| `StoredData` | `content: [field; 4]` | The data payload stored in the mapping. ~124 bytes of effective capacity. |

### Mappings

| Mapping | Type | Description |
|---|---|---|
| `data_storage` | `field => StoredData` | Maps anonymous IDs (hashes of `address + nonce`) to user-stored data. |

### Functions

#### `get_id(nonce_)`

Pure helper. Returns the ID that the caller would obtain for a given nonce.

| Parameter | Type | Description |
|---|---|---|
| `nonce_` | `field` | A freely chosen nonce. |

Returns: `field` — the value `Poseidon2::hash_to_field({ addr: self.signer, nonce: nonce_ })`.

On-chain checks: none (pure function, no `final { }` block).

#### `store_data(nonce_, data_)`

Stores data under the caller's anonymous ID for the given nonce. Reverts if that slot is already occupied.

| Parameter | Type | Description |
|---|---|---|
| `nonce_` | `field` | The nonce identifying the slot to write to. |
| `data_` | `StoredData` | The data to store. |

On-chain checks:
- `data_storage.contains(id) == false` (where `id` is computed internally).

#### `get_my_data(nonce_)`

Verifies that data exists at the caller's anonymous ID for the given nonce. To retrieve the actual data, the client must read the mapping value directly via REST API.

| Parameter | Type | Description |
|---|---|---|
| `nonce_` | `field` | The nonce identifying the slot to check. |

On-chain checks:
- `data_storage.contains(id)` (where `id` is computed internally).

Returns `(bool, Final)`. The `bool` is always `true` when the transaction succeeds. A revert indicates "no data found".