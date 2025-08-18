# HTLC

HTLC stands for *Hash Timed Locked Contract*. Involves two users named *committer* and *verifier*. This is to be intended as a proof of concept.

The owner deposits a collateral (in native cryptocurrency) in the contract, then specifies a deadline for the secret revelation, in terms of a delay from the publication of the contract, then specifies the receiver of the collateral, in case the deposit is not revealed within the deadline.

## Functionality

The contract is structured as follows.

### Initialization

`pub fn __init__(mut self, ctx: Context, v: address, h: u256, delay: u256)`

At deploy time the contract takes an **address**, a **uint256** representing the hash and another **uint256** representing che delay after which the contract expires.

The owner is whoever deployed the contract and the value inside the HTLC is the amount sent in the deployment transaction.


## Technical challenges

Implementing this contract required to understand how *keccak256()* works in Fe. It actually needs a variable of type `Array<u8, 32>` which is often referred to as "bytes" as a parameter and returns a `u256` type as opposed to Solidity, where in this use case in the Rosetta repository the function takes a **string** that gets encoded `abi.encodePacked(s)` and returns a `bytes32` type.

This difference required to change some types around the contract to make keccak256() function work properly.

## Execution

After the contract is deployed, 2 functions can be called.

### reveal(s: Array<u8, 32>)

Only the owner of the contract can call this function.

They are required to send a password, and if it matches the hash they get back the entirety of the contract balance.

### timeout()

This function can called to get the contract balance only if enough time has passed and the contract is expired. For testing purposes, I modified the blockchain in a specific order that makes it easier to understand the concept of "timeout" by looking at the unit tests.

Basically, in this implementation, time is supposed to be out only after reveal() is called successfully, creating a new block on the chain, making the contract expire.

Before that, time is not out and balance can not me redeemed. Obviously, being able to call timeout() only after reveal() is called successfully makes the timeout transfer zero ether, because the contract is already emptied. This it just a proof of concept to demonstrate the timeout function.
