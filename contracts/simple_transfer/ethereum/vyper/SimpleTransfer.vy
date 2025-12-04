
owner: public(address)
recipient: public(address)

@deploy
def __init__(recipient: address):
    self.owner = msg.sender
    self.recipient = recipient


@payable
@external
def deposit():
    assert msg.sender == self.owner, "Only the owner"
    assert msg.value > 0, "Invalid amount"


@nonreentrant 
@external
def withdraw(amount: uint256):
    assert msg.sender == self.recipient, "Only the recipient can withdraw"
    assert amount <= self.balance, "Insufficient balance"

    send(self.recipient, amount)





    
    

    


