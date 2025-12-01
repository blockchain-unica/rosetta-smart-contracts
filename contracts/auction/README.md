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

## Required functionalities

- Native tokens
- Time constraints
- Transaction revert
- Key-value maps

## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: Previous bidders are not stored, the contract sends the currency back to the previous bidder in the same transaction in which the new bid is made. 
- **Aiken/Cardano**: differently from the Solidity implementation, the withdraw action returns only one outbid at a time as this action must be called on the single outbid UTXO. To collect the whole balance, it is necessary to insert all the outbid UTXOs in the same transaction. 
- **PyTeal/Algorand**: implementation coherent with the specification.
- **SmartPy/Tezos**: implementation coherent with the specification.
- **Move/Aptos**: current bid is not sent to the contract but rather stored on chain. Bid can be any asset type. Each bidder refunds the previous one; the withdraw function does not exist.
- **Move/IOTA**: in the bid function if a higher bid is made than the previous one, the previeus bid is sent back to the sender; the withdraw function does not exist.
- **Fe/Ethereum**: implementation coherent with the specification. Enums have been handled differently than in Solidity.
- **Vyper/Ethereum**: implementation is conceptually similar to Solidity, but rebidding requires a manual withdrawal step. This is because Vyper does not allow calling external functions from within the contract.