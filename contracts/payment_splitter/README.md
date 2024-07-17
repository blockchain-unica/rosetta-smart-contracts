# Payment Splitter

## Specification

This contract allows to split (native) cryptocurrency payments among a group of users. The split can be in equal parts or in any other arbitrary proportion. The way this is specified is by assigning each account to a number of shares. 

At deployment, the contract creator specifies the set of users who will receive the payments and the corresponding number of shares. The set of shareholders and their shares cannot be updated thereafter. 

After creation, the contract supports the following actions:
- **receive**, which allows anyone to deposit cryptocurrency units in the contract;
- **release**, which allows anyone to distribute the contract balance to the shareholders. Each shareholder will receive an amount proportional to the percentage of total shares they were assigned. The contract follows a pull payment model: this means that each shareholder will receive the corresponding amount in a separate call to the release function.

## Required functionalities

- Native tokens
- Transaction revert
- Key-value maps
- Bounded loops

## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: a step has been added for initializing the data of the contract (payees, shares, released amounts, etc.). 
- **Aiken/Cardano**:
- **PyTeal/Algorand**:
- **SmartPy/Tezos**:
- **Move/Aptos**:
