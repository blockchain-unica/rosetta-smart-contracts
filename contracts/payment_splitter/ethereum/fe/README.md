# Payment splitter

This contract allows a user to deploy a contract setting up an array of payees and their share on the contract.

It is allowed by anyone to deposit on the contract, and the payees can then release their share of the balance present on the contract. Can only be done once per payee and payees are immutable once the contract is deployed.

## Deploy

`pub fn __init__(mut self, ctx: Context, payees: Array<address, 3>, shares_: Array<u256, 3>)`

At deploy time, the contract takes 2 arguments:

1. An array of payees
2. An array of shares

## Techical challenges

Since Fe does not support dynamic arrays, it requires the amount of payees and shares to be set permanently at deploy time, and also requires the deploy to exactly contain the exact amount of elements of said array in each array.

Otherwise, it returns a generic "custom error", suggesting that this functionality is not yet implemented completely and not capable of managing every situation.

This implies that many of the tests executed at runtime in the __init__ function become redundant, because Fe in the first place requires everything to be set up correctly, implying the tests will pass.

For example, the contract checks whether the payees match the number of shares (granted by Fe itself otherwise wouldn't compile).

Some other checks are useful and not redundant: the initialization function also calls *_addPayee()* and checks for payees to not be added twice or for theis address to be valid and their share to not be zero.

## Execution

After the contract is deployed, 10 functions can be called.

### receive()

This function accepts ETH from any user to add to the Payment Splitter balance.

### totalShares()

This function simply returns the amount of total shares of the contract.

### totalReleased()

This function simply returns the amount of ETH released in total until said moment.

### shares(account: address)

This function returns the shares of the account passed as parameter.

### released(account: address)

This function returns the amount of ETH released of the account passed as parameter.

### payee(index: u256)

This function returns the payee address given its index of the array.

### releasable(account: address)

This function calculates the amount of ETH that is releasable to the account passed as parameter.

It takes into account the shares of the account.

### release(account: address)

This function actually sends the ETH to the account based on its shares using the releasable() function. It updates the total released amounts and checks whether the account has shares, and prevents an account to get twice its quota.

### _pendingPayment(account: address, totalReceived: u256, alreadyReleased: u256)

This is a private function that just calculates the exact amount of ETH to release based on the shares and returns it to releasable() to return the right amount.

### _addPayee(account: address, totalReceived: u256, alreadyReleased: u256)

This is a private function function that is called by __init__() and adds a single payer to the Payment Splitter system by checking if they are already in the system and if their shares are set correctly, or if their address is invalid.
