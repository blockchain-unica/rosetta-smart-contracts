# Atomic transactions

## Specification

The *Atomic Transactions* contract allows the owner of the contract
to create a sequence of transactions and then execute it 
atomically.
In the deployment phase, the owner of the contract is set.

Once deployed, the following actions are possible:
- **addTransaction**: if the contract is not sealed, the owner adds
a transaction to the sequence.
- **sealAtomicTransactions**: the owner seals the contract to avoid 
adding further transactions.
- **execute**: if the contract is sealed, the owner of the contract
performs this action to execute the sequence of transactions
atomically (if only one fails, then the entire state is restored).
Each transaction must be executed while preserving the context of the caller (the owner of the contract).
- **reset**: at any time, the contract owner performs this action
to delete the sequence of transactions and remove the seal
(the owner can then use the contract for 
another atomic sequence of transactions).