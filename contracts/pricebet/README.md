# Price Bet

## Specification

The PriceBet contract allows anyone to bet on a future exchange rate between two tokens. 
Its specification is adapted from the [Clockwork Finance](https://arxiv.org/abs/2109.04347) paper.

The contract has the following parameters, defined at deployment time: 
- an **owner**, who deposits the initial pot (in the native cryptocurrency);
- an **oracle**, a contract that is queried for the exchange rate between two given tokens;
- a **deadline**, a time limit after which the player loses the bet (e.g. the current block height plus a fixed constant); 
- an **exchange rate**, that must be reached in order for the player to win the bet.  
 
After creation, the following actions are possible: 
- **join**: a player joins the contract by depositing an amount of tokens equal to the initial pot;
- **win**: after the join and before the deadline, the player can withdraw the whole pot if the oracle exchange rate is greater than the bet rate;
- **timeout**: after the deadline, the owner can redeem the whole pot.

## Expected Features

- Asset transfer
- Multisig
- Time constraints
- Contract-to-contract interactions

## Implementations

- **Solidity/Ethereum**: ---
- **Anchor/Solana**: ---
- **Aiken/Cardano**: ---
- **PyTeal/Algorand**: ---
- **SmartPy/Tezos**: ---
- **Move/Aptos**: ---