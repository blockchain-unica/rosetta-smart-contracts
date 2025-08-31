# Factory

## Specification

The Factory contract allows a user to create and deploy another contract (called Product contract), according to the [Factory Pattern](https://betterprogramming.pub/learn-solidity-the-factory-pattern-75d11c3e7d29).

Once the Factory contract has been deployed, it supports the following actions"
- **createProduct**: to create a Product contract, the user must specify a *tag* string to be stored in the Product state. 
- **getProducts**: at any time, the user gets the list of addresses of his Product contracts.

Once a Product contract has been deplyoed, it supports the following actions:
- **getTag**: the user gets the tag stored in the Product state. This action is only possible for the user who requested the creation of the Product contract.
- **getFactory**: the user gets the address of the Factory contract that generated the Product.

## Required functionalities
- In-contract deployment
- Transaction revert
- Key-value maps
- Dynamic arrays
 
## Implementations
- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: 
- **Aiken/Cardano**:
- **PyTeal/Algorand**: implementation coherent with the specification.
- **SmartPy/Tezos**: implementation coherent with the specification.
- **Move/Aptos**:
- **Fe/Ethereum**: the implementation is coherent with the specification, but (possible Fe bud, Issue was created on Fe repo) the chain is not actually affected by the deployment of the product of the factory.