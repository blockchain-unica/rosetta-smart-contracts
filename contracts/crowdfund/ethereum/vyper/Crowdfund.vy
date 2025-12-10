# pragma version ^0.4.0

recipient: public(address)
goal: public(uint256)
deadline: public(uint256)
donations: public(HashMap[address, uint256])
has_withdrawn: public(bool)

@deploy
def __init__(_recipient: address, _goal: uint256, duration: uint256):
    assert _recipient != empty(address), "Invalid recipient"
    assert _goal > 0, "Goal must be positive"
    assert duration > 0, "Duration must be positive"
    
    self.recipient = _recipient
    self.goal = _goal
    self.deadline = block.timestamp + duration
    

@payable
@external
def donate():
    assert msg.value > 0, "Invalid amount"
    assert self.deadline > block.timestamp, "Deadline reached"

    self.donations[msg.sender] += msg.value 


@nonreentrant
@external
def withdraw():
    assert msg.sender == self.recipient, "Only the recipient"
    assert self.deadline < block.timestamp, "Deadline not reached yet"
    assert not self.has_withdrawn, "Cannot withdraw twice"
    assert self.balance >= self.goal, "Goal not reached, cannot withdraw"
    self.has_withdrawn = True

    send(self.recipient, self.balance)


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

    
