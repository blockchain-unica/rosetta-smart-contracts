# pragma version ^0.4.0

player1: public(address)
player2: public(address)
winner: public(address)
MAX_SECRET_LENGTH: constant(uint256) = 64

# The hashes of the secrets the players have committed to
secretHashOf: HashMap[address, bytes32]
revealedSecretOf: HashMap[address, Bytes[MAX_SECRET_LENGTH]]

# Deadlines
end_commit: public(uint256) 
end_reveal: public(uint256)

enum PlayerStatus:
    JOINED
    REVEALED

statusOf: public(HashMap[address, PlayerStatus])
bet: public(uint256)

lottery_ended: public(bool)


@deploy
def __init__(_commit_time: uint256, _reveal_time: uint256):
    assert _commit_time > 0, "Invalid join time interval"
    assert _reveal_time > 0, "Invalid reveal time interval"
    self.end_commit = block.number + _commit_time
    self.end_reveal = self.end_commit + _reveal_time


@payable
@external
def join(_hash: bytes32):
    assert _hash != empty(bytes32), "Empty hash"
    assert msg.value > 0, "Invalid bet"
    assert msg.sender != self.player1 and msg.sender != self.player2, "Player already joined"
    assert block.number < self.end_commit, "Join phase already ended"

    # Register player 
    if self.player1 == empty(address):
        self.player1 = msg.sender 
    elif self.player2 == empty(address):
        self.player2 = msg.sender 
    else: 
        assert False, "Two players already joined"

    # Commit secret 
    self.statusOf[msg.sender] = PlayerStatus.JOINED
    self.secretHashOf[msg.sender] = _hash

    # Check bet 
    if self.bet == 0:
        self.bet = msg.value 
    else: 
        assert msg.value == self.bet, "Bet must match the other player\'s bet"


@external
def reveal(_secret: String[MAX_SECRET_LENGTH]):
    assert self.statusOf[msg.sender] == PlayerStatus.JOINED or self.statusOf[msg.sender] == PlayerStatus.REVEALED, "Not a player"
    assert block.number > self.end_commit, "Join phase not ended yet"
    assert block.number < self.end_reveal, "Reveal phase already ended"
    assert self.statusOf[msg.sender] != PlayerStatus.REVEALED, "Player already revealed the secret"
    
    # Reveal the secret
    assert keccak256(convert(_secret, Bytes[MAX_SECRET_LENGTH])) == self.secretHashOf[msg.sender], "Wrong secret revealed"
    self.statusOf[msg.sender] = PlayerStatus.REVEALED
    self.revealedSecretOf[msg.sender] = convert(_secret, Bytes[MAX_SECRET_LENGTH])


@nonreentrant 
@external
def refund_on_missing_opponent():
    assert not self.lottery_ended, "Lottery already ended"
    assert block.number > self.end_commit, "Join phase not ended yet"
    assert self.statusOf[msg.sender] == PlayerStatus.JOINED, "Not a player"

    # Check that a player is actually missing
    if msg.sender == self.player1:
        assert self.player2 == empty(address), "Another player joined, cannot be refunded"

    self.lottery_ended = True 

    # Refund player
    send(msg.sender, self.bet)


@nonreentrant
@external
def redeem():
    assert not self.lottery_ended, "Lottery already ended"
    assert block.number > self.end_reveal, "Reveal phase non ended yet"

    # Check if caller has revealed the secret 
    assert self.statusOf[msg.sender] == PlayerStatus.REVEALED, "Secret was not revealed"
    
    # If player1 or player2 has not revealed than the caller can redeem
    if (self.statusOf[self.player1] != PlayerStatus.REVEALED) or (self.statusOf[self.player2] != PlayerStatus.REVEALED):
        self.winner = msg.sender 
    
    # Both player revealed the secret
    else:
        self.winner = self.calculateWinner()
        assert msg.sender == self.winner, "You're not the winner"
    
    self.lottery_ended = True
    send(self.winner, self.balance) 



@view
@internal
def calculateWinner() -> address:
   
    l1: uint256 = len(self.revealedSecretOf[self.player1])
    l2: uint256 = len(self.revealedSecretOf[self.player2])

    if (l1 + l2) % 2 == 0:
        return self.player1 
    else:
        return self.player2
    


    
