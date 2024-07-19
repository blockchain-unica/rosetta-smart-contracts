# Factory

## Specification

The Factory contract allows a user to create and deploy a Product contract, according to the *Factory Pattern*.

After the Factory contract creation, the following actions are possible.
- **createProduct**: to create a Product 
contract, the user must specify a *tag* 
string to be stored in the Product state. 
- **getProducts**: at any time, the user gets 
the list of addresses of his Product contracts.

After a Product contract creation, the following actions are possible.
- **getTag**: the user gets the tag stored in the Product state. This action is only possible for the user who requested the creation of the Product contract.
- **getFactory**: the user gets the address of the Factory contract that generated the Product.

## Required functionalities
- Transaction revert
- In-contract deploy
 
## Implementations
- **Solidity/Ethereum**: implementation coherent with the specification.
- **Anchor/Solana**: 
- **Aiken/Cardano**:
- **PyTeal/Algorand**: implementation coherent with the specification.
- **SmartPy/Tezos**: implementation coherent with the specification.
- **Move/Aptos**:
