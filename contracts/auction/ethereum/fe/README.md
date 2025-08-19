# Auction

This contract allow the creation of a timed auction, with a bidding system and refunding automatically when a higher bid is made, and with possibility to withdraw is not current highest bidder.

## Technical challenges

Types of enums created at runtime and Strings types can't be compared in Fe. Because of that, I had to implement a function in the Fe's enum native functionality that actually returns an integer.

This is the same solution adopted for Escrow use case.

## States system

A *States* system ensures every function can be called only when it is meaningful to do so. Auctions can't be started more than once, withdrawals can't be made if the auction is closed, bidding is prohibited if the auction is closed and ending the bid is prohibited if time is not up yet.

## Initialization

`pub fn __init__(mut self, ctx: Context, _object: String<100>, _startingBid: u256)`

At deploy time the contract takes a **String<100>.

Since Fe does not support dynamic arrays, the maximum for *_object* parameter is 100 chars, issues with this limitation will be discussed in following use cases. 

This parameter describes the bid for notarization purposes, and an integer describing the starting bid value. Whoever wants to participate must bid higher than the starting bid value.

## Execution

After the contract is deployed, 4 functions can be called.

### start(_duration: u256)

Whoever deploys the contract becomes the seller.

They are required to set up the duration of the bid in seconds by parameter *_duration*.

### bid()

Anyone can bid any amount of Ether, the only requirement is bidding higher than the previous highest bidder or higher than the starting bid set up by the seller.

If the same user bids twice and consequently makes a higher bid than previously, the previous bid is refunded and the new one is accepted as new highest bid.

### withdraw()

This function can be called by anyone has previously placed a bit and is not currently the highest bidder and hasn't withdrawed yet.

Withdrawing refunds the Ether to the user.

### end()
This function can only be called by the Seller and if the auction both started and ended, and lets them take the highest bid.
