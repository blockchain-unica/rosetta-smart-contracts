# Lottery

## Specification

Consider a lottery where two players bet an equal amount of crypto-currency, and the winner - who is chosen fairly between the two players - redeems the whole pot.

Since smart contract are deterministic and external sources of randomness (e.g., random number oracles) might be biased, to achieve fairness we follow a *commit-reveal-punish* protocol, where both players first commit to the secret hash, then reveal their secrets (which must be preimages of the committed hashes), and finally the winner is computed as a fair function of the secrets.

Implementing this properly is quite error-prone, since the protocol must prescribe punishments in case a player behaves dishonestly, e.g. by refusing to perform some required action. In this case, the protocol must still ensure that, on average, an honest player has at least the same payoff that she would have by interacting with another honest player. 

The protocol followed by the players is the following:
1. `player1` and `player2` join the lottery by paying the bet and committing to a secret (the bet is the same for each player);
2. `player1` reveals the first secret;
3. if `player1` has not revealed, `player2` can redeem both players' bets after a given deadline (`end_reveal`); 
4. once `player1` has revealed, `player2` reveals the secret;
5. if `player2` has not revealed, `player1` can redeem both players' bets after a given deadline (`end_reveal` plus a fixed constant);
6. once both secrets have been revealed, the winner, who is fairly determined as a function of the two revealed secrets, can redeem the whole pot.

If the platform does not support multisig transactions, then step 1. is split in the following sub-steps: 
- `player1` joins the lottery by paying the bet and committing to a secret;
- `player2` joins the lottery by paying the bet and committing to another secret;
- if `player2` has not joined, `player1` can redeem her bet after a given deadline (`end_commit`).

## Expected Features

- Asset transfer
- Multisig transactions
- Time constraints
- Abort conditions
- Hash
- Randomness

## Implementations

- **Solidity/Ethereum**: ---
- **Anchor/Solana**: implementation coherent with the specification.
- **Aiken/Cardano**: ---
- **PyTeal/Algorand**: ---
- **SmartPy/Tezos**: ---
- **Move/Aptos**: ---
