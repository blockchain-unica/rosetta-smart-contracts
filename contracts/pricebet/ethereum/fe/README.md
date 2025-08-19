# Price bet

This use case allows anyone to bet on a future exchange rate between two tokens. It is useful to demonstrate how Fe handles two contracts interacting with one another.

## Functionality

The contracts involved are 3:
1. PriceBet
2. Oracle
3. Oracle (ingot)

- The "Oracle" contract is the actual cotract that will be deployed on chain.
- The "Oracle (ingot)" is a copy of the "Oracle" contract that is not actually deployed. It's purpose is to be imported into the "PriceBet" contract to make sure PriceBet know how a "Oracle" contract works. 
It acts as a declaration of the signatures of all the functions of the contract.
This way of importing contracts is required by Fe itself.

## PriceBet contract

This contract is the centre of the operation of the betting system.

Initialization

`pub fn __init__(mut self, ctx: Context, _oracle: address, _deadline: u256, _exchange_rate: u256)`

This contract takes 3 arguments:

1. **_oracle** -> the address of the **contract** already deployed on the blockchain that will act as an oracle.
2. **_deadline** -> the deadline expressed in blocks after which the bet timeouts.
3. **_exchange_rate** -> the expected exchange rate the deployer of the contract chooses. The bet will be based on this exchange rate.

The deployer also sends ETH to the contract, and this ETH will be set up as the initial pot of the contract that has to be matched by any other player that desires to join.

### Execution

After the contract is deployed, 4 functions can be called.

#### join()

This function allows to anyone to join the bet and requires to send the exact amount of ETH that was set up as initial pot by the owner at deploy time. Only one user can join.

#### win()

This function calls the Oracle (oracle details will be discussed later) and compares it with the expected exchange rate.

Leter it checks if the deadline is expired, if the sender is the player who joined and after that whether they won or not.

If they won, they immediately a transaction sends the whole contract balance on their own balance.

#### addBlock()

This is a test function, created only to be able to create blocks on demand on the chain. Its purpose is to be able to check all possibilities and making the contract expire on-demand by the unit tests.

#### timeout()

This function has the purpose of checking whether time is out, and if it is, the whole balance of the contract is given to the owner (deployer) of the contract. This also works if nobody joins in time, they just get their own bet back.

## Oracle contract

The oracle contract is the external contract that is called by the PriceBet contract to check the current exchange rate in our use case.

It has not initialiation function and just has a simple function.

#### get_exchange_rate()

This function simply returns the current exchange rate for our use case.

## Oracle (ingot) "contract"

This is not technically a contract, in fact Fe calls it "Ingot". It is a library that can be imported by Fe and lets use it as as an imported contract that is deployed inside PriceBet.

Since the purpose of this use case is to check whether two contracts can interact between each other, I created this Ingot to make it possible to have the interface of the actual Oracle, later on I initialized an Oracle instance with the address of the Oracle deployed on chain and this worked fine in Fe.

Its implementation is similar to normal Oracle, as it acts as an interface but has not logic inside it.
