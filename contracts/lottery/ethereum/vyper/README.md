# Lottery

## State variables

```py
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
```
This contract manages a two-player lottery based on a _commit-reveal mechanism_. The most relevant state variables are:
- `player1`, `player2` — the addresses of the two participants registered in the lottery.
- `secretHashOf` — a mapping linking each player to the committed hash of their secret. This prevents players from changing their secret after joining.
- `revealedSecretOf` — a mapping storing the actual secret revealed by the players during the **reveal phase**.
- `statusOf` — tracks the commit/reveal state of each participant (`JOINED` or `REVEALED`).
- `end_commit`, `end_reveal` — block numbers defining the two main deadlines: **join** and **commit** phase.
- `bet` — the amount of ETH each player must send to join the lottery.
- `lottery_ended` — a final flag preventing further interaction once the lottery has been resolved.

## Initialization

```py
@deploy
def __init__(_commit_time: uint256, _reveal_time: uint256):
    assert _commit_time > 0, "Invalid join time interval"
    assert _reveal_time > 0, "Invalid reveal time interval"
    self.end_commit = block.number + _commit_time
    self.end_reveal = self.end_commit + _reveal_time
```
The constructore sets up the timing parameters for the lottery: `end_commit`, `end_reveal`.
Before assigning values, it enforces that both input durations are strictly greater than zero. These parameters are expressed in **block intervals**, meaning time progression is measured by new blocks added to the blockchain rather than real-world time.

## join

```py
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
```
This **payable external function** allows a player to enter the lottery and commit to a secret value.

Before registering the player, it enforces:
- A non-empty commitment hash
- A positive ETH bet
- The caller has not joined already
- The commit phase (`block.number < end_commit`) is still active

The first two distinct callers become `player1` and `player2`.
Each player’s commitment hash is stored and their status is set to `JOINED`.

To ensure fairness, the contract enforces that both players place **identical bets**.
The first player sets the reference amount, and the second must match it.

No secret is revealed at this stage — only its hash is stored.

## reveal

```py 
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
```
This **external** function reveals the previously committed secret. 

It validates:
- The caller is a registered player
- The commit phase has ended and the reveal phase is still open
- The player has not already revealed

Upon successful verification that the secret revealed is the correct one (`keccak256(convert(_secret, Bytes[64])) == secretHashOf[msg.sender]`), the contract records the revealed secret and marks the player's status as `REVEALED`.

## refund_on_missing_opponent

```py
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
```
This **external non-reentrant** function allows a single player to recover their funds if no opponent joined correctly (before `end_commit`).

It requires:
- The lottery has not already ended
- The commit phase has finished
- The caller is a player

A refund is only possible when the caller joined, but no valid second player exists. After refunding the player the lottery is permanently marked as ended, and no further interaction is allowed.

## redeem

```py
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
```
This **external non-reentrant** function settles the lottery by declaring a winner and transferring the prize. 

It enforces:
- The lottery is still active
- The reveal phase is over
- The caller has revealed the secret

Winner logic:
- If the **opponent of the caller failed to reveal** the secret, the caller wins by default.
- If **both players revealed**, the contract calls `calculateWinner()` to decide the winner deterministically.

Finally it marks the lottery as ended.

## calculateWinner

```py
@view
@internal
def calculateWinner() -> address:
   
    l1: uint256 = len(self.revealedSecretOf[self.player1])
    l2: uint256 = len(self.revealedSecretOf[self.player2])

    if (l1 + l2) % 2 == 0:
        return self.player1 
    else:
        return self.player2
```
This **internal helper** function computes the winner when both players have revealed their secret.
It retrieves the lengths of the revealed secrets and uses a simple parity rule:
- if `(length1 + length2)` is **even**, `player1` wins
- Otherwise, `player2` wins

## Differences between the Vyper and Solidity implementations

The Vyper implementation introduces a few structural differences when compared to the Solidity version:
- A single `join` function handles registration for both players.
- A single `reveal` function manages secret disclosure for either participant.

To cover edge cases, Vyper uses a dedicated `refund_on_missing_opponent` function to resolve situations where only one player joins.

Outcome resolution is performed in the `redeem` function, which accounts for both scenarios: only one player revealed, or both players revealed. When both secrets are available, `redeem` delegates winner selection to the internal `calculateWinner` function.

Some additional differences are:
- Solidity implementation uses **enum** to keep track of the contract state, while Vyper implementation uses status maps (`statusOf`).
- Vyper implementation stores revealed secrets as fixed-size `Bytes[MAX_SECRET_LENGTH]` instead of unbound strings values.
