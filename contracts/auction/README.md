# Auction

## Specification

The Auction contract allows a seller to create an auction based 
on the native cryptocurrency and any participant to bid.
To create the contract, the seller must specify:
- the *startBid* of the auction,
- the *duration* of the auction,
- the *object* of the auction,

After creation, the following actions are possible:
- **start**: after the contract creation, the seller can 
start the auction. 
- **bid**: after the auction starts, any participant can 
bid an amount of native cryptocurrency and transfer that 
amount to the contract until the duration time elapses. 
In the event of a raise, the contract returns the old bid to 
the participant.
- **withdraw**: at any time, participant can withdraw his bid
if this is not the currently highest one.
- **end**: after the deadline, the seller ends the auction
and withdraws the highest bid.
