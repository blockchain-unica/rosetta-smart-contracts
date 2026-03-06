# Storage

## Cairo `ByteArray`

`ByteArray` is Cairo’s native type for variable-length byte data.

It is equivalent to Solidity’s:

| Solidity | Cairo       |
| -------- | ----------- |
| `bytes`  | `ByteArray` |
| `string` | `ByteArray` |

This allows the contract to store:

- raw byte sequences
- UTF-8 encoded text strings

## Storage vars

```cairo
struct Storage {
    byte_sequence: ByteArray,  // mirrors: bytes public byteSequence
    text_string: ByteArray,    // mirrors: string public textString
}
```

| Field           | Type        | Description                                       |
| --------------- | ----------- | ------------------------------------------------- |
| `byte_sequence` | `ByteArray` | Arbitrary byte data — updated by `store_bytes`    |
| `text_string`   | `ByteArray` | Arbitrary text string — updated by `store_string` |

## Constructor

```cairo
fn constructor(ref self: ContractState) {}
```

The contract does not require initialization parameters.

When deployed:

- Both storage fields are initialized as **empty byte arrays**.

## Store Bytes

```cairo
fn store_bytes(ref self: ContractState, byte_sequence: ByteArray) {
    self.byte_sequence.write(byte_sequence);
}
```

Stores an arbitrary byte sequence in the contract.

Example usage:

```cairo
storage.store_bytes(bytes_data)
```

This overwrites any previously stored value.

## Store String

```cairo
fn store_string(ref self: ContractState, text_string: ByteArray) {
    self.text_string.write(text_string);
}
```

Stores a text string (UTF-8 encoded) in the contract.

Example usage:

```cairo
storage.store_string("Hello Starknet")
```
