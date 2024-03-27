# Simple transfer

## Specification 

The contract allows a user (the *owner*) to deposit native cryptocurrency, 
and another user (the *recipient*) to withdraw arbitrary fractions of the contract balance.

At contract creation, the owner specifies the receiver's address.

After contract creation, the contract allows two actions:
- **deposit** allows the owner to deposit an arbitrary amount of native cryptocurrency in the contract;
- **withdraw** allows the receiver to withdraw any amount of the cryptocurrency deposited in the contract.


## Expected Features

- Asset transfer
- Abort conditions
- (External) contract call


## Implementations

- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: implementation coherent with the specification.
- **Aiken/Cardano**: implementation coherent with the specification; however, a full withdrawal operation would not preserve the covenant as an output associated with the contract would not be created. Therefore, the withdrawal is considered valid if the recipient leaves a pre-declared offset amount of currency in the contract during a full withdraw.
- **PyTeal/Algorand**: implementation coherent with the specification.
- **SmartPy/Tezos**: implementation coherent with the specification.
- **Move/Aptos**: implementation coherent with the specification.
