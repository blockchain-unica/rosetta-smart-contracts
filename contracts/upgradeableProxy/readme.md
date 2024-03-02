# Upgradeable Proxy

## Specification

This use case involves three contracts:
- *Logic* implements a logic to be stored in the blockchain;
- *TheProxy* is an upgradeable proxy that forwards a received call to
an implementation contract and returns the result to the caller. In addition, this contract
allows users to upgrade the address of the implementation contract in a secure way;
- *Caller* uses the implementation in Logic for its purposes, by calling a specific contract.
This contract allows the user to specify the address of the contract to be called.

The three contracts are deployed in the following order: 1. *Logic*, 2. *TheProxy*, 3. *Caller*
When creating the proxy contract, the creator specifies the address of the Logic contract.

After creation, the contracts feature the following actions:
- **Caller.callLogicByProxy** allows the user to pass the address of the proxy and to execute
the logic inside the Logic contract. In particular, the function *check* of the Logic contract
returns *true* if the balance of the contract passed as an argument is lower than 100.
- **TheProxy.upgradeTo** allows the user to pass the address of the new implementation of Logic.

The Solidity implementation uses low-level instructions for memory access.
The Solidity reference implementation in this use case is adapted from the ERC1967 Openzeppelin
implementation.

## Implementations

- **Solidity/Ethereum**: 
- **Rust/Solana**:
- **Aiken/Cardano**:
- **PyTeal/Algorand**:
- **SmartPy/Tezos**:
- **Move/Aptos**:
