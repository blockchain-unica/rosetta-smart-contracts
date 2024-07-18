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
- **join**: a player joins the contract by depositing an amount of native cryptocurrency equal to the initial pot;
- **win**: after the join and before the deadline, the player can withdraw the whole pot if the oracle exchange rate is greater than the bet rate;
- **timeout**: after the deadline, the owner can redeem the whole pot.

## Required functionalities

- Native tokens
- Time constraints
- Transaction revert
- Contract-to-contract calls

## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: a after the deployment step has been added for allowing the owner to initialize the data
- **Aiken/Cardano**: the validator retrieves an UTXO (passed as an input of the transaction) with the same address as the oracle, containing a script and accesses its datum, where the exchange rate is stored
- **PyTeal/Algorand**: ---
- **SmartPy/Tezos**: the contract owner has to be passed as parameter during contract creation
- **Move/Aptos**: ---
