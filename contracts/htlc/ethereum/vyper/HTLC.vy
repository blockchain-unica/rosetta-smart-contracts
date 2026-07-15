# pragma version ^0.4.0

MAX_REVEAL_KEY_SIZE: constant(uint256) = 64
receiver: public(address)
committer: public(address)
hashlock: public(bytes32)
deadline: public(uint256)


@payable
@deploy
def __init__(_receiver: address, _delay: uint256, _hash: bytes32):
    assert msg.value > 0, "ETH sent is zero"
    assert msg.sender != _receiver, "Committer and receiver share the same address"

    self.committer = msg.sender 
    self.receiver = _receiver
    self.deadline = block.number + _delay
    self.hashlock = _hash 


@nonreentrant 
@external
def reveal(_reveal_key: String[MAX_REVEAL_KEY_SIZE]):
    assert msg.sender == self.committer, "Only the committer"
    assert block.number < self.deadline, "Deadline reached, cannot reveal"
    assert keccak256(convert(_reveal_key, Bytes[MAX_REVEAL_KEY_SIZE])) == self.hashlock, "Invalid reveal key"
    assert self.balance > 0, "Balance is zero"

    send(self.committer, self.balance)
    assert self.balance == 0, "Transaction error"


@nonreentrant
@external
def timeout():
    assert block.number > self.deadline, "Deadline not reached"
    assert self.balance > 0, "Balance is zero"

    send(self.receiver, self.balance)
    assert self.balance == 0, "Transaction error"

