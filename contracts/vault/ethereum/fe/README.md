# Vault

This contract allows anyone to store cryptocurrency inside it, only the owner can decide to initiate a transaction towards an user. After the transaction is requested, there is a waiting time that has to pass before the transaction can be finalized. A recovery user is allowed to cancel the transaction in case the owner's private key is compromised and the transaction was not requested by the real owner.

## Technical challenges

This contract required to use States, that have been handled the same way as Escrow use case.

## Initialization

`pub fn __init__(mut self, ctx: Context, recovery_: address, wait_time_: u256)`

At deploy time the contract takes an address as recovery and a waiting time that will be the wait time to finalize the transaction.

The owner is whoever deploys the contract.

## Execution

After the contract is deployed, 4 functions can be called. There is a States system that ensures the right functions can be called at the right time.

### receive()

Anyone can send ETH to this function to store it in the vault.

### withdraw(receiver_: address, amount_: u256)

This function can only be called by the owner, and only if the current State is IDLE. Meaning that there are no other withdrawals pending in the waiting process. It is prevented to try to withdraw more than the contract balance.

### finalize()

This function can only be called by the owner of the contract, can be called only if State is REQ, meaning that there is a request pending. Also, if the waiting time is not over yet, the contract returns an error telling the user to wait for the previously planned waiting time.

### cancel()

This function can only be called by the recovery user that was set up at deploy time. Only they are able to cancel a transaction during its waiting process. This is supposed to be a backup system in case the owner's private key is compromised and a withdrawal is requested maliciously.

State must be REQ, meaning there has to be a pending transaction in order to cancel one.