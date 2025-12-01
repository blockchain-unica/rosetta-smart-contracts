# Crowdfund in Vyper

## State variables

```py
recipient: public(address)
goal: public(uint256)
deadline: public(uint256)
donations: public(HashMap[address, uint256])
has_withdrawn: public(bool)
```
- `donations` — tracks the amount donated by each address. If the target is not reached before deadline, users can reclaim their money.
- `has_withdrawn` — marks whether the recipient has already withdrawn funds. Prevents multiple withdrawals.

## Initialization

```py
def __init__(_recipient: address, _goal: uint256, duration: uint256):
    assert _recipient != empty(address), "Invalid recipient"
    assert _goal > 0, "Goal must be positive"
    assert duration > 0, "Duration must be positive"
    
    self.recipient = _recipient
    self.goal = _goal
    self.deadline = block.timestamp + duration
```

The **__init__** function is run after the contract is deployed and initializes the state of the contract. This function checks:
- the recipient is a valid address (`_recipient != empty(address)`)
- the goal to be positive
- the duration to be positive

> **Note**: In Vyper `empty(address)` is the same as `0x0000000000000000000000000000000000000000`, the zero address.

## donate

```py
@payable
@external
def donate():
    assert msg.value > 0, "Invalid amount"
    assert self.deadline > block.timestamp, "Deadline reached"

    self.donations[msg.sender] += msg.value
```

The **donate** function allows any user to contribute ETH to the crowdfunding campaign (**@payable**). If:
- the `msg.value` of the transaction is greater than zero
- and the call happens before the deadline

the function does not reverts, and the contributed amount is added to the sender’s cumulative total stored in `self.donations[msg.sender]`.

## withdraw

```py
@nonreentrant
@external
def withdraw():
    assert msg.sender == self.recipient, "Only the recipient"
    assert self.deadline < block.timestamp, "Deadline not reached yet"
    assert not self.has_withdrawn, "Cannot withdraw twice"
    assert self.balance >= self.goal, "Goal not reached, cannot withdraw"
    self.has_withdrawn = True

    send(self.recipient, self.balance)
```

The **withdraw** function transfers the contract’s full balance to the designated recipient once the crowdfunding campaign has successfully concluded.
Because this function handles fund transfers, it is protected with **@nonreentrant** to prevent reentrant withdrawal attacks.

Requirements:
- The caller must be the recipient
- Current timestamp must be after the deadline
- Goal must be met or exceeded
- Must not have withdrawn before

When all conditions are satisfied:
- `has_withdrawn` is set to True to prevent future withdrawals.
- The entire contract balance is sent to `self.recipient`.


## reclaim

 ```py
@nonreentrant
@external
def reclaim():
    assert not msg.sender == self.recipient, "Only donors"
    assert self.deadline < block.timestamp, "Deadline not reached yet"
    assert self.balance < self.goal, "Goal reached, cannot reclaim"    

    amount: uint256 = self.donations[msg.sender] 
    assert amount > 0, "Nothing to reclaim"

    self.donations[msg.sender] = 0
    send(msg.sender, amount)
 ```

The **reclaim** function allows donors to retrieve their contributions if the crowdfunding campaign fails to reach its funding goal.

Requirements:
- Caller must not be the recipient
- The deadline must have passed
- The goal must not be reached
- The caller must have a non-zero recorded donation

When these conditions apply:
- The donor recorded contribution is set to zero
- The contract sends to the donor the exact amount they contributed.


## Differences between the Vyper and Solidity implementations

Implementation is similar to Solidity.
