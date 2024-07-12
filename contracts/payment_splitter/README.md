# Payment Splitter

## Specification

This contract allows to split Ether payments among a group of accounts. The sender does not need to be aware that the Ether will be split in this way, since it is handled transparently by the contract. 

The split can be in equal parts or in any other arbitrary proportion. The way this is specified is by assigning each account to a number of shares. 
Of all the Ether that this contract receives, each account will then be able to claim an amount proportional to the percentage of total shares they were assigned. 
The distribution of shares is set at the time of contract deployment and can't be updated thereafter. 

PaymentSplitter follows a pull payment model. This means that payments are not automatically forwarded to the accounts but kept in this contract, and the actual transfer is triggered as a separate step by calling the release() function.


## Expected Features

- Asset transfer
- Abort conditions
- (External) contract call
- Dynamic data structures

## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: a step has been added for initializing the data of the contract (payees, shares, released amounts, etc.). 
- **Aiken/Cardano**:
- **PyTeal/Algorand**:
- **SmartPy/Tezos**:
- **Move/Aptos**:
