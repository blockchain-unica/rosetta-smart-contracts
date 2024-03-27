import smartpy as sp


@sp.module
def main():
    class SimpleTransfer(sp.Contract):
        def __init__(self, owner, receiver):
            self.data.owner = owner
            self.data.receiver = receiver

        @sp.entrypoint
        def deposit(self):
            #check if the sender is the owner
            assert self.data.owner == sp.sender

        @sp.entrypoint
        def withdraw(self):
            # check receiver
            assert self.data.receiver == sp.sender, "Wrong Address"
            # withdraw
            sp.send(self.data.receiver, sp.balance)

@sp.add_test()
def testSimpleTransfer():
    # set scenario
    sc = sp.test_scenario("SimpleTransfer", main)
    owner = sp.test_account("owner")
    receiver = sp.test_account("receiver")
    # create object SimpleTransfer
    sitr = main.SimpleTransfer(owner.address, receiver.address)
    # start scenario
    sc += sitr