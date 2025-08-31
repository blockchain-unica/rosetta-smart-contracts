# Factory

This use case requires to generate a contract by doing so within another contract.

## Technical challenges

Fe should be able to alter the chain and add a new contract to it via the `<OBJECT>`.create() function. This unfortunately doesn't alter the local blockchain in a testing environment and it is not understandable whether this is a Fe bug or is an unexpected interaction with Foundry, the toolchain to test the blockchain locally. Basically, the created contract by the factory is fully functional within the Factory contract, but the returned address points to nothing and the blockchain wasn't modified. So the contract wasn't actually deployed on-chain.

## Factory contract

`pub fn __init__(mut self, ctx: Context)`

At deploy time the contract just sets an internal counter to zero, since arrays are static in Fe, I set to 100 the maximum amount of contracts to be created by the Factory.

### Execution

After the contract is deployed, 2 functions can be called.

### createProduct(_tag: String<100>)

This function generates a new Product contract and sets its tag (a string) to a given value as a parameter, and returns the contract address of the newly deployed contract.

### getProducts()

Returns the list of all the products that have been created until that moment.

## Product contract

This contract is the produced contract by the factory.

### Execution

At deploy time, this contract sets the owner to be who generated the product and sets the factory address as the one who created that contract.

After deployment, 4 functions can be called.

### setTag(_tag: String<100>)

This function sets the tag of the contract to a given _tag as a parameter which is a String.

### getTag()

This function returns the tag (string) that was set for that product.

### getFactory()

This function returns the address of the factory that created the product.

### getAddress()

This function returns the address of the Product contract itself. It is used for testing purposes.
