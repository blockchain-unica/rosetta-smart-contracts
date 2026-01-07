# Payment Splitter in Vyper

## State variables 

```py
totalShares: uint256
totalEthReleased: uint256
payees: DynArray[address, 10]
sharesOf: HashMap[address, uint256]
releasedTo: HashMap[address, uint256]

event ReleasedTo:
    to: address
    amount: uint256
```
- `totalShares` — the total number of shares assigned to all payees.
- `totalEthReleased` — the cumulative amount of ETH that has been released (withdrawn) from the contract to all payees.
- `payees` — a dynamic array containing the addresses of all registered payees. 
- `sharesOf` — a mapping that associates each payee’s address with the number of shares they own.
- `releasedTo` — A mapping that tracks the total amount of ETH already withdrawn by each payee.

## Initialization

```py 
deploy
def __init__(_shareholders: DynArray[address, NUM_OF_PAYEES], _shares: DynArray[uint256, NUM_OF_PAYEES]):
    assert len(_shareholders) == len(_shares), "Payees and shares length mismatch"

    for i: uint256 in range(NUM_OF_PAYEES):
        if i >= len(_shares):
            break
        self._addPayee(_shareholders[i], _shares[i])
```
At deployment, the constructor initializes the list of payees and their respective shares. 

The following conditions are enforced:
- The two arrays must have the same length 
- Each payee is added through the internal function **_addPayee** which perform additional validation (non-zero address, positive shares, no duplicate entries).


## addPayee (Helper function)

``` py
@internal
def _addPayee(_payee: address, _shares: uint256):
    assert _payee != empty(address), "Empty address"
    assert _shares > 0, "Account has no shares"
    assert self.sharesOf[_payee] == 0, "Account already owns shares"

    # Append new payee
    self.payees.append(_payee)
    self.sharesOf[_payee] = _shares
    self.totalShares += _shares
```

This internal function is used during deployment to add a new payee and assign its corresponding number of shares.


## receive

```py 
@payable
@external
def receive():
    # Accept ETH payments
    pass
```

An external payable function that allows the contract to receive ETH.
It is automatically executed by the EVM when ETH is sent to the contract without calldata, and does not require any logic beyond accepting the transfer.


## release 

```py 
@external
def release(_account: address):
    # Check if account has any shares
    assert self.sharesOf[_account] > 0, "Account has no shares"

    amount: uint256 = self.getReleasableTo(_account)

    # Check amount is greater than zero
    assert amount > 0, "Account is not due for payment"
    self.totalEthReleased += amount 
    self.releasedTo[_account] += amount
    send(_account, amount)

    log ReleasedTo(to=_account, amount=amount)
```
This function allows a payee to withdraw the portion of ETH they are entitled to, based on their share of the total allocation.

It first verifies that the given account owns shares and computes the amount currently releasable to it. If the calculated amount is greater than zero, the function updates the accounting state (`totalEthReleased` and `releasedTo`) and transfers the ETH to the payee.
A `ReleasedTo` event is emitted to record the payment.


## getReleasableTo (Helper function)

```py 
@view
@internal
def getReleasableTo(_account: address) -> uint256:
    totalBalance: uint256 = self.balance + self.totalEthReleased
    return self.pendingPayment(_account, totalBalance, self.releasedTo[_account])
```
This internal view function computes the total amount of ETH that can currently be released to a given account. 
It reconstructs the total historical balance of the contract (current balance + released ETH) and delegates the actual calculation to **pendingPayment**.


## pendingPayment (Helper function)

```py 
@view    
@internal
def pendingPayment(_account: address, _totalBalance: uint256, alreadyReleased: uint256) -> uint256:
    return ((_totalBalance * self.sharesOf[_account]) // self.totalShares) - alreadyReleased
```
This internal helper function calculates the pending payment owed to an account.


## Differences between the Vyper and Solidity implementations

Implementation is similar to Solidity. The main differences are driven by language constraints rather than design choices. For example: 
- Vyper requires dynamic arrays to have a maximum length defined at compile time
