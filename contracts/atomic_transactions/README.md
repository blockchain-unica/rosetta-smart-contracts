# Atomic transactions

## Specification

This contract allows its owner to create a sequence of transactions and then execute it atomically.

In the deployment phase, the owner of the contract is set.

Once the contract is deployed, it supports the following actions:
- **addTransaction**: if the contract is not sealed, the owner adds a transaction to the sequence.
- **sealAtomicTransactions**: the owner seals the contract to avoid adding further transactions.
- **execute**: if the contract is sealed, the owner of the contract performs this action to execute the sequence of transactions atomically (if only one fails, then the entire state is restored).
Each transaction must be executed while preserving the context of the caller (the owner of the contract).
- **reset**: at any time, the contract owner performs this action to delete the sequence of transactions and remove the seal (the owner can then use the contract for another atomic sequence of transactions).

## Required functionalities
- Transaction batches
- Transaction revert
- Hash on arbitrary messages
- Versig on arbitrary messages

## Implementations
- **Solidity/Ethereum**: implementation coherent with the specification. Uses all features.
- **Anchor/Solana**: natively supported via a list of contract calls in the transaction.
- **Aiken/Cardano**:
- **PyTeal/Algorand**: not implemented, since transaction batches are natively supported by the platform.
- **SmartPy/Tezos**:
- **Move/Aptos**: not implemented, since transaction batches are natively supported by the platform.
