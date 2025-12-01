# Escrow

## Specification

The escrow contract acts as a trusted intermediary between a buyer and a seller, aiming to protect the buyer from the possible non-delivery of the purchased goods. 

The seller initializes the contract by setting: 
- the buyer's address;
- the amount of native cryptocurrency required as a payment.

Immediately after the initialization, the contract supports a single action:
- **deposit**, which allows the buyer to deposit the required amount in the contract.

Once the deposit action has been performed, exactly one of the following actions is possible:
- **pay**, which allows the buyer to transfer the whole contract balance to the seller.
- **refund**, which allows the seller to transfer back the whole contract balance to the buyer.

## Required functionalities

- Native tokens
- Transaction revert

## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: a step has been added for initializing the data of the escrow (buyer, seller, amount, etc.).
- **Aiken/Cardano**: in Cardano, a contract cannot have an empty balance. The seller creates the contract with an initialization amount in ADA, which remains for the contract's lifespan and is returned to the seller during the Pay and Refund actions. 
- **PyTeal/Algorand**: implementation coherent with the specification.
- **SmartPy/Tezos**: implementation coherent with the specification.
- **Move/Aptos**: implementation coherent with the specification.
- **Move/IOTA**: implementation coherent with the specification.
- **Fe/Ethereum**: implementation coherent with the specification, some adjustments were made to make Enums work.
- **Vyper/Ethereum**: implementation coherent with the specification.