import smartpy as sp

@sp.module
def t():
    tx : type = sp.record(
        recipient = sp.address,
        value = sp.mutez,
        data = sp.string
    )

@sp.module
def main():
    class SimpleWallet(sp.Contract):
        def __init__(self, _owner):
            self.data.owner = _owner
            self.data.transactions = {}
            self.data.currentID = 0

        @sp.entrypoint
        def deposit(self):
            assert sp.sender == self.data.owner, "You are not the owner"

        @sp.entrypoint
        def createTransaction(self, batch):
            sp.cast(batch, t.tx)
            
            assert sp.sender == self.data.owner, "You are not the owner"

            transaction = batch
            executed = False
            self.data.currentID += 1

            sp.emit(self.data.currentID)  # return transaction ID

            self.data.transactions = sp.update_map(self.data.currentID, sp.Some((transaction, executed)), self.data.transactions)

        @sp.entrypoint
        def executeTransaction(self, ID):
            sp.cast(ID, sp.nat)
            assert sp.sender == self.data.owner, "You are not the owner"
            assert self.data.transactions.contains(ID), "No transaction found"
            assert not sp.snd(self.data.transactions[ID]), "Transaction already executed"

            transaction = sp.fst(self.data.transactions[ID])
            details = (transaction, True)

            sp.send(transaction.recipient, transaction.value)
            self.data.transactions = sp.update_map(ID, sp.Some(details), self.data.transactions)

        @sp.entrypoint
        def withdraw(self):
            assert sp.sender == self.data.owner, "You are not the owner"
            sp.send(sp.sender, sp.balance)
        


@sp.add_test()
def testWallet():
    # set scenario
    sc = sp.test_scenario("Simple Wallet", [t,main])
    # create admin
    admin = sp.test_account("admin")
    # create object simple wallet
    simpleWallet = main.SimpleWallet(admin.address)
    # start scenario
    sc += simpleWallet



