# Token transfer

## Specification 

The contract TokenTransfer allows a user (the *owner*)
to transfer units of a token (possibly, not the native cryptocurrency) to the contract, 
and another user (the *recipient*) to withdraw.

At contract creation, the owner specifies the receiver's address and the token address.

After contract creation, the contract supports two actions:
- **deposit**, which allows the owner to deposit an arbitrary amount of tokens
in the contract;
- **withdraw**, which allows the receiver to withdraw 
any amount of the token deposited in the contract.

## Required functionalities
- Custom tokens
- Transaction revert
  
If custom tokens are not natively available, then the following functionalities can be used to implement a workaround:
- Key-value maps
- Contract-to-contract calls

## Implementations

- **Solidity/Ethereum**: the token is implemented by importing an Openzeppelin ERC20 token. 
This implies that the `deposit` function can be activated only after calling 
the ERC20's `approve` function to specify the address of the contract.
- **Anchor/Solana**: implementation coherent with the specification.
- **Aiken/Cardano**: implementation coherent with the specification.
- **PyTeal/Algorand**: implementation coherent with the specification.
- **SmartPy/Tezos**: implementation coherent with the specification.
- **Move/Aptos**: implementation coherent with the specification.
- **Move/IOTA**: implementation coherent with the specification.
