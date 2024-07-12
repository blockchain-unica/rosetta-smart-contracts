# Auction

## Specification

The contract allows a seller to create an english auction, with bids in the native cryptocurrency.

The seller creates the contract by specifying:
- the starting bid of the auction;
- the duration of the auction (i.e., the period of time in which bids are open from the start of the auction);
- the object of the auction (a string, used for notarization purposes only).

After creation, the contract supports the following actions:
- **start**, which allows the seller to start the auction. 
- **bid**, which allows any user to bid any amount of native cryptocurrency after the auction has started and before its duration has expired. If the the amount of the bid is greater than the current highest bid, then it is transferred to the contract; otherwise, it is returned back to the user.
- **withdraw**, which allows any user, at any time, to withdraw their bid if this is not the currently highest one.
- **end**, which allows the seller to end the auction after its duration has expired, and to withdraw the highest bid.

## Required Features

- Native tokens
- Time constraints
- Transaction revert
- Key-value maps

## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: Previous bidders are not stored, the contract sends the currency back to the previous bidder in the same transaction in which the new bid is made. 
- **Aiken/Cardano**: implementation coherent with the specification.
- **PyTeal/Algorand**: implementation coherent with the specification.
- **SmartPy/Tezos**: implementation coherent with the specification.
- **Move/Aptos**: current bid is not sent to the contract but rather stored on chain. Bid can be any asset type. Each bidder refunds the previous one; the withdraw function does not exist.
