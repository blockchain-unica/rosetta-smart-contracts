# Bet

## Specification

The Bet contract involves two players and an oracle. The contract has the following parameters, defined at deployment time:
- **deadline**: a time limit (e.g. current block height plus a fixed constant); 
- **oracle**: the address of a user acting as an oracle.

After creation, the following actions are possible: 
- **join**: the two players join the contract by depositing their bets (the bets, that must be equal for both players, can be in the native cryptocurrency);
- **win**: after both players have joined, the oracle is expected to determine the winner, who receives the whole pot;
- **timeout** if the oracle does not choose the winner by the deadline, then both players can redeem their bets.

## Required functionalities

- Native tokens
- Multisig transactions
- Time constraints
- Transaction revert

## Implementations

- **Solidity/Ethereum**: since the platform does not support multisig transactions, the join is split in two actions. The first player acts first; after that, the second player joins.
- **Anchor/Solana**: implementation coherent with the specification.
- **Aiken/Cardano**: the oracle cannot be one of the two players; the first player will always pay the join and the timeout transactions fees.  
- **PyTeal/Algorand**: two join functions, one for each player; the first player who joins is also the owner of the contract and its creator.
- **SmartPy/Tezos**: two join functions, one for each player; the first player **could** also be the owner of the contract and its creator.
- **Move/Aptos**: the deadline is a timestamp; the bets can be paid in any token type.
- **Move/IOTA**: two join function, the first player acts first and after the second player joins; the deadline is a timestamp; the bets can be paid in any token type.
