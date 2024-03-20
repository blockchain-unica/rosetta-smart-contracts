# Anonymous Data

## Specification

This smart contract is designed to implement the recording of personal data anonymously.

The Producer generates data that must be associated with a user anonymously (without using his address) so that only the
user knows that the data belongs to him.
The user owns his address but must never reveal it.
Through the smart contract, the user generates an ID (a hash of its address "salted" with a nonce long as desired).
The user communicates off-chain the ID to the Producer.
The Producer will associate on-chain the produced data with the user ID.

The user will always be able to read the data by reconstructing the ID via the nonce and without a transaction 
being validated in blockchain. The manufacturer will be able to access all data stored in the contract anonymously.

NOTE: A possible attacker can obtain the data of a user if he knows his address and nonces.


In this use case, we define two actors: User, Producer
After creation, the following sequence of actions is possible:
- **Create ID**. Actor: Owner1.
-  ...

## Expected Features

- Abort conditions
- Hash
- Dynamic data structures


## Implementations

- **Solidity/Ethereum**: 
- **Anchor/Solana**: 
- **Aiken/Cardano**:
- **PyTeal/Algorand**:
- **SmartPy/Tezos**:
- **Move/Aptos**:
