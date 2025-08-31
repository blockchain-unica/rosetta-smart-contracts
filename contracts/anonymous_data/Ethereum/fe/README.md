# Anonymous data

This use case is a contract that allows multiple users to store data on-chain. Stored data is associated with a cryptographic hash in a way that only the user who can generate that hash can retrieve it.

## Technical challenges

Since Fe does not support dynamic data structures (Solidity can), I was forced to cap the amount of any data sructure to a fixed amount.

There can only be 100 users storing data, and the stored data has to be a single uint256.

## Initialization

`pub fn __init__(mut self, ctx: Context)`

At deploy time, this contract sets the owner as the deployer. It also sets the ID_Counter to zero. This ID is used to keep track of how many users data have been stored.

## Execution

After the contract is deployed, 4 functions can be called.

### storeData(data: u256, user_ID: u256)

This function lets the sender store data in form of u256. His associated ID is the Hash that will be required to retrieve the data.

### getID(nonce: u256)

This function can be used to generate the ID, a hash that combines the user address with an arbitrary given Nonce that will be the ID to provide to storeData() to safely store the data, and also to retrieve it afterwards.

### getAllData()

This function is callable only by the owner of the contract, and returns as an array of 100 u256, all data saved on the contract by the users.

### getMyData(nonce: u256)

This function returns the user's stored data if the address is correct and the given Nonce matches the one given at storeData().