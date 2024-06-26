# Escrow

## Specification

The Escrow contract involves a buyer
and a seller (but no arbiter).
The contract acts as a trusted
intermediary to protect the buyer from
the possible non-delivery of the 
purchased goods. The buyer is 
expected to deposit the required amount
in the contract after the contract 
initialization.

The seller initializes the contract by 
setting: 
- the address of the buyer 
- the amount of native cryptocurrency 
required as a payment.

After the initialization, the contract 
allows one first actions:
- **deposit**, with which the buyer 
deposits the required amount in the 
contract.

When the contract is funded, one of the 
following two actions are possible.
- **pay**, with which the buyer can 
release the payment to the
seller: in this case, the whole contract
balance 
is transferred to the seller.
- **refund**, that allows
the seller to accept a buyer reclaim: 
in this case, the contract issues a 
refund,transferring back the whole 
contract balance to the buyer.

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
