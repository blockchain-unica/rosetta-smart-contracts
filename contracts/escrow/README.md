# Escrow

## Specification

The escrow contract acts as a trusted intermediary between a buyer and a seller, aiming to protect the buyer from the possible non-delivery of the purchased goods. 

The seller initializes the contract by setting: 
- the address of the buyer;
- the amount of native cryptocurrency required as a payment.

After the initialization, the contract enables a single action:
- **deposit**, which allows the buyer to deposit the required amount in the contract.

Once the deposit action has been performed, exactly one of the following actions is possible:
- **pay**, which allows the buyer to transfer the whole contract balance to the seller.
- **refund**, which allows the seller transfer back the whole contract balance to the buyer.

## Expected Features

- Asset transfer
- Abort conditions
- (External) contract call

## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: a step has been added for initializing the data of the escrow (buyer, seller, amount, etc.).
- **Aiken/Cardano**: implementation coherent with the specification.
- **PyTeal/Algorand**: implementation coherent with the specification.
- **SmartPy/Tezos**: implementation coherent with the specification.
- **Move/Aptos**: implementation coherent with the specification.
