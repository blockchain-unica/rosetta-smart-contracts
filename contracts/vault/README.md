# Vault

## Specification

Vaults are a security mechanism to prevent cryptocurrency from being immediately withdrawn by an adversary who has stolen the owner's private key.

To create the vault, the owner specifies: 
- a recovery key, which can be used to cancel a withdraw request;
- a wait time, which has to elapse between a withdraw request and the actual finalization of the cryptocurrency transfer.

Once the vault contract have been created, it supports the following actions:
- **receive**, which allows anyone to deposit native cryptocurrency in the contract;
- **withdraw**, which allows the owner to issue a withdraw request to the vault, specifying the receiver and the desired amount;
- **finalize**, which allows the owner to finalize the withdraw after the wait time has passed since the request; 
- **cancel**, which allows the owner of the recovery key to cancel the withdraw request during the wait time.

## Required functionalities

- Native tokens
- Time constraints
- Transaction revert

## Implementations

- **Solidity/Ethereum**: the waiting time is based on the current block number.
- **Anchor/Solana**: a step has been added for initializing the data of the vault (owner, recovery key, wait time).
- **Aiken/Cardano**: the withdrawal request time, computed as the timestamp when the transaction is sent to the network by the contract's user, may differ from the one computed by the validator. Therefore, the  request time is checked within a one-second tolerance threshold. 
- **PyTeal/Algorand**: implementation coherent with the specification.
- **SmartPy/Tezos**: implementation coherent with the specification.
- **Move/Aptos**: implementation coherent with the specification.
