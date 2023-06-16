# BetOracle

## Specification

The Bet oracle contract involves three accounts: two users (bettors) and an oracle.
It allows two bettors to bet on one of the two possible choices (simply defined as 1 and 2).
The oracle will send the winning choice after the end of a time period.

At contract creation, the oracle:
- sets itself up as the oracle for the contract.
- sets the value of the wager,
- specifies the deadline for betting, in terms of a delay from the publication of the contract;

After contract creation, the Bet Oracle allows two actions:
- **bet**, which can be called within the deadline and which requires the caller (a bettor) to send 
a value equal to the wager (fixed) and specify a choice that is not already chosen by the other bettor;
- **oracleSetResult**, which can be called only by the oracle and after the deadline of the bet, and 
transfers the whole contract balance to the winner of the bet.

## Execution traces

### Trace 1

