# Decentralized Identity

## Specification

This case study is intended to represent the SSI context.
The reference implementation is an extraction from the EIP 1056 implementation.

*Identity* is a blockchain address that has the property of belonging to another address.
*Owner* is an account that has the authority to perform actions on the identity.
*Delegate* This is an account that could have some privileges for a specific identity. Each identity can have multiple delegate names, one for each specific type. The owner of an identity can assign a delegate to it, specifying the type of delegate. A delegate remains valid for a certain period of time (expressed in blocks).
*Actor* is the account that performs actions. In public functions, it is always the message sender.

In this use case, we define two actors: Owner1, Onwer2

After creation, the following sequence of actions is possible:
- **Generate new Identity**. Actor: Owner1.
This action is intended for generating a 
new ownership for a given Identity.  For simplicity, Identity is the address of Owner1.
Using the two-argument ChangeOwner function, Onwer1 implicitly assigns itself as the
owner of the identity address.

- **Signed ownership changing**. Actor: Owner1.
This action is intended to change the ownership of a given identity. In particular, Owner1 
requests to change the ownership of the given Identity in favor of Owner2.
To do this, according to the reference implementation, Owner1 creates a "raw transaction" that
calls the two-argument changeOwner function, specifying the address of the Identity and Owner2 
as newOwner. 
Then Owner1 signs the raw transaction to obtain the signature values (v, r, and s in the 
reference implementation). 
Finally, Owner1 uses these three values as arguments to call the changeOwnerSigned function, 
along with the identity and newOwner.
Note: Signature data can be in different forms on the EVM blockchain.

- **Create a delegate**. Actor: Owner2
This action is intended to allow Owner2 adding a delegate to a givent Identity, via the changeOwnerSigned function.
To do this, according to the implementation references, Owner2 creates a "raw transaction" for
calling the 4-argument addDelegate function, passing the identity address, delegateType, 
the address of the delegate, and the number of blocks for which the delegation remains valid. 
Then, Owner2 signs the raw transaction to get the values of v, r, and s. 
Finally, Owner2 uses these values as arguments to call the addDelegateSigned function, 
along with parameters to specify the identity, delegateType, the address of the delegate, 
and the validity, namely the number of blocks for which the delegation is valid.

- **Delegate validity check**. Actor: Owner2
Using validDelegate, this action verifies that the delegation is valid within the validity term and not valid beyond the validity term.


## Expected Features

- Abort conditions
- Hash
- Versig on arbitrary messages
- Dynamic data structures


## Implementations

- **Solidity/Ethereum**: 
- **Anchor/Solana**: 
- **Aiken/Cardano**:
- **PyTeal/Algorand**:
- **SmartPy/Tezos**:
- **Move/Aptos**:
