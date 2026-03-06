# Editable NFT

A Cairo implementation of an ERC721 NFT contract with editable, sealable token data. Each token holds an arbitrary-length byte sequence that its owner can freely edit until the token is permanently sealed.

The contract extends OpenZeppelin's `ERC721Component` and adds two custom fields per token:

```
Token {
    data: ByteArray   // arbitrary byte data, editable by owner
    is_sealed: bool   // once true, data can never be changed
}
```

## Storage

```cairo
struct Storage {
    #[substorage(v0)]
    erc721: ERC721Component::Storage,
    #[substorage(v0)]
    src5: SRC5Component::Storage,
    last_token_id: u256,
    tokens: Map<u256, Token>,
}
```

| Field           | Type                       | Description                                                           |
| --------------- | -------------------------- | --------------------------------------------------------------------- |
| `erc721`        | `ERC721Component::Storage` | OpenZeppelin ERC721 substorage — ownership, approvals, balances       |
| `src5`          | `SRC5Component::Storage`   | Interface introspection substorage                                    |
| `last_token_id` | `u256`                     | ID of the most recently minted token — increments on each `buy_token` |
| `tokens`        | `Map<u256, Token>`         | Custom token data per token ID — data and seal status                 |

## Buy token

```cairo
fn buy_token(ref self: ContractState) {
    let caller = get_caller_address();
    let token_id = self.last_token_id.read() + 1;
    self.last_token_id.write(token_id);
    self.erc721.mint(caller, token_id);
    self.tokens.write(token_id, Token { data: "", is_sealed: false });
}
```

Mints a new token and assigns ownership to the caller.

- Increments `last_token_id` and mints token with that ID
- Initializes token with empty data and `is_sealed = false`
- Anyone can call this — no restrictions

```cairo
contract.buy_token();
// → mints token with id = last_token_id + 1, assigned to caller
```

## Set token

```cairo
fn set_token_data(ref self: ContractState, token_id: u256, data: ByteArray) {
    self._only_owner_of_token(token_id);
    let token = self.tokens.read(token_id);
    assert(!token.is_sealed, Errors::ALREADY_SEALED);
    self.tokens.write(token_id, Token { data, is_sealed: false });
}
```

Sets the data field of a token.

- Caller must be the current owner of the token
- Token must not be sealed
- Data can be overwritten multiple times before sealing

```cairo
contract.set_token_data(1, "my custom data");
```

## Transfer to

```cairo
fn transfer_to(ref self: ContractState, dest: ContractAddress, token_id: u256) {
    let caller = get_caller_address();
    self.erc721.transfer_from(caller, dest, token_id);
}
```

Transfers ownership of a token to another address.

- Calls ERC721 `transfer_from` under the hood
- Caller must be the current owner
- Data and seal status are preserved after transfer

```cairo
contract.transfer_to(owner2_address, 1);
```

## Seal token

```cairo
fn seal_token(ref self: ContractState, token_id: u256) {
    self._only_owner_of_token(token_id);
    let token = self.tokens.read(token_id);
    assert(!token.is_sealed, Errors::ALREADY_SEALED);
    self.tokens.write(token_id, Token { data: token.data, is_sealed: true });
}
```

Permanently seals a token, preventing any future edits.

- Caller must be the current owner of the token
- Token must not already be sealed
- Once sealed, `set_token_data` will always revert
- Sealing is **irreversible**

```cairo
contract.seal_token(1);
```

---

## Get token data

```cairo
fn get_token_data(self: @ContractState, token_id: u256) -> (ByteArray, bool) {
    assert(
        self.erc721.owner_of(token_id) != starknet::contract_address_const::<0>(),
        Errors::NON_EXISTENT
    );
    let token = self.tokens.read(token_id);
    (token.data, token.is_sealed)
}
```

Returns the data and seal status of a token.

- Token must exist (i.e. have been minted)
- Returns `(data, is_sealed)`

```cairo
let (data, is_sealed) = contract.get_token_data(1);
```
