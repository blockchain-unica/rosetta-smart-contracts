# Bet

## Specification

The Bet contract involves two players and an oracle. The contract has the following parameters, defined at deployment time:
- **deadline**: a time limit (e.g. current block height plus a fixed constant); 
- **oracle**: the address of a user acting as an oracle.

After creation, the following actions are possible: 
- **join**: the two players join the contract by depositing their bets (the bets, that must be equal for both players, can be in the native cryptocurrency);
- **win**: after both players have joined, the oracle is expected to determine the winner, who receives the whole pot;
- **timeout** if the oracle does not choose the winner by the deadline, then both players can redeem their bets.

## Expected Features

- Asset transfer
- Multisig
- Time constraints

## Implementations

- **Solidity/Ethereum**: since the platform does not support multi-signature verification, the join is split in two actions: the first player acts first. After that, the second player joins.
- **Anchor/Solana**: implementation coherent with the specification.
- **Aiken/Cardano**: since we cannot access the current block height where the transaction is being validated, the deadline is represented as a UNIX timestamp, which is checked against the lowest bound of the transaction's validity interval.
- **PyTeal/Algorand**: two join functions, one for each player; player1 is also the owner of the contract and its creator.
- **SmartPy/Tezos**: two join functions, one for each player; player1 **could** also be the owner of the contract and its creator.
- **Move/Aptos**: deadline is a timestamp rather than a block height; the two players can be different from the oracle creator; the bets can be paid in any asset type.
