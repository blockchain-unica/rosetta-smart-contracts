# Storage

## Specification

The contract Storage allows a user to 
store inside the blockchain two 
typologies of dynamic size data: 
a byte sequence and a string.

After contract creation, the contract 
allows two actions:
- **storeBytes**, which allows the user
to store an arbitrary 
sequence of bytes (1 to 5 bytes, 128 bytes);
- **storeString**, which allows the user 
to store a string of arbitrary 
length (1 to 5 simple characters, 128 simple characters).


## Expected Features

- Dynamic data structures
- Bitstring operations

## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: a step has been added for initializing storage accounts.
- **Aiken/Cardano**: implementation coherent with the specification.
- **PyTeal/Algorand**: implementation coherent with the specification.
- **SmartPy/Tezos**: implementation coherent with the specification.
- **Move/Aptos**: implementation coherent with the specification.
