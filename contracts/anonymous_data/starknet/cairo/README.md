# Anonymous Data

## Storage variables

```cairo
struct Storage {
    stored_data: Map<u256, ByteArray>,
}
```

Variable that associates ID to byte array data

## Get id

```cairo
fn get_id(self: @ContractState, nonce: u256) -> u256 {
    let caller: felt252 = get_caller_address().into();
    let caller_u256: u256 = caller.into();
    keccak_u256s_be_inputs(array![caller_u256, nonce].span())
}
```

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

```cairo
fn store_data(ref self: ContractState, data: ByteArray, id: u256) {
    let existing = self.stored_data.read(id);
    assert(existing.len() == 0, Errors::ALREADY_STORED);
    self.stored_data.write(id, data);
}
```

Associates byte array with the given ID.

- Reverts if data is already stored for that ID
- Data can be of arbitrary length
- A user can store multiple entries by using different nonces to generate different IDs

```cairo
let id = contract.get_id(42_u256);
contract.store_data("my secret data", id);
```

## Get my data

```cairo
fn get_my_data(self: @ContractState, nonce: u256) -> ByteArray {
    let caller: felt252 = get_caller_address().into();
    let caller_u256: u256 = caller.into();
    let id = keccak_u256s_be_inputs(array![caller_u256, nonce].span());
    self.stored_data.read(id)
}
```

Retrieves the data previously stored under the ID derived from the caller's address and nonce.

- Internally recomputes `keccak256(caller_address, nonce)` to find the ID
- Returns empty `ByteArray` if no data was stored for that ID
- Only works for the original storing address — a different caller with the same nonce will get a different ID and see no data

```cairo
let data = contract.get_my_data(42_u256);
// → "my secret data" (if stored with nonce 42)
```
