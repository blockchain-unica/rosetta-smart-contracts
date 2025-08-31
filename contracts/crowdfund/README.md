# Crowdfund

## Specification

The Crowdfund contract allows users to donate native cryptocurrency to
fund a campaign.
To create the contract, one must specify:
- the *recipient* of the funds,
- the *goal* of the campaign, that is the least amount of currency that
must be donated in order for the campaign to be succesfull,
- the *deadline* for the donations.

After creation, the following actions are possible:
- **donate**: anyone can transfer native cryptocurrency to the contract
until the deadline;
- **withdraw**: after the deadline, the recipient can withdraw the funds
stored in the contract, provided that the goal has been reached;
- **reclaim**: after the deadline, if the goal has not been reached
donors can withdraw the amounts they have donated.

## Required functionalities

- Native tokens
- Time constraints
- Transaction revert
- Key-value maps

## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: a step has been added for initializing the data of the campaign (goal, deadline, etc.).
- **Aiken/Cardano**: implementation coherent with the specification.
- **PyTeal/Algorand**: implementation coherent with the specification.
- **SmartPy/Tezos**: implementation coherent with the specification.
- **Move/Aptos**: implementation coherent with the specification.
- **Move/IOTA**: implementation coherent with the specification.
- **Fe/Ethereum**: implementation coherent with the specification.