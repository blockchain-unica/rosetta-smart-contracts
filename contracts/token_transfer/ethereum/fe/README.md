# Token Transfer

Transfer system that supports ERC20 tokens.

## Functionality

This use case requires 2 contracts, ERC20 and TokenTransfer.

## Contract ERC20

This contract is the ERC20 gatekeeper, keeping track of who owns tokens and how much.

## Initialization

`pub fn __init__(mut self, ctx: Context)`

At deploy time, the contract initializes its own balance.

### Execution

After the contract is deployed, 4 functions can be called.

#### addAccount(account: address)

This function lets add a new account (address) to the system, with a default amount of tokens equal to zero.

#### mint(recipient: address, amount: u256)

This function emits new tokens to the recipient.

#### balanceOf(account: address)

Returns the balance of the account in ERC20.

#### transfer(from: address, to: address, amount: u256)

Transfers ERC20 in said amount from sender to recipient.

## Contract TokenTransfer

This contract allows exchange of ERC20 tokens by depositing inside itself and withdrawing from itself.

## Initialization

`pub fn __init__(mut self, ctx: Context, _recipient: address, _token_address : address)`

At deploy time, the contract requires the recipient address, the ERC20 contract address. The owner is taken from context.

### Execution

After deploy, 2 functions can be called.

#### deposit(amount: u256)

Only the owner can deposit ERC20 inside the contract through amount parameter, and only if they have enough available.

### withdraw(amount: u256)

Only the receiver can call this function. It gives the token to the recipient based on the parameter amount and only if there is enough available.