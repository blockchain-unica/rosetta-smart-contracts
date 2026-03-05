# Anonymous Data

## Get id

Returns the cryptographic ID for the caller, salted with the given nonce.

- Computes `keccak256(caller_address, nonce)`
- Pure view function — does not modify state
- The same caller + same nonce always produces the same ID
- Different callers with the same nonce produce different IDs

```cairo
start_cheat_caller_address(contract_addr, user);
let id = contract.get_id(42_u256);
// → u256 hash unique to (user, 42)
```

## Store data

Associates binary data with the given ID.

- `id` should be obtained via `get_id` first
- Reverts if data is already stored for that ID
- Data can be of arbitrary length
- A user can store multiple entries by using different nonces to generate different IDs

```cairo
let id = contract.get_id(42_u256);
contract.store_data("my secret data", id);
```

## Get my data

Retrieves the data previously stored under the ID derived from the caller's address and nonce.

- Internally recomputes `keccak256(caller_address, nonce)` to find the ID
- Returns empty `ByteArray` if no data was stored for that ID
- Only works for the original storing address — a different caller with the same nonce will get a different ID and see no data

```cairo
let data = contract.get_my_data(42_u256);
// → "my secret data" (if stored with nonce 42)
```
