# Auction

## Specification

The contract allows a seller to create an auction based, with bids in the native cryptocurrency.
The seller initializes the contract by specifying:
- the startBid of the auction,
- the duration of the auction (i.e., the time that bids are open from the start of the auction),
- the object of the auction.

After creation, the contract supports the following actions:
- **start**: after the contract creation, the seller can start the auction. 
- **bid**: after the auction has started, any participant can bid any amount of native cryptocurrency and transfer that 
amount to the contract until the duration time elapses. In the amount is not greater than the current highest bid, the contract returns the old bid to the participant.
- **withdraw**: at any time, participant can withdraw their bid if this is not the currently highest one.
- **end**: after the deadline, the seller ends the auction and withdraws the highest bid.

## Required Features

- Native tokens
- Time constraints
- Transaction revert

## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: Previous bidders are not stored, the contract sends the currency back to the previous bidder in the same transaction in which the new bid is made. 
- **Aiken/Cardano**: implementation coherent with the specification.
- **PyTeal/Algorand**: implementation coherent with the specification.
- **SmartPy/Tezos**: implementation coherent with the specification.
- **Move/Aptos**: current bid is not sent to the contract but rather stored on chain. Bid can be any asset type. Each bidder refunds the previous one; the withdraw function does not exist.
