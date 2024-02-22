import smartpy as sp


@sp.module
def main():
    class SimpleTransfer(sp.Contract):
        def __init__(self):
            self.data.receiver = None

        @sp.entrypoint
        def deposit(self, receiver):
            # update data
            self.data.receiver = sp.Some(receiver)

        @sp.entrypoint
        def withdraw(self):
            # check receiver
            assert self.data.receiver == sp.Some(sp.sender), "Wrong Address"
            # withdraw
            sp.send(self.data.receiver.unwrap_some(), sp.balance)

@sp.add_test()
def testSimpleTransfer():
    # set scenario
    sc = sp.test_scenario("SimpleTransfer", main)
    # create object SimpleTransfer
    sitr = main.SimpleTransfer()
    # start scenario
    sc += sitr