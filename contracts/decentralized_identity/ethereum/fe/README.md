# Decentralized identity

This use case represents Self-sovereign identity.
There are some crucial variables that represent specific elements in this scenario.

- *Identity* -> is a blockchain address that has the property of belonging to another address.
- *Owner* -> is an account that has the authority to perform actions on the identity.
- *Delegate* -> is an account that could have some privileges for a specific identity. The owner of an identity can assign a delegate to it, specifying the type of delegate. A delegate remains valid for a certain period of time (expressed in blocks).
- *Actor* -> is the account that performs actions. In public functions, it is always the message sender.

In this use case, we define two actors: Owner1, Owner2

After creation, it will be posible to generate a new identity, change its ownership in a simple way or in a "signed" more complex way.
The same applies to delegates.

Finally, it's also possible to execute a delegate validity check.
Tthis action verifies that the delegation is valid within the validity term and not valid beyond the validity term.

## Technical challenges

Fe, being an incomplete project, doesn't allow for a perfect implementation of this use case, but with some adjustments it's possible to make it work.

Specifically, the Solidity implementation generates the bytes32 hash this way:

```
bytes32 hash = keccak256(abi.encodePacked(bytes1(0x19), bytes1(0), this, nonce[identityOwner(identity)], identity, "changeOwner", newOwner));
```

Fe does not support an equivalent of "abi.encodePacked", or it is not documented. So I used a simple abi_encode() function. Furthermore, I simplified the hash creation by removing "self", and "nonce[identityOwner(identity)]" from the creation of the hash because Fe doesn't allow for the existance of tuples with variable lenght.

This is the simplified Fe implementation of the hash:

```
let hash: u256 = keccak256((0x19, 0x0, identity, "changeOwner", newOwner).abi_encode());

```

Also, Fe doesn't have a native ecrecover function. I found in the source code of Fe a working implementation of such function, so I copied it in this contract and I adapted it to work correctly for this use case.

## Initialization

This contract doesn't perform any specific action at deploy time.

## Execution

After the contract is deployed, 10 functions can be called.

### identityOwner(identity: address)

This function simply returns the owner of the specified identity. If there is no owher specified yet, the owner is the identity itself.

### ec_recover(hash: u256, v: u256, r: u256, s: u256)

This is an internal function that substitutes the "ecrecover()" function built in Solidity.
Performs  signature recovery to extract the signer's address.

### checkSignature(identity: address, sigV: u256, sigR: u256, sigS: u256, hash: u256)

This internal function calls ec_recover() to obtain the original signer's address, then checks for it to match with the identity owner saved in the contract.

### validDelegate(identity: address, delegateType: Array<u8, 32>, delegate: address)

This function simply checks whether the delegate is still valid or has expired.

### _changeOwner(identity: address, actor: address, newOwner: address)

This internal function ensures the actor is the right one by checking the caller of the function, and changes the owner of the identity.

### changeOwner(identity: address, newOwner: address)

This is the exposed public function that receives the call to change ownership of an identity. This is the simplified version of changing an identity, where the owner directly calls the function and its identity is verified by checking the address that is calling.

### changeOwnerSigned(identity: address, sigV: u256, sigR: u256, sigS: u256, newOwner: address)

This is the signed version of the changeOwner() function. This version can be called by any address as long as it provides the correct signature values that will be elaborated by the contract to extract the actual owner's signature. If the right signature was provided, the ownership is changed.

### _addDelegate(identity: address, actor: address, delegateType: Array<u8, 32>, delegate: address, validity: u256)

This internal function adds a delegate the simple way, just by checking the caller is the correct address that is authorized to perform the action.

### addDelegate(identity: address, delegateType: Array<u8, 32>, delegate: address, validity: u256)

This is the public function that calls the internal _addDelegate() that performs the addition of the delegate in the simple way. It also lets set up the delegateType and validity of the delegation.

### addDelegateSigned(identity: address, sigV: u256, sigR: u256, sigS: u256, delegateType: Array<u8, 32>, delegate: address, validity: u256)

This is the signed version of the addDelegate() function. This version can be called by any address as long as it provides the correct signature values that will be elaborated by the contract to extract the actual owner's signature. If the right signature was provided, the delegation is added.
