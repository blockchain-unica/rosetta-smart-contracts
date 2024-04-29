# Bet

## Specification
The Bet contract involves two players and an oracle. 
At construction, the contract creation must specify:
- **deadline**: a time limit is specified  (e.g. block height plus 1000); 
- **oracle**: the address of a user acting as an oracle.	

After creation, the following actions are possible: 
- **join**: the two players join the contract by depositing 1 token unit each (the token can be the native cryptocurrency);
- **win**: after the join, the oracle is expected to perform this action, determining the winner between the two players; the winner can redeem the whole pot of 2 token units.
- **timeout** if the oracle does not choose the winner by the deadline, then both players can redeem their bets, withdrawing 1 token units each.

## Expected Features

- Asset transfer
- Multisig
- Time constraints

## Implementations

- **Solidity/Ethereum**: since the platform does not support multi-signature verification, the join is split in two actions: the first player acts first, by depositing 1 ETH. After that, the second player joins by depositing 1 ETH.
- **Anchor/Solana**: implementation coherent with the specification.
- **Aiken/Cardano**: since we cannot access the current block height where the transaction is being validated, the deadline is represented as a UNIX timestamp, which is checked against the lowest bound of the transaction's validity interval.
- **PyTeal/Algorand**: two join functions, one for each player; player1 is also the owner of the contract and its creator.
- **SmartPy/Tezos**: two join functions, one for each player; player1 **could** be also the owner of the contract and its creator.
- **Move/Aptos**: deadline is a timestamp rather than a block height; the two players can be different from the oracle creatore; wager can be any amount and is in assets.

