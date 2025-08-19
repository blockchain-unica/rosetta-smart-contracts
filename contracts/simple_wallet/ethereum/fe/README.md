# Simple wallet

This contract acts as a native cryptocurrency deposit, it allows deposit, transaction creation, execution, with storaging of previous transactions in memory, and withdrawal.

## Initialization

`pub fn __init__(mut self, ctx: Context, _owner: address)`

At deploy time, the contract requires a single parameter, an address that will be the owner of the wallet.

## Technical challenges

This contract suffers from the lack of dynamic arrays, which Fe does not support. Therefore, I tried a different approach with a Map, mapping every contract to its own transaction in order to simulate a dynamic array keeping trace of the number of transactions in an integer.

Unluckily, Fe does not support maps with non-primitive types:

```
transactions: Map<Transaction, u256>
│                 ^^^^^^^^^^^ this has type "Transaction"; expected a primitive type
```

This happened when I tried to create mapping between Transactions and integers.

## Workaround

Being forced to work with static arrays, for testing purposes i created a fixed array of 5 elements. The wallet only supports 5 transactions after which refuses any creation of a transaction.

**Note: the contract actually puts a transaction in the wallet at transaction creation. So, creating 5 transactions and not executing them already fills the wallet's space.**

**Consider that these transactions can be executed even if the array is full.**

When trying to create a sixth transaction the owner is prompted to create a new wallet. They can withdraw all the money in the contract at any moment, via the withdraw function, so no money gets stuck in the contract.

## Execution

After the contract is deployed, 4 functions can be called.

### deposit()

This function can be called only by the owner of the simple wallet, and lets deposit whatever amount of native cryptocurrency.

### createTransaction(_to: address, _value: u256, _data: Array<u8, 1>)

This function can only be called by the owner, and sets up a transaction. In this phase, the balance is not checked.

What is checked is whether the `_to` (recipient) is valid and if the wallet still has space in the static array to create transactions.

`_value` is the amount of ETH to transfer.

`_data` is the function to call (with params) of the recipient

In this phase, if the user does everything correctly, a new transaction is created in the array.

### executeTransaction(_txId: u256)

This function, only callable by the owner, checks if the given transaction id `_txId` refers to an existing transaction and ensures the transaction was not executed yet.

It then checks if the balance of the contract is sufficient to complete the transaction. after that, the transaction is completed only if all conditions are met.

### withdraw()

This function can only be called by the owner and simply transfers all the content of the wallet in the owners own account.
