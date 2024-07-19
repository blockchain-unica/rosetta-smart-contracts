# Simple Wallet

## Specification

The SimpleWallet contract acts as a native cryptocurrency deposit, and it allows for the creation and execution of transactions to a specific address. 
The owner can withdraw the total amount of cryptocurrency in the balance at any time.

The owner initializes the contract by specifying the address that they want to authorize. 

After contract creation, the contract supports the following actions:
- **deposit**, which allows the owner to deposit any amount of native cryptocurrency; 
- **createTransaction**, which allows the owner to create a transaction. The transaction specifies its recipient, value, and a data field;
- **executeTransaction**, which allows the owner to execute the transaction, specifying the transaction ID. This transaction will be successful only if the contract balance is sufficient and if the transaction ID exists and has not yet been executed; 
- **withdraw**, which allows the owner to withdraw the entire contract balance.

## Required functionalities

- Native tokens
- Transaction revert
- Dynamic arrays

## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: no byte sequence to send to the receiver during the execution of the custom transaction since the transfer instruction in Solana does not allow for the transfer of data.
- **Aiken/Cardano**: a full withdrawal operation would not preserve the covenant since an output associated with the contract would not be created. Therefore, in the withdrawal, the onwer has to leave some amount of currency in the contract.
- **PyTeal/Algorand**: implementation coherent with the specification.
- **SmartPy/Tezos**: use of an 'emit' for the transaction ID.
- **Move/Aptos**: implementation coherent with the specification.
