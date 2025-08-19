# Vesting

This contract handles the maturation of cryptocurrency for a given beneficiary.

## Initialization

`pub fn __init__(mut self, ctx: Context, beneficiaryAddress: address, startTimestamp: u64, durationSeconds: u64)`

At deploy time, the contract takes an address, who is the beneficiary, a timestamp which represents the starting moment of the maturation process, and a duration in seconds, which represents how long the maturation process will take.

At deploy time, the user has to send a certain amount of ETH that represents the whole vesting that will be sent when the entirety of the preselected time has passed.

## Technical challenges

This contract is supposed to have some `immutable` variables, but fe still lacks something equivalent.

Fe is scheduled to have a *const* keyword, but it is not implemented yet.

This is what Fe prompts if trying to put a *const* keyword to a variable.

error: feature not yet implemented: contract *const* fields

## Execution

After the contract is deployed, one function can be called, despite there being 4, only one is public, the others are for internal functionality of the contract.

### release()

This is the only public function, that anyone can call. Whoever calls it, triggers the depositing of the ETH vested until that moment to the beneficiary. This function relies on the other 3 for its logic.

### releasable()

This is a private function that is called by release(), calculate and *returns* (*u256*) the amount of ETH than can be released at any given moment. It traces the amount of ETH given until that moment, so multiple calls to that function will add the ETH vested until that moment to the amount that was already emitted. Because it subtracts the amount that was already emitted until that moment.

### vestedAmount(time_stamp: u64)

This is the function that keeps trace of the total amount that will be vested over time. It passes this information to `_vestingSchedule()` that will actually calculate how much ETH to give to the beneficiary and return it as *u256*

Takes as an argument the current *time_stamp* to calculate the *totalAllocation*, which is the total of ETH that is being allocated for the beneficiary.

### _vestingSchedule(totalAllocation: u256, timestamp: u64)

This function calculates the amount of ETH to give to the beneficiary, given all the information calculated by the previous functions, and returns it as *u256*.

It takes as input *totalAllocation* and *timestamp* which are used to calculate the amount of ETH to give using the formula for the linear curve. This will output the total ETH to emit until a given moment, that will be reduced accordingly by the caller function based on the amount that was already emitted.
