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

