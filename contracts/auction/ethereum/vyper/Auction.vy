# pragma version ^0.4.0

MAX_OBJECT_NAME: constant(uint256) = 64
seller: public(address)
highestBid: public(uint256)
startingBid: public(uint256)
duration: public(uint256)   # Duration in seconds
deadline: public(uint256)   # Time when auction ends 
objectName: public(String[64])
auctionStarted: public(bool)
auctionEnded: public(bool)
bidsOf: public(HashMap[address, uint256])
hasBid: public(HashMap[address, bool])
highestBidder: public(address)


@deploy
def __init__(_startingBid: uint256, _duration: uint256, _objectName: String[MAX_OBJECT_NAME]):
    assert _duration > 0, "Invalid duration"
    self.seller = msg.sender
    self.startingBid = _startingBid
    self.duration = _duration
    self.objectName = _objectName


@external
def start():
    assert msg.sender == self.seller, "Only the seller"
    assert not self.auctionStarted, "Auction already started"

    self.auctionStarted = True
    self.deadline = block.timestamp + self.duration


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
    

