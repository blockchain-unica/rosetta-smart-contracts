# Vesting

## Specification

The Vesting contract involves a funder 
and a beneficiary.
The contract acts as a trusted 
intermediary to implement a 
time-costrained custody of the deposited 
amount until its vesting.

At any time, the beneficiary 
can get the remaining vested 
amount, according to a liner 
vesting curve. 

The funder initializes the contract by 
setting: 
- the beneficiary, 
- the start timestamp 
- the duration.
- the funder sends to the contract the 
amount to 
be vested.

After contract creation, the Vesting 
allows one action:
- **release**, which sends to the 
beneficiary the amount of the remaining 
vested amount 

## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**:  a step has been added for initializing the data of the vesting (beneficiary, start, duration, etc.).
- **Aiken/Cardano**: since beneficiary needs to compute the vesting value offchain, this value will be different (i.e. smaller than) from the one later computed by the validator. Therefore, the beneficiary is allowed to withdraw any value that is smaller than the actual one computed by the validator.
- **PyTeal/Algorand**:
- **SmartPy/Tezos**:
- **Move/Aptos**:
