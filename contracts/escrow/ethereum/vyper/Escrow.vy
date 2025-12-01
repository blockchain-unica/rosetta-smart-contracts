# pragma version ^0.4.0

seller: public(address)
buyer: public(address)
amount: public(uint256)
deposited: public(bool)
payed: public(bool)
refunded: public(bool)

@deploy
def __init__(_buyer: address, _amount: uint256):
    self.seller = msg.sender
    self.buyer = _buyer
    self.amount = _amount


@nonreentrant
@payable
@external
def deposit():
    assert not self.deposited, "Already deposited"
    assert msg.sender == self.buyer, "Only the buyer"
    assert msg.value == self.amount, "Invalid amount"

    self.deposited = True 


@nonreentrant
@external
def pay():
    assert self.deposited, "Empty balance, deposit first"
    assert msg.sender == self.buyer, "Only the buyer"
    assert not self.payed, "Already paid"
    assert not self.refunded, "Already refunded, cannot pay"
    self.payed = True 

    send(self.seller, self.amount)
    assert self.balance == 0, "Invalid balance"
    
    
@nonreentrant
@external
def refund():
    assert self.deposited, "Empty balance"
    assert msg.sender == self.seller, "Only the seller"
    assert not self.refunded, "Buyer already refunded"
    assert not self.payed, "Already paid, cannot refund"
    self.refunded = True

    send(self.buyer, self.amount)
    assert self.balance == 0, "Invalid balance"
    



    


    

