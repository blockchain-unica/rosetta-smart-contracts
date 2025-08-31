# Atomic transactions

## Specification

This contract simulates atomically-executed transaction batches for the platforms that do not natively implement this functionality.

Upon creation, the contract sets its *owner*, who is the only actor who can execute the contract actions.

Once the contract is deployed, it supports the following actions:
- **addTransaction** adds a transaction to the batch, if the batch is not already sealed.
- **sealAtomicTransactions** seals the transaction batch, preventing further transactions to be added.
- **execute** atomically executes a sealed transaction batch: if even a single transaction fails, then the state is rolled back. Each transaction must be executed while preserving the context of the caller (i.e., the contract owner).
- **reset**: deletes the current transaction batch and removes the seal, allowing the owner to use the contract for another batch.

## Required functionalities
- Dynamic arrays
- Bounded loops
- Transaction revert
- Hash on arbitrary messages
- Versig on arbitrary messages

## Implementations
- **Solidity/Ethereum**: implementation coherent with the specification. Uses all features.
- **Anchor/Solana**: not implemented, since transaction batches are natively supported via a list of contract calls in the transaction.
- **Aiken/Cardano**: not implemented, since transaction batches are natively supported by the EUTXO-model.
- **PyTeal/Algorand**: not implemented, since transaction batches are natively supported by the platform.
- **SmartPy/Tezos**:
- **Move/Aptos**: not implemented, since transaction batches are natively supported by the platform.
- **Fe/Ethereum**: dynamic arrays not supported. Not implemented, the language lacks a substitute for Solidity's delegatecall() function or is not documented.