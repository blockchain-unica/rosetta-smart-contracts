# Upgradeable Proxy

This use case is designed to understand whether a Smart Contract language can create a contract that acts as a Proxy that can be upgraded with a new implementation of another contract.

This use case involves 3 contracts that are deployed in this order:

1. Logic
2. TheProxy
3. Caller

Logic -> contains the actual logic of the contract that is the target of the proxy.

TheProxy -> is the actual Proxy that redirects the call to the current Logic implementation based on what is set inside the proxy itself.

Caller -> is the contract that in actually makes the call to TheProxy to reach Logic.

## Technical challenges

This use case is implemented in a low-level way that acts as a fully functional proxy in Solidity. Unfortunately, Fe is likely not capable (or not documented enough) to provide the same functionality. I have found the existance of a ctx.raw_call() function but its usage is unclear.
For that reason, this implementation of the Upgradeable Proxy is more high level and there are some limitations.

### Limitations

The Logic contract that can be upgraded is treated as a Fe Ingot (we have already seen Ingots in pricebet use case). Basically, it is required to have an Ingot (library) that defines the variables and in general the signatures of all the functions of Logic (this implies that a new implementation on Logic should have the same signatures of all functions, but the content of those functions can change. In Solidity, this limitation is completely absent.

## TheProxy contract

`pub fn __init__(mut self, ctx: Context, _logic: address)`

At deploy time the contract takes an address that represents the Logic contract to redirect the calls to, and sets as Admin the deployer of the contract.

Finally, it loads into an array the functions that are present (and won't change) into Logic contract.

### Execution

After the contract is deployed, 4 functions can be called.

### implementation()

Simply returns the address of the current Logic address the proxy is set to.

### getAdmin()

Returns the address of the admin of the proxy who is whoever deployed the contract.

### upgradeTo(newImplementation: address)

This function upgrades the proxy with a new implementation of Logic via an address to where the new implementation of Logic is supposed to be.

### call(to_call: u8, to_check: address)

This function takes two parameters:

- to_call -> represents the function to call. It is taken as an integer because I'm using an Enum to represent functions beacause fe limitations prohibit to check equality between two Strings.
- to_check -> is the parameter that will be passed to the function the proxy is pointing to. The Logic contract has to check a balance of an address in our case.

## Logic contract

The logic contract exists in two versions:

- Ingot version -> is a version of the contract that only represents its signature. Has no actual implementation and acts as an interface.
- Real implementation -> is the actual Logic contract that gets deployed on-chain and is then set up to be contract the proxy points to.

### Execution

Logic contract only has one function.

### check(_toCheck: address)

This function checks the balance of the given address as parameter and returns true if it's lower than 100, otherwise it returns false.

## Caller contract

### Execution

The caller contract just has one function that is supposed to call Logic passing through the Proxy.

### callLogicByProxy(_proxy: address)

This function takes the proxy as a parameter as an address, and calls the function "check" on also passing the parameter. Proxy will do the rest.
