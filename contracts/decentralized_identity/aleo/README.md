# Decentralized Identity in Leo (Aleo)

This is an implementation of the Decentralized Identity use case on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language.

## Implementation Notes

The implementation supports the four actions described in the specification, generating a new identity, changing ownership (with or without an off-chain signature), creating delegates (with or without an off-chain signature), and verifying delegate validity. Beyond the specification, this implementation offers two coexisting patterns for ownership management, exploiting Aleo's record system to provide a privacy mode that has no analogue in the Solidity reference.

### Two Coexisting Patterns: Private Records and Public Signed Operations

The Solidity reference uses a single pattern: a public `mapping(address => address) owners` records who owns each identity, and off-chain signatures (ECDSA `(v, r, s)`) authorize relayer-submitted transactions. Everything is publicly inspectable on-chain.

In Aleo, two patterns make sense and I implemented both:

The **record pattern** uses a private `IdentityRecord { owner, identity }` that lives in the owner's wallet. Operations like `change_owner` and `add_delegate` consume the record as input, and the act of providing it is itself the cryptographic proof of ownership, since only the record's holder can spend it. No public storage is touched for ownership, the operation is invisible to third-party observers.

The **signed pattern** uses the public mapping `owners: address => address` plus a `nonces` mapping for replay protection. Functions like `change_owner_signed` and `add_delegate_signed` accept an Aleo signature as a parameter and verify it against the registered owner. This pattern is necessary to support the relayer use case, where the owner authorizes an action off-chain but a third party submits the transaction.

The two patterns are alternative, not complementary. An identity that uses only the record pattern leaves no trace of its ownership in any public mapping. An identity that uses the signed pattern necessarily exposes its current owner publicly. Using the record pattern guarantees 100% privacy and takes full advantage of aleo's structure, but at the expense of allowing third parties to carry out transactions.

### Default Ownership

Following the Solidity reference, every address is implicitly the owner of itself unless explicitly reassigned. In the signed pattern this is handled by `owners.get_or_use(identity_, identity_)`, if no entry exists for an identity, the function defaults to the identity itself as owner. This means a user can immediately sign and authorize operations on their own identity without any prior setup.

### Signature Scheme: Aleo Schnorr, not Ethereum ECDSA

The Solidity reference uses ECDSA on secp256k1 , and signatures are represented as the triple `(v, r, s)`. The contract recovers the signer's address from a signed message hash via `ecrecover(hash, v, r, s)`.

Aleo uses a Schnorr-style signature scheme on BLS12-377. Leo exposes this as a native `signature` type with a `signature::verify(sig, address, message)` function. The cryptographic primitive is fundamentally different, but the semantics for the application layer are identical: "verify that this signature was produced by the holder of the private key corresponding to the address, over this specific message hash". Anyone wanting to sign for this contract must use an Aleo private key.

### Message Construction: Typed Structs, not Raw Byte Concatenation

The Solidity reference constructs message hashes via `keccak256(abi.encodePacked(...))`, concatenating raw bytes of the message components. In Leo I use a different approach: each signed operation has its own Leo struct containing all the message fields, and the struct is passed directly to signature::verify. Leo handles the canonical serialization and hashing of the struct internally as part of the verification, so no explicit pre-hashing step is needed.

The two message structs are:

```leo
struct ChangeOwnerMessage {
    contract_address: address,
    operation: field,
    nonce: u64,
    identity: address,
    new_owner: address,
}

struct AddDelegateMessage {
    contract_address: address,
    operation: field,
    nonce: u64,
    identity: address,
    delegate_type: field,
    delegate: address,
    validity: u32,
}
```

 `contract_address` (set to `self.address`) prevents a signature made for one deployment from being valid on another. `operation` (a `field` constant `CHANGE_OWNER = 1field` or `ADD_DELEGATE = 2field`) prevents a signature made for `change_owner` from being reusable for `add_delegate`. `nonce` (read from the `nonces` mapping for the current owner) prevents replay of the same operation, and is incremented after each successful signed operation. The remaining fields carry the operation's data.


### Replay Protection

The `nonces` mapping tracks how many signed operations each owner has authorized. The mapping is indexed by **owner**. An owner who controls multiple identities has a single global nonce that advances with every signed operation across all their identities. This is acceptable because the message struct also includes `identity` and `operation`, which together with the nonce uniquely identify each signed message.


### The Delegates Mapping: Publicly Verifiable but Not Enumerable

The mapping `delegates: field => u32` stores delegate validity entries. The key is **not** the raw tuple `(identity, delegate_type, delegate)`, instead it is `Poseidon2::hash_to_field(IdentityDelegateKey { identity, delegate_type, delegate })`. The value is the absolute block height until which the delegation is valid.

This has an interesting privacy property. An observer who reads the `delegates` mapping sees only opaque `field` keys mapped to block heights. They cannot decode "which identity has which delegate of which type" from the mapping alone. To verify a specific delegation, you must already know the triple `(identity, delegate_type, delegate)`, at that point you can recompute the hash and check the entry.


### The `valid_delegate` Function: Revert as "False"

The specification's `validDelegate` returns a `bool`. In Leo, a function's `final { }` block cannot return values computed from on-chain state, it can only execute effects. To implement a function that "returns true if the delegate is valid", I use the same pattern as in the Upgradeable Proxy's `logic.aleo`: return `(bool, Final)` where the `bool` is always `true` off-chain, and an assertion inside the `final { }` block enforces the actual condition. The semantics are:

- If the delegate is valid: the transaction succeeds and the caller receives `true`.
- If the delegate is invalid or expired: the assertion fails and the entire transaction reverts.

A caller can interpret a reverted transaction as a `false` result.

### Records and `final { }`: An Important Constraint

When a function takes a record as input and also has a `final { }` block, the record's fields cannot be accessed inside the `final` block. Records are private off-chain entities; the `final` block executes on-chain. The two contexts are separated by design in Aleo's privacy model.

In `add_delegate`, the field `identityRecord.identity` is extracted into a local variable before the `final` block:

```leo
let identity_value: address = identityRecord.identity;

return (identityRecord, final {
    // identity_value is used here instead of identityRecord.identity
});
```

This does not compromise privacy. The value is extracted in the off-chain transition body, where the record's fields are accessible to the caller. Only the final hash of the delegate key is written to the public mapping, the original `identity` value is never exposed on-chain in clear form.

---

## Contract Design

### Constants

| Constant | Value | Description |
|---|---|---|
| `CHANGE_OWNER` | `1field` | Operation tag for `change_owner_signed` messages. |
| `ADD_DELEGATE` | `2field` | Operation tag for `add_delegate_signed` messages. |

### Records

| Record | Fields | Description |
|---|---|---|
| `IdentityRecord` | `owner: address`, `identity: address` | Private proof of identity ownership. |

### Structs

| Struct | Purpose |
|---|---|
| `ChangeOwnerMessage` | Message format for ownership change signatures. |
| `AddDelegateMessage` | Message format for delegate creation signatures. |
| `IdentityDelegateKey` | Composite key for the `delegates` mapping. |

### Mappings

| Mapping | Type | Description |
|---|---|---|
| `owners` | `address => address` | identity → current owner. Default: identity itself. |
| `nonces` | `address => u64` | owner → signed operations counter. Default: `0`. |
| `delegates` | `field => u32` | `Poseidon2(identity, delegate_type, delegate)` → expiry block height. |

### Functions

#### `generate_identity()`

Called by **any user** to obtain a fresh `IdentityRecord` where they are both owner and identity. No on-chain state is touched.

#### `change_owner(identityRecord, new_owner)`

Called by **the current owner** to transfer ownership of an identity. Consumes the input record and produces a new one with the updated owner. Fully private — no mapping is touched.

| Parameter | Type | Description |
|---|---|---|
| `identityRecord` | `IdentityRecord` | The owner's record, proving ownership. |
| `new_owner` | `address` | The new owner address. |

On-chain checks: none (record consumption is itself the proof of ownership).

#### `change_owner_signed(identity_, new_owner_, sig_)`

Can be called by **anyone** carrying a valid signature from the current owner. Verifies the signature and updates the public `owners` mapping.

| Parameter | Type | Description |
|---|---|---|
| `identity_` | `address` | The identity to update. |
| `new_owner_` | `address` | The new owner. |
| `sig_` | `signature` | Owner's signature over the `ChangeOwnerMessage`. |

On-chain checks:
- `signature::verify(sig_, current_owner, message)` must succeed.

#### `add_delegate(identityRecord, delegate_type_, delegate_, validity_)`

Called by **the current owner** to add a delegate to an identity. Uses the record to prove ownership and updates the public `delegates` mapping.

| Parameter | Type | Description |
|---|---|---|
| `identityRecord` | `IdentityRecord` | The owner's record. |
| `delegate_type_` | `field` | Application-defined delegate type identifier. |
| `delegate_` | `address` | The address being granted delegate authority. |
| `validity_` | `u32` | Number of blocks for which the delegation is valid. |

On-chain checks: none (record consumption is itself the proof of ownership).

#### `add_delegate_signed(identity_, delegate_type_, delegate_, validity_, sig_)`

Can be called by **anyone** carrying a valid signature from the current owner. Verifies the signature and updates the `delegates` mapping.

| Parameter | Type | Description |
|---|---|---|
| `identity_` | `address` | The identity. |
| `delegate_type_` | `field` | Application-defined delegate type. |
| `delegate_` | `address` | The delegate. |
| `validity_` | `u32` | Validity duration in blocks. |
| `sig_` | `signature` | Owner's signature over the `AddDelegateMessage`. |

On-chain checks:
- `signature::verify(sig_, current_owner, message)` must succeed.

#### `valid_delegate(identity_, delegate_type_, delegate_)`

Verifies that a specific delegation is currently active.

| Parameter | Type | Description |
|---|---|---|
| `identity_` | `address` | The identity. |
| `delegate_type_` | `field` | The delegate type. |
| `delegate_` | `address` | The delegate. |

On-chain checks:
- `delegates[Poseidon2(IdentityDelegateKey)] > block.height` must hold. If false, the transaction reverts.

Returns `(bool, Final)`. The `bool` is always `true` when the transaction succeeds.