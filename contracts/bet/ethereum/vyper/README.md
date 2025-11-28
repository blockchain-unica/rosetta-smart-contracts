# Bet in Vyper

**join**

```py
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
```

The join function allows users to participate in the bet by depositing the required wager amount.
It is marked as **@payable**, meaning it can receive Ether (ETH) from participants when called.

Before accepting a new player, the function performs several checks:
- Ensures that the betting session is open (self.open == True).
- Validates that the amount of Ether sent (msg.value) matches the required wager amount.
- Checks that the current block number has not exceeded the deadline (block.number <= self.deadline).

If all conditions are met:
- If no player has joined yet, the caller becomes **player1**.
- If one player has already joined, the caller becomes **player2**, but only if they are not the same as player1.
- Once both players have joined, the contract sets **open** variable to **False** to prevent additional participants.
<br>

**win**

```py
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
```

The win function is used by the oracle to declare the winner of the bet and distribute the total wagered amount accordingly.
It is marked as both **@external** and **@nonreentrant** to avoid reentrancy attacks.

Before processing the payout, the function enforces several checks:
- Verifies that the caller is the designated oracle (`msg.sender == self.oracle`).
- Ensures the contract’s balance equals twice the wager amount (both players must have joined).
- Confirms that betting is closed (`self.open == False`).
- Checks that the deadline has not yet passed (`block.number <= self.deadline`).
- Ensures the bet has not already been resolved (`self.completed == False`).

If all conditions are met:
- The contract state is updated by setting the **completed** variable to **True**, marking the bet as finalized.
- Based on the **winner** value:
  - If `winner == 1`, the total balance is sent to **player1**.
  - If `winner == 2`, the total balance is sent to **player2**.
  - Any other value for winner raises an "Invalid winner" error.
<br>

**timeout**

```py
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
```

The **timeout** function allows players to reclaim their wager if the bet is not resolved before the deadline.

Before processing any refunds, the function performs the following checks:
- Verifies that the current block number has passed the deadline (`block.number > self.deadline`).
- Ensures the contract balance is valid and holds at least one wager (`self.balance >= self.wager`).
- Confirms that the bet has not already been completed (`self.completed == False`).

If these conditions are met:
- Checks that the caller is one of the participating players (`msg.sender == self.player1 or msg.sender == self.player2`).
- Ensures that the caller has not already been refunded (`self.refunded[msg.sender] == False`).

Once validated:
- The caller’s refund status is updated in the **refunded** mapping.
- The wager amount is sent back to the caller using `send(msg.sender, self.wager)`.
- If both players have been refunded, the contract marks the bet as completed by setting `self.completed = True`.
- If the caller is not one of the registered players, the function reverts with `assert False, "Not a player"`.

## Implementation differences

Implementation is similar to Solidity. The join is split in two actions.
