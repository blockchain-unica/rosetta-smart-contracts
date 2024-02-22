import smartpy as sp


@sp.module
def main():
    class SimpleWallet(sp.Contract):
        def __init__(self, _owner):
            self.data.owner = _owner
            self.data.transactions = {None: None}
            self.data.currentID = 0

        @sp.entrypoint
        def deposit(self):
            assert sp.sender == self.data.owner, "You are not the owner"

        @sp.entrypoint
        def createTransaction(self, _recipient, _value, _data):
            assert sp.sender == self.data.owner, "You are not the owner"

            transaction = sp.record(recipient=_recipient, value=_value, data=_data)
            executed = False
            self.data.currentID += 1

            sp.emit(self.data.currentID)  # return transaction ID

            self.data.transactions = sp.update_map(sp.Some(self.data.currentID),
                                                   sp.Some(sp.Some((transaction, executed))), self.data.transactions)

        @sp.entrypoint
        def executeTransaction(self, ID):
            assert self.data.transactions.contains(sp.Some(ID)), "No transaction found"
            details = self.data.transactions[sp.Some(ID)].unwrap_some()
            assert not sp.snd(details), "Transaction already executed"

            transaction = sp.fst(details)
            sp.send(transaction.recipient, transaction.value)
            details = (transaction, True)

            self.data.transactions = sp.update_map(sp.Some(ID), sp.Some(sp.Some(details)), self.data.transactions)

        @sp.entrypoint
        def withdraw(self):
            assert sp.sender == self.data.owner, "You are not the owner"

            sp.send(sp.sender, sp.balance)


@sp.add_test()
def testWallet():
    # set scenario
    sc = sp.test_scenario("Simple Wallet", main)
    # create admin
    admin = sp.test_account("admin")
    # create object simple wallet
    simpleWallet = main.SimpleWallet(admin.address)
    # start scenario
    sc += simpleWallet