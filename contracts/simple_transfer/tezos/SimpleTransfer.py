import smartpy as sp

@sp.module
def main():
    class SimpleTransfer(sp.Contract):
        def __init__(self):
            self.data.receiver = None
    
        @sp.entry_point
        def deposit(self, receiver):
            #update data
            self.data.receiver = sp.Some(receiver)
            
        @sp.entry_point
        def withdraw(self):
            #check receiver
            assert self.data.receiver == sp.Some(sp.sender) , "Wrong Address"
    
            #withdraw
            sp.send(self.data.receiver.unwrap_some(), sp.balance)

@sp.add_test(name = "SimpleTransfer")
def testSimpleTransfer():
    #set scenario
    sc = sp.test_scenario(main)
    #create object SimpleTransfer
    sitr = main.SimpleTransfer()
    #start scenario
    sc += sitr

    #create users
    sofia = sp.test_account("sofia")
    pippo = sp.test_account("pippo")

    #deposit
    sitr.deposit(sofia.address).run(amount = sp.tez(10))
    #withdraw
    sitr.withdraw().run(sender = sofia)