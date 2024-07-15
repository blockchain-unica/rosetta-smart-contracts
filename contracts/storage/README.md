# Storage

## Specification

The Storage contract allows a user to store on-chain byte sequences and strings (of arbitrary size).  

After contract creation, the contract supports two actions:
- **storeBytes**, which allows the user to store an arbitrary sequence of bytes (1 to 5 bytes, 128 bytes);
- **storeString**, which allows the user to store a string of arbitrary length (1 to 5 simple characters, 128 simple characters).

## Required Features

- Dynamic data structures
- Bitstring operations

## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: a step has been added for initializing storage accounts.
- **Aiken/Cardano**: implementation coherent with the specification.
- **PyTeal/Algorand**: implementation coherent with the specification.
- **SmartPy/Tezos**: implementation coherent with the specification.
- **Move/Aptos**: implementation coherent with the specification.
