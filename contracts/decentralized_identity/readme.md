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
Using the two-argument ChangeOwner function, Onwer1 implicitly assigns itself as the owner of the identity address.

- **Signed ownership changing**. Actor: Owner1.
To perform this action, the owner must first create a local transaction that it must sign to obtain the signature data.
To do this, according to the reference implementation, the owner must first create a "raw transaction" towards the two-argument changeOwner, specifying the address of the identity and the newOwner, then sign it to obtain the siguature values (v, r, and s in the reference implementation). Use these three values as arguments to changeOwnerSigned, along with the identity and newOwner.
Note: Signature data can be in different forms on the EVM blockchain.

- **Create a delegate**. Actor: Owner2
Owner2 adds a delegate via changeOwnerSigned to the identity.
To do this. According to the implementation references, the Owner2 creates a raw transaction for calling the 4-argument addDelegate function, passing the identity address, delegateType, the address of the delegate, and the number of blocks for which the delegation remains valid. Then, the Owner2 signs the raw transaction to get the values of v, r, and s. Finally, Owner2 uses these values as arguments to call the addDelegateSigned function, along with parameters to specify the identity, delegateType, the address of the delegate, and the validity, namely the number of blocks for which the delegation is valid.

- **Delegate validity check**. Actor: Owner2
Using validDelegate, this action verifies that the delegation is valid within the validity term and not valid beyond the validity term.