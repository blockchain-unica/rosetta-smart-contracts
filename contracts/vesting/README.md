# Vesting

## Specification

The Vesting contract involves a funder and a beneficiary.
The contract acts as a trusted intermediary to
implement a time-costrained custody of the deposited 
amount until its vesting.

The funder initializes the contract by setting the 
beneficiary, the start timestamp and the duration. 
The funder also sends to the contract the amount to 
be vested.
At any time, the beneficiary can get the remaining vested 
amount, according to a liner vesting curve. 

## Execution traces

... 