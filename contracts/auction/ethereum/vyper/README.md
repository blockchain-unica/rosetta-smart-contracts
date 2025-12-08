# Auction in Vyper

## State variables 

```py
seller: public(address)
highestBid: public(uint256)
startingBid: public(uint256)
duration: public(uint256)   # Duration in seconds
deadline: public(uint256)   # Time when auction ends 
objectName: public(String[MAX_OBJECT_NAME])
auctionStarted: public(bool)
auctionEnded: public(bool)
bidsOf: public(HashMap[address, uint256])
hasBid: public(HashMap[address, bool])
highestBidder: public(address)
```

The **Auction** contract maintains several important pieces of information in its state.  
The most notable variables are:

- `bidsOf: public(HashMap[address, uint256])` — maps each user address to the current bid amount they have placed.  
- `hasBid: public(HashMap[address, bool])` — maps each user address to a boolean value indicating whether the user has already placed a bid.

## Initialization

```py
@deploy
def __init__(_startingBid: uint256, _duration: uint256, _objectName: String[MAX_OBJECT_NAME]):
    assert _duration > 0, "Invalid duration"
    self.seller = msg.sender
    self.startingBid = _startingBid
    self.duration = _duration
    self.objectName = _objectName
```

This function is automatically executed at deployment time. It performs the following actions:
- Sets the seller as the deploying address (msg.sender).
- Ensures that the auction duration is greater than zero.
- Initializes the auction parameters: starting bid, duration, and item name.

## start

```py
@external
def start():
    assert msg.sender == self.seller, "Only the seller"
    assert not self.auctionStarted, "Auction already started"

    self.auctionStarted = True
    self.deadline = block.timestamp + self.duration
```

This function starts the auction. It performs the following checks and actions:
- Verifies that the caller is the seller (only the seller can start the auction).
- Ensures the auction has not already started.
- Sets the auctionStarted flag to True.
- Calculates and stores the bidding deadline based on the current block timestamp and auction duration.

## bid

```py
@payable
@external
def bid():
    assert self.auctionStarted, "Auction not started yet"
    assert not self.auctionEnded, "Auction ended"
    assert self.deadline > block.timestamp, "Bidding time expired"
    assert msg.sender != self.highestBidder, "Already highest bidder"
    assert msg.value > self.highestBid, "Amount is lower than the highest bid"
    assert msg.sender != self.seller, "Seller cannot bid"
    assert self.bidsOf[msg.sender] == 0 and self.hasBid[msg.sender] == False, "Withdraw previous bid first"

    # User made the highest bid 
    self.highestBidder = msg.sender 
    self.highestBid = msg.value 

    # Store in hashmaps the value of the highest bid and the flag that a bid was made
    self.bidsOf[msg.sender] = self.highestBid
    self.hasBid[msg.sender] = True
```
This function is marked as **@payable**, meaning it can receive Ether (ETH).
Participants call this function to place their bids.

The function performs the following validations:
- Ensures the auction has started.
- Checks that the auction has not yet ended and that the bidding deadline has not passed.
- Confirms that the new bid is higher than the current highest bid.
- Ensures the seller cannot place bids.
- Verifies that the bidder has not placed a previous bid (they must withdraw before rebidding).

If all conditions are met:
- The new highest bidder and bid amount are updated.
- The bid value is recorded in the **bidsOf** mapping.
- The **hasBid** flag for the bidder is set to **True**.

## withdraw

```py
@nonreentrant 
@external
def withdraw():
    assert self.auctionStarted, "Auction not started yet"
    assert msg.sender != self.seller, "Not a bidder"
    assert msg.sender != self.highestBidder, "Only non-winning bids are withdrawable"
    assert self.bidsOf[msg.sender] > 0 and self.hasBid[msg.sender] == True, "Nothing to withdraw"

    amount: uint256 = self.bidsOf[msg.sender]
    self.bidsOf[msg.sender] = 0         # Sets previous bid to zero
    self.hasBid[msg.sender] = False     # Allow rebidding

    send(msg.sender, amount)            # Send money
```

The withdraw function is marked as both **@external** and **@nonreentrant**.

The **@nonreentrant** decorator prevents the function from being called again before its first execution is completed.
This ensures protection against **reentrancy attacks**, a common vulnerability that can lead to **double withdrawals** or **double spending** if exploited.

The function performs the following checks:
- Confirms that the auction has started. If not, the contract balance should be empty since no bids were placed.
- Ensures the seller cannot withdraw funds (`msg.sender != self.seller`). Once the auction ends, the seller automatically receives the winning bid.
- Ensures only non-winning bidders can withdraw their funds.
- Verifies that **msg.sender** has a positive balance recorded in **bidsOf**.

If all these conditions are met:
- The contract updates its state by setting the user's **bidsOf** value to **0** and resetting the **hasBid** flag to **False**, allowing the user to place new bids later.
- Finally, the function transfers the user's bid amount back to their address.

## end

```py
@nonreentrant
@external
def end():
    assert self.auctionStarted, "Auction not started"
    assert not self.auctionEnded, "Auction already ended"
    assert msg.sender == self.seller, "Only the seller"
    assert self.deadline < block.timestamp, "Bids are still open"
    self.auctionEnded = True 

    # Send the highest bid to seller 
    self.bidsOf[self.highestBidder] = 0
    send(self.seller, self.highestBid)
```

The **end** function is marked as both **@external** and **@nonreentrant**, since it involves transferring Ether.
This ensures that the function cannot be re-entered during execution, protecting the contract from reentrancy attacks when handling funds.

Before finalizing the auction and sending the winning bid to the seller, the function performs several checks:
- Verifies that the auction has started.
- Ensures the auction has not already ended.
- Confirms that the caller (msg.sender) is the seller — only the seller can close the auction.
- Checks that the bidding deadline has passed, meaning no more bids can be placed.

If all conditions are met:
- The flag **auctionEnded** is set to **True**.
- The highest bid amount is transferred to the seller.
- The winning bidder’s record in **bidsOf** is reset to 0 to clear their stored balance.

## Differences between the Vyper and Solidity implementations

Implementation is similar to Solidity but with one key difference:
- The **withdraw** function is _not_ automatically called when a user makes a new bid. In Vyper a _@external_ function cannot be called internally, unlike in Solidity. The opposite is also true: an _@internal_ function cannot be called externally or from outside the contract. Therefore it's up to the user to call _withdraw_ to bid again.


