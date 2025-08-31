# Storage

## Specification

The Storage contract allows a user to store on-chain byte sequences and strings (of arbitrary size).  

After contract creation, the contract supports two actions:
- **storeBytes**, which allows the user to store a sequence of bytes of arbitrary lenght;
- **storeString**, which allows the user to store a string of arbitrary length.

## Required functionalities

- Dynamic arrays

## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: a step has been added for initializing storage accounts.
- **Aiken/Cardano**: implementation coherent with the specification.
- **PyTeal/Algorand**: implementation coherent with the specification.
- **SmartPy/Tezos**: implementation coherent with the specification.
- **Move/Aptos**: implementation coherent with the specification.
- **Move/IOTA**: implementation coherent with the specification.
- **Fe/Ethereum**: dynamic arrays not supported. The implementation **does not** allot arbitrary size of byte sequences and strings.