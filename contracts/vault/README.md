# Vault

## Specification

Vaults are a security mechanism to prevent cryptocurrency
from being immediately withdrawn by an adversary who has stolen
the owner's private key.
To create the vault, the owner specifies a recovery key, which can be
used to cancel a withdraw request, and a wait time that has to elapse
between a withdraw request and the actual currency transfer.
Once the vault contract have been created, anyone can deposit
native cryptocurrency.

When users want to withdraw from a vault, they must first issue a request.
The withdrawal is finalized only after the
wait time has passed since the request.
During the wait time, the request can be cancelled by using a recovery key.

## Implementations

- **Solidity/Ethereum**: the waiting time is calculated based on the current block number
However, the block timestamp can be used instead.
- **Anchor/Solana**: a step has been added for initializing the data of the vault (owner, recovery, wait time, etc.).
- **Aiken/Cardano**: the withdrawal request time, computed as the timestamp when the transaction is sent to the network by the contract's user, may differ from the one computed by the validator. Therefore, the request time is checked within a one-second tolerance threshold. 
- **PyTeal/Algorand**:
- **SmartPy/Tezos**:
- **Move/Aptos**:
