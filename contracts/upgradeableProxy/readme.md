# Upgradeable Proxy

## Specification

In this Use Case, three contracts and a user are involved.
The contract *Logic* implements a logic to be stored in the blockchain.
The contract *TheProxy* is an upgradeable proxy that forwards a received call to
an implementation contract and returns the result to the caller. In addition, this contract
allows for the upgrade of the address of the implementation in a secure way.
The contract *Caller* makes use of the implementation in Logic for its purposes.
To do it, the contract Caller must include a call instruction to a specific contract.
This contract allows the user to specify the address of the contract to be called.

The user must deploy the contracts in the order: 1. *Logic*, 2. *TheProxy*, 3. *Caller*
At the time of the proxy's creation, the user specifies the address of the Logic contract.

After contracts creation, the contract Caller allows an action:
- **callLogicByProxy**, which allows the user to pass the address of the proxy and to execute
the logic inside the Logic contract. In particular, the function *check* of the Logic contract
returns *true* if the balance of the contract passed as an argument is lower than 100.

The contract TheProxy allows an action:
- **upgradeTo**, which allows the user to pass the address of the new implementation of Logic.

NOTE:The Solidity implementation makes use of low-level instructions for memory accessing.
The solidity reference implementation in this use case is adapted from the ERC1967 Openzeppelin
implementation.

## Execution traces
