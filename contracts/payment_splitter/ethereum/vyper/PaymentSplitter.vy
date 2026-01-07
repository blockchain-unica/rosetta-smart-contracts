# pragma version ^0.4.0

NUM_OF_PAYEES: constant(uint256) = 10
totalShares: uint256
totalEthReleased: uint256
payees: DynArray[address, NUM_OF_PAYEES]
sharesOf: HashMap[address, uint256]
releasedTo: HashMap[address, uint256]

event ReleasedTo:
    to: address
    amount: uint256


@deploy
def __init__(_shareholders: DynArray[address, NUM_OF_PAYEES], _shares: DynArray[uint256, NUM_OF_PAYEES]):
    assert len(_shareholders) == len(_shares), "Payees and shares length mismatch"

    for i: uint256 in range(NUM_OF_PAYEES):
        if i >= len(_shares):
            break
        self._addPayee(_shareholders[i], _shares[i])


@payable
@external
def receive():
    # Accept ETH payments
    pass


@internal
def _addPayee(_payee: address, _shares: uint256):
    assert _payee != empty(address), "Empty address"
    assert _shares > 0, "Account has no shares"
    assert self.sharesOf[_payee] == 0, "Account already owns shares"

    # Append new payee
    self.payees.append(_payee)
    self.sharesOf[_payee] = _shares
    self.totalShares += _shares

 
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


@view
@internal
def getReleasableTo(_account: address) -> uint256:
    totalBalance: uint256 = self.balance + self.totalEthReleased
    return self.pendingPayment(_account, totalBalance, self.releasedTo[_account])


@view    
@internal
def pendingPayment(_account: address, _totalBalance: uint256, alreadyReleased: uint256) -> uint256:
    return ((_totalBalance * self.sharesOf[_account]) // self.totalShares) - alreadyReleased


# Getters
@view
@external
def getTotalShares() -> uint256:
    return self.totalShares

@view
@external
def getTotalEthReleased() -> uint256:
    return self.totalEthReleased


@view
@external
def getPayee(_index: uint256) -> address:
    return self.payees[_index]

@view
@external
def getSharesOf(_account: address) -> uint256:
    return self.sharesOf[_account]


@view
@external
def getReleasedTo(_account: address) -> uint256:
    return self.releasedTo[_account]
   
