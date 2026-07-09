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
- **Scalus/Cardano**: Cardano transactions have a size limit (~16 KB), so storing large data requires splitting it across multiple UTxOs. This implementation uses the Linked List pattern to create a chain of UTxOs, each holding a chunk of the data as its datum. NFTs link the chunks together in order.
- **PyTeal/Algorand**: implementation coherent with the specification.
- **SmartPy/Tezos**: implementation coherent with the specification.
- **Move/Aptos**: implementation coherent with the specification.
- **Move/IOTA**: implementation coherent with the specification.
- **Fe/Ethereum**: dynamic arrays not supported. The implementation **does not** allow arbitrary-size byte sequences and strings.
- **Leo/Aleo**: dynamic arrays not supported. The implementation stores byte sequences and strings of up to 512 bytes each, using fixed-size arrays padded with zeros and a separate length field.