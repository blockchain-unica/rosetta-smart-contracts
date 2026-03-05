# Editable NFT

A Cairo implementation of an ERC721 NFT contract with editable, sealable token data. Each token holds an arbitrary-length byte sequence that its owner can freely edit until the token is permanently sealed.

The contract extends OpenZeppelin's `ERC721Component` and adds two custom fields per token:

```
Token {
    data: ByteArray   // arbitrary byte data, editable by owner
    is_sealed: bool   // once true, data can never be changed
}
```

## Buy token

Mints a new token and assigns ownership to the caller.

- Increments `last_token_id` and mints token with that ID
- Initializes token with empty data and `is_sealed = false`
- Anyone can call this — no restrictions

```cairo
contract.buy_token();
// → mints token with id = last_token_id + 1, assigned to caller
```

## Set token

Sets the data field of a token.

- Caller must be the current owner of the token
- Token must not be sealed
- Data can be overwritten multiple times before sealing

```cairo
contract.set_token_data(1, "my custom data");
```

## Transfer to

Transfers ownership of a token to another address.

- Calls ERC721 `transfer_from` under the hood
- Caller must be the current owner
- Data and seal status are preserved after transfer

```cairo
contract.transfer_to(owner2_address, 1);
```

## Seal token

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

Returns the data and seal status of a token.

- Token must exist (i.e. have been minted)
- Returns `(data, is_sealed)`

```cairo
let (data, is_sealed) = contract.get_token_data(1);
```
