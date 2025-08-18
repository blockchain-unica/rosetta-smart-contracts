# Simple Transfer

Transfer system that lets usage of a contract as a wallet.

## Initialization

`pub fn __init__(mut self, ctx: Context, _recipient: address)`

At deploy time, the contract requires **one address**. It's the address of the user that is allowed to withdraw money from the contract.

The owner of the contract (the deployer) is automatically set to be the only one who can deposit.

### Execution

After the contract is deployed, 2 functions can be called.

### deposit()

Only the owner of the contract can deposit whatever amount to the contract just by sending ETH to the contract.

#### withdraw(amount: u256)

Only the recipient that was set at deploy time can withdraw ETH from the contract (only if the contract has enough ETH to give)
