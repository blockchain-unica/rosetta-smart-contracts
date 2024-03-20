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

## Expected Features

- Abort conditions
- Transaction batches
- Hash
- Versig on arbitrary messages

## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification. Uses all features.
- **Anchor/Solana**: natively supported via a list of contract calls in the transaction.
- **Aiken/Cardano**:
- **PyTeal/Algorand**:
- **SmartPy/Tezos**:

// qui sotto una ipotesi di formato più strutturato per ogni piattaforma.
// Pro: le feature usate nella tal piattaforma sono in forma di elenco (un sottoinsieme di quelle in cima a questo file)
// Contro: per spiegare come mai si sono usate certe e non altre bisogna cmq ricorrere ad una riga di commento che spieghi in inglese discorsivo le scelte e le motivazioni fatte.
// Allora a questo punto, perché non lasciare solamente una riga di commento libero ma che spiega tutto per bene?

- **Move/Aptos**:
        *Features*: Transaction batches, Versig on arbitrary messages.
		*Comment*: atomic transactions are natively supported by the Aptos framework API.
