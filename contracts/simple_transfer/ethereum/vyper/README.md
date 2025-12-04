# Simple transfer

## State variables

```py
owner: public(address) 
recipient: public(address)
```
- `owner` — the address allowed to deposit ETH into the contract.
- `recipient` — the address allowed to withdraw funds from the contract.

These two roles are fixed at deployment and determine who controls deposits and withdrawals.

## Initialization

```py 
@deploy
def __init__(recipient: address):
    self.owner = msg.sender
    self.recipient = recipient
```
This constructor sets the contract participants:
- `owner` is automatically set to the deployer (`msg.sender`).
- `recipient` is passed as a parameter.

## deposit

```py
@payable
@external
def deposit():
    assert msg.sender == self.owner, "Only the owner"
    assert msg.value > 0, "Invalid amount"
```
This **payable** function allows the owner to send ETH into the contract.
Since value transfer is done automatically, the function only verifies two conditions: 
- The caller is the designated owner
- The `msg.value` is strictly greater than zero.

## withdraw

```py
@nonreentrant 
@external
def withdraw(amount: uint256):
    assert msg.sender == self.recipient, "Only the recipient can withdraw"
    assert amount <= self.balance, "Insufficient balance"

    send(self.recipient, amount)
```
This **external non-reentrant** function transfer ETH to the recipient. It ensures:
- Only the `recipient` can call this function.
- The requested withdrawal amount does not exceed the contract balance.

## Differences between the Vyper and Solidity implementations

Implementation is similar to Solidity.

