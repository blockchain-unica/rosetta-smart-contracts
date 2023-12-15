import smartpy as sp

@sp.module
def main():
    class Escrow(sp.Contract):
        # Define the contract's data
        def __init__(self, _seller, _buyer, _amount):
            self.data.seller = _seller
            self.data.buyer = _buyer
            self.data.amount = _amount
            
        @sp.entrypoint
        def deposit(self):
            assert sp.sender == self.data.buyer, "You are not the buyer"
            assert sp.amount == self.data.amount, "Amount incorrect"
            
        @sp.entrypoint
        def pay(self):
            assert sp.balance == self.data.amount, "Contract not funded yet"
            assert sp.sender == self.data.buyer, "You are not the buyer"
            
            sp.send(self.data.seller, sp.balance)
            
        @sp.entrypoint
        def refund(self):
            assert sp.sender == self.data.seller, "You are not the seller"
            
            sp.send(self.data.buyer, sp.balance)
            
@sp.add_test(name = "Escrow")
def test():
    #set scenario
    sc = sp.test_scenario(main)
    #create admin
    admin = sp.test_account("admin")
    #create users
    pippo = sp.test_account("pippo")
    #create object
    Escrow = main.Escrow(admin.address,pippo.address, sp.tez(1))
    #start scenario
    sc += Escrow


    #entrypoint calls
    sc.h1("Deposit")
    Escrow.deposit().run(amount = sp.tez(1), sender = pippo)
    sc.h1("Pay")
    Escrow.pay().run(sender = pippo)
    sc.h1("Withdraw")
    Escrow.refund().run(sender = admin)