# Upgradeable Proxy

## Specification

This use case involves three contracts:
- *Logic* implements a logic to be stored in the blockchain. 
- *TheProxy* is an upgradeable proxy that forwards a received call to
an implementation contract and returns the result to the caller. In addition, this contract
allows users to upgrade the address of the implementation contract in a secure way;
- *Caller* uses the implementation in Logic for its purposes, by calling a specific contract.
This contract allows the user to specify the address of the contract to be called.

The Logic contract provides a function *check* that returns *true* if the value of the 
balance of the address passed as an argument is lower than 100.

The three contracts are deployed in the following order: 1. *Logic*, 2. *TheProxy*, 3. *Caller*
When creating the proxy contract, the creator specifies the address of the Logic contract.

After creation, the contracts feature the following actions:
- **Caller.callLogicByProxy** allows the user to pass the address of a proxy contract.
The function forwards to the proxy a request to execute the *check* function of the Logic contract,
with the address of the Caller contract as an argument.  
- **TheProxy.upgradeTo** allows the user to pass the address of the new implementation of Logic.

## Expected Features
- Abort conditions
- (External) contract call
- Check if sender is contract
- Context-preserving call
- Dynamic data structures

## Implementations

- **Solidity/Ethereum**: the implementation is adapted from the ERC1967 Openzeppelin
implementation. It uses low-level instructions for memory access.
- **Anchor/Solana**: Solana natively supports upgradability of contracts and requires no proxy.
- **Aiken/Cardano**: cannot be implemented.
- **PyTeal/Algorand**: Algorand natively supports upgradability of contracts and requires no proxy.
- **SmartPy/Tezos**:
- **Move/Aptos**: cannot be implemented.
