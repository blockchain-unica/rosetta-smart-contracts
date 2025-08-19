# Escrow

This contract acts as an intermediary between a seller and a buyer, aiming to protect the buyer from possible non-delivery from the seller, creating a trustless environment that enforcer fairness in the transaction.

## Technical challenges

Types of enums created at runtime and Strings types can't be compared in Fe. Because of that, I had to implement a function in the Fe's enum native functionality that actually returns an integer.
Also, Fe needs the enum to be declared **outside** the contract.

Below are shown the errors of Fe compiler that led me to work with integer comparison instead of anything else.

`error: States type can't be compared with the == operator`
`error: String<15> type can't be compared with the == operator`

In solidity:

`require(state == States.WAIT_DEPOSIT, "Invalid State");`

In Fe:

`assert (self.state == States::WAIT_DEPOSIT.read()), "Invalid State"`

As shown, in Fe I compare the state (that is a u8 type) with an enum to which I apply the custom read() function I created to return the u8 type number represented by the enum.

Also, Fe does not have the "modifier" functionality opposed as Solidity, so I had to enforce the identity of the seller and buyer the classical way.

## Initialization

`pub fn __init__(mut self, ctx: Context, _amount: u256, _buyer: address, _seller: address)`

At deploy time the contract takes a uint256 representing the transaction amount and two addresses.

The former representing, the buyer.

The latter, the seller.

The seller is whoever deployed the contract and the value of the transaction is set via the *_amount* variable.

## Execution

After the contract is deployed, 3 functions can be called.

### deposit()

Only the buyer can call this function.

They are required to deposit the exact amount in ETH as requested by the seller at deploy time. The state of the contract is updated accordingly whenever the deposit is successful.

### pay()

Only the buyer can call this function, and by calling it, the contract deposits the entirety of its balanace (the price the seller required) on the sellers' account, confirming the purchase and completing it. The "States" system ensures this function can only be called once and only if deposit() was successful and refund() and pay() were not called previously.

### refund()

Only the seller can call this function, and by calling it, the contract deposits the entirety of its balance (the price the seller required) on the buyer's account, implying the purchase is cancelled and the buyer is refunded. The "States" system ensures this function can only be called once and only if deposit() was successful and pay() and redund() were not called previously.
