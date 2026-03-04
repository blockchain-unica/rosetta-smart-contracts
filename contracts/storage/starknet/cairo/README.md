# Storage

# Cairo `ByteArray`

`ByteArray` is Cairo’s native type for variable-length byte data.

It is equivalent to Solidity’s:

| Solidity | Cairo       |
| -------- | ----------- |
| `bytes`  | `ByteArray` |
| `string` | `ByteArray` |

This allows the contract to store:

- raw byte sequences
- UTF-8 encoded text strings

## Constructor

```cairo
#[constructor]
fn constructor(ref self: ContractState) {}
```

The contract does not require initialization parameters.

When deployed:

- Both storage fields are initialized as **empty byte arrays**.

## Store Bytes

```cairo
fn store_bytes(byte_sequence: ByteArray)
```

Stores an arbitrary byte sequence in the contract.

Example usage:

```cairo
storage.store_bytes(bytes_data)
```

This overwrites any previously stored value.

## Store String

```cairo
fn store_string(text_string: ByteArray)
```

Stores a text string (UTF-8 encoded) in the contract.

Example usage:

```cairo
storage.store_string("Hello Starknet")
```
