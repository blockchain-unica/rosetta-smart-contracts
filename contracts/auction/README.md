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
In the event of a raise, the contract returns the old bid to    // alvi: in che senso "raise"? una eccezione? non tutti i linguaggi hanno le eccezioni, questa terminologia è fuorviante e poco generica
the participant.
- **withdraw**: at any time, participant can withdraw his bid
if this is not the currently highest one.
- **end**: after the deadline, the seller ends the auction
and withdraws the highest bid.

## Expected Features

- Asset transfer
- Time constraints
- Abort conditions
- (External) contract call


## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: Previous bidders are not stored, the contract sends the currency back to the previous bidder in the same transaction in which the new bid is made. 
- **Aiken/Cardano**: implementation coherent with the specification.
- **PyTeal/Algorand**: implementation coherent with the specification.
- **SmartPy/Tezos**: implementation coherent with the specification.
- **Move/Aptos**: current bid is not sent to the contract but rather stored on chain. Bid can be any asset type. Each bidder refunds the previous one; the withdraw function does not exist.
