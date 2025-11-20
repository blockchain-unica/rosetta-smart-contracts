# pragma version ^0.4.0

ZERO_ADDR: constant(address) = 0x0000000000000000000000000000000000000000
player1: public(address)
player2: public(address)
deadline: public(uint256)
oracle: public(address)
open: public(bool)
wager: public(uint256)
completed: public(bool)
refunded: public(HashMap[address, bool])

@deploy
def __init__(_timeout: uint256, oracle: address, _wager: uint256):
    # Deadline based on block production rate 
    self.deadline = block.number + _timeout
    self.oracle = oracle
    self.wager = _wager
    self.open = True


@payable
@external
def join():
    assert self.open, "Bets are closed"
    assert (self.wager == msg.value), "Invalid bet"
    assert (self.deadline >= block.number), "Time out reached"
    
    if self.player1 == ZERO_ADDR:
        self.player1 = msg.sender 
    elif self.player2 == ZERO_ADDR:
        assert msg.sender != self.player1, "Cannot bet against yourself"
        self.player2 = msg.sender
        self.open = False   # Two players reached


@nonreentrant
@external
def win(winner: uint256):
    # Check conditions
    assert (msg.sender == self.oracle), "Only the oracle"
    assert (self.balance == 2 * self.wager), "Invalid balance"
    assert not self.open, "Bets are still open"
    assert (self.deadline >= block.number), "Time out reached"
    assert not self.completed, "Bet already resolved"

    # Update state
    self.completed = True

    # External interaction
    if winner == 1:
        send(self.player1, self.balance)    
    elif winner == 2:
        send(self.player2, self.balance)
    else:
        raise "Invalid winner" 


@nonreentrant
@external
def timeout():
    assert block.number > self.deadline, "Bets are still open"
    assert self.balance >= self.wager, "Invalid balance"
    assert not self.completed, "Bet already resolved"

    if msg.sender == self.player1 or msg.sender == self.player2: 
        assert not self.refunded[msg.sender], "Already refunded"
        self.refunded[msg.sender] = True

        send(msg.sender, self.wager)

        # When both players are refunded mark as completed
        if self.refunded[self.player1] and self.refunded[self.player2]:
            self.completed = True 
    else:
        assert False, "Not a player"




    


