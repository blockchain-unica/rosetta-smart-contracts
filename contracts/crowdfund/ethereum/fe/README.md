# Crowdfund

This contract allows users to donate ETH to fund a campaign. Users can't withdraw money unless the campaign is over and not successful. If the goal is reached in time, the receiver gets the entirety of the campaign raised money.

## Initialization

`pub fn __init__(mut self, receiver_: address, end_donate_: u256, goal_: u256)`

At deploy time the contract takes an address, and two integers.

The address is the receiver, who will get the money that was crowdfunded in case it is successful, the first integer is a **time limit** expressed in **blockchain blocks** for the end of the crowdfunding. The last integer is the **goal** in *Wei* that the receiver aims to achieve.

## Execution

After the contract is deployed, 3 functions can be called.

### donate()

If the crowdfunding is still open, users can donate native cryptocurrency, multiple times, and will be registered as donors.

### withdraw()

This function can only be called if the crowdfunding is over, and only if it was successful. When the function is successful the creator of the crowdfund gets the whole money raised on his account.

### reclaim()

This function can be called only if the crowdfunding is over and unsuccessful, meaning that the goal was not reached in time. By calling this function, the donor gets back the money he previously donated. If they have nothing to claim, the function fails by telling so.
