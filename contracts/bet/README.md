# Bet

## Specification
The Bet contract involves two players and an oracle. 
At construction, the contract creation must specify:
**deadline** is set to the current block height plus 1000, 
**oracle** the address of an oracle is specified.	
// alvi: la deadline col block height mi sembra poco generica
// Andrea: si potrebbe usare un timestamp ma così non si mostra 
// il problema di Cardano che non può accedere all'altezza dei blocchi

After creation, the following actions are possible: 
**join**: the two players join the contract by depositing 1 token unit each.
**win**: after the join, the oracle is expected to determine the winner between the two players.
The winner can redeem the whole pot of 2 token units.
**timeout** If the oracle does not choose the winner by the deadline,
then both players can redeem their bets, withdrawing 1 token units each.


## Features 
**multi-signature** the two players join the contract with the same transaction.
**gossip**  the contract access the block height when timeout is called
**native asset transfer** the contract transfers native currency to a user's address 

## Implementations
- **Solidity/Ethereum**: since the platform does not support multi-signature verification, the join is split in two actions: the first player acts first, by depositing 1 ETH. After that, the second player joins by depositing 1 ETH.
- **Anchor/Solana**: a step has been added for initializing the data of the bet contract (buyer, seller, amount, etc.).
- **Aiken/Cardano**: since we cannot access the current block height where the transaction is being validated, the deadline is represented as a UNIX timestamp, which is checked against the lowest bound of the transaction's validity interval.
- **PyTeal/Algorand**: two join functions, one for each player; player1 is also the owner of the contract and its creator.
- **SmartPy/Tezos**:
- **Move/Aptos**: deadline is a timestamp rather than a block height; the two players can be different from the oracle creatore; wager can be any amount and is in assets.

