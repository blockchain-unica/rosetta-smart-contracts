# Bet

## Specification

The Bet contract involves two players and an oracle. 
At construction, a deadline is set to the current block height plus 1000, and the address of an oracle is specified.

The players join the contract by depositing 1 token unit each.

At this point, the oracle is expected to determine the winner between the two players.
The winner can redeem the whole pot of 2 token units.

If the oracle does not choose the winner by the deadline,
then both players can redeem their bets, withdrawing 1 token units each.

## Implementations

- **Solidity/Ethereum**: since the platform does not support multi-signature verification, the join is split in two actions: 
the first player acts first, by depositing 1 ETH. After that, the second player joins by depositing 1 ETH.
- **Anchor/Solana**: a step has been added for initializing the data of the bet contract (buyer, seller, amount, etc.).
- **Aiken/Cardano**: since we cannot access the current block height where the transaction is being validated, the deadline is represented as a UNIX timestamp, which is checked against the lowest bound of the transaction's validity interval.
- **PyTeal/Algorand**:
- **SmartPy/Tezos**:
- **Move/Aptos**:  
