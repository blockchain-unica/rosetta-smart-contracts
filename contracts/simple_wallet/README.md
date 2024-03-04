# Simple Wallet

## Specification

Consider a simple wallet contract 
involving a single owner and the use 
of the blockchain's native cryptocurrency.
The contract acts as a cryptocurrency 
deposit and allows for the creation and 
execution of transactions to a specific
address. The owner can withdraw the total
amount of cryptocurrency in the balance 
at any time.


The owner initializes the contract, 
specifying the address that he intends 
to authorize. 

After contract creation, the contract 
allows four actions:
- **deposit**, the owner can deposit a 
certain amount of cryptocurrency; 
- **createTransaction**,  with which the owner can 
create a transaction by 
specifying the recipient, the value, 
and the data field;
- **executeTransaction**, with which the owner can 
execute the transaction, 
specifying the transaction ID. 
This transaction will be successful 
only if the balance of the contract 
is sufficient and if the transaction 
ID exists and has not yet been executed; 
- **withdraw**,  with which the owner can withdraw the 
balance of the contract, emptying it.

## Implementations

- **Solidity/Ethereum**: 
- **Anchor/Solana**: no byte sequence to send to the receiver during the execution of the custom transaction since the transfer instruction in Solana does not allow for the transfer of data.
- **Aiken/Cardano**: a full withdrawal operation would not preserve the covenant since an output associated with the contract would not be created. Therefore, in the withdrawal, the onwer has to leave some amount of currency in the contract.
- **PyTeal/Algorand**:
- **SmartPy/Tezos**:
- **Move/Aptos**:
