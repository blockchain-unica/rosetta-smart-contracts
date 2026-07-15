# Storage Contract in Leo (Aleo)

This is an implementation of the Storage contract on the [Aleo](https://aleo.org) blockchain, written in the [Leo](https://leo-lang.org) programming language. For a general introduction to Leo and the Aleo execution model, refer to the Bet contract README.

## Implementation Notes

The implementation **does not fully match the specification**: arbitrary-size byte sequences and strings are not supported. The contract stores byte sequences and strings of up to **512 bytes each**, by using fixed-size arrays padded with zeros and a separate length field. This limitation is inherent to Leo's type system, which requires all array sizes to be known at compile time. The situation is analogous to that of Fe/Ethereum, which documents the same limitation.

### Why Not Storage Vectors

Leo provides `storage vec: [T]`, a dynamic storage vector that supports `push`, `pop`, `len`, and `clear`. At first glance this seems like the optimal solution for our contract.

However, storage vectors cannot be used here because of **snarkVM's 32-operation limit per on-chain execution**: each `push` compiles to two `set` operations (one for the element, one for the length) plus one `get.or_use` for reading the current length. With two functions (`store_bytes` and `store_string`), the compiler counts operations statically across the entire program, and the total must stay below 32.

In practice this meant the storage-vector implementation could not go beyond 5 bytes per call before hitting the limit, making the contract effectively unusable.

### Fixed-Size Array with Length Field

To work around the limit, the contract uses a **struct** containing a fixed-size array and a separate length field:

```leo
struct ByteData {
    data: [u8; 512],
    length: u32,
}
```

Each `store_bytes` or `store_string` call performs a **single `set`** on the storage variable, the whole struct is written at once regardless of how many bytes are actually meaningful. The `length` field tracks the number of significant bytes; the rest of the array is zero padding.

### Why 512 Bytes

The choice of 512 is a compromise between Leo's declared limits and snarkVM's practical parsing behavior. Leo's type checker accepts arrays of up to 2048 elements, but in practice snarkVM's bytecode parser rejects the deployment transaction when the struct contains arrays of 1024 or more bytes. Values up to 512 were observed to deploy successfully.

This limit is well below the theoretical maximum allowed by Aleo's 128 KB transaction size, but it is the largest value that deploys reliably at the time of writing with the current toolchain.

### Client Responsibility

Because the function inputs are fixed-size `[u8; 512]` arrays, the client must pad shorter inputs with trailing zeros to fill the array and pass the actual length as a separate parameter. When reading the state, the client should only consider the first `length` bytes of the `data` field — the rest is meaningless padding.

---

## Contract Design

### State

| Variable | Type | Description |
|---|---|---|
| `byte_sequence` | `ByteData` | The stored byte sequence and its actual length. |
| `text_string` | `ByteData` | The stored string (as bytes) and its actual length. |

The `ByteData` struct contains:

| Field | Type | Description |
|---|---|---|
| `data` | `[u8; 512]` | The raw bytes, padded with zeros to fill the array. |
| `length` | `u32` | The number of significant bytes in `data`. |

### Functions

#### `store_bytes(data_, length_)`

Overwrites the `byte_sequence` storage variable with the given bytes. The input array is always 512 bytes long, with `length_` indicating how many of those bytes are significant.

On-chain checks:
- `length_` must be less than or equal to `512`.

#### `store_string(data_, length_)`

Overwrites the `text_string` storage variable with the given bytes (interpreted as a UTF-8 string). Same signature and constraints as `store_bytes`.

On-chain checks:
- `length_` must be less than or equal to `512`.