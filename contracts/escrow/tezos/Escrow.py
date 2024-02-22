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


@sp.add_test()
def test():
    # set scenario
    sc = sp.test_scenario("Escrow", main)
    # create admin
    seller = sp.test_account("seller")
    # create users
    buyer = sp.test_account("buyer")
    # create object
    Escrow = main.Escrow(seller.address, buyer.address, sp.tez(1))
    # start scenario
    sc += Escrow