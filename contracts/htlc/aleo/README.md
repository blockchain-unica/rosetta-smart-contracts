# HTLC Contract in Leo (Aleo)

This is an implementation of the HTLC Contract on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language. For a general introduction to Leo and the Aleo execution model, refer to the Bet contract README.

## Hashing in Leo

The specification requires **Keccak-256** as the hashing algorithm. Leo supports `Keccak256::hash_to_field_raw` which takes a `[u8; 32]` array and returns a `field` value. 

- The **secret** is a fixed-length array of 32 bytes (`[u8; 32]`)
- The **hash** stored on-chain is a `field` value
- The committer must compute the hash **off-chain** before calling `initialize`, using the same algorithm that Leo uses internally

## Implementation Notes

The implementation is coherent with the specification. Deployment and initialization are separate steps, as Aleo does not support a deploy-time constructor for state initialization.

### Parameter Design

Due to the async/transition model, `collateral_` and `verifier_` must be passed explicitly as parameters in `timeout`, and `collateral_` in `reveal`, since the transfers must be initiated off-chain where storage is not readable. The `async function` then verifies these values against stored state.

### `timeout` Can Be Called by Anyone

Unlike `reveal` which checks `caller == owner`, `timeout` has no caller restriction.

### No Deadline Check in `reveal`

Following the Solidity implementation, `reveal` does check that the deadline has not passed (`block.height <= deadline`). This prevents the committer from revealing the secret after the verifier has already claimed via `timeout`.

## Contract Design

### State

| Variable | Type | Description |
|---|---|---|
| `owner` | `address` | Address of the committer. |
| `verifier` | `address` | Address that receives the collateral on timeout. |
| `hash` | `field` | Keccak256 hash of the secret. |
| `deadline` | `u32` | Block height after which timeout becomes active. |
| `collateral` | `u64` | Amount of microcredits locked in the contract. |

### Functions

#### `initialize(collateral_, delay_, verifier_, hash_)`

Called by the **committer** to lock the collateral and commit to the hash. The deadline is set to `block.height + delay_`. Can only be called once.

On-chain checks:
- `owner` must be the zero address (prevents double initialization).
- `verifier` must be the zero address (prevents double initialization).

#### `reveal(secret, collateral_)`

Called by the **committer** to reclaim the collateral by providing the preimage of the committed hash. The secret is hashed on-chain using `Keccak256::hash_to_field_raw` and compared against the stored hash.

On-chain checks:
- Caller must be the stored `owner`.
- Current block height must be ≤ `deadline`.
- `collateral_` must equal the stored `collateral`.
- `Keccak256::hash_to_field_raw(secret)` must equal the stored `hash`.

#### `timeout(collateral_, verifier_)`

Called by **anyone** after the deadline to transfer the collateral to the verifier.


On-chain checks:
- `owner` must not be the zero address (contract must be initialized).
- Current block height must be > `deadline`.
- `collateral_` must equal the stored `collateral`.
- `verifier_` must equal the stored `verifier`.