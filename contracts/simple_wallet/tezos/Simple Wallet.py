import smartpy as sp
from utils import utils


@sp.module
def main():
    class SimpleWallet(sp.Contract):
        def __init__(self, _owner):
            self.data.owner = _owner
            self.data.transactions = {None : None}
            self.data.currentID = 0


        @sp.entry_point
        def deposit(self):
            assert sp.sender == self.data.owner, "You are not the owner"
            

        @sp.entry_point
        def createTransaction(self, _recipient, _value, _data):
            assert sp.sender == self.data.owner, "You are not the owner"

            transaction = sp.record(recipient = _recipient, value = _value, data = _data)
            executed = False
            self.data.currentID += 1

            sp.emit(self.data.currentID) #return transaction ID
                
            self.data.transactions = sp.update_map(sp.Some(self.data.currentID), sp.Some(sp.Some((transaction, executed))), self.data.transactions)


        @sp.entry_point
        def executeTransaction(self, ID):
            assert self.data.transactions.contains(sp.Some(ID)), "No transaction found"
            details = self.data.transactions[sp.Some(ID)].unwrap_some()
            assert not sp.snd(details), "Transaction already executed"

            transaction = sp.fst(details)
            sp.send(transaction.recipient, transaction.value)
            details = (transaction, True)

            self.data.transactions = sp.update_map(sp.Some(ID), sp.Some(sp.Some(details)), self.data.transactions)

            
        @sp.entry_point
        def withdraw(self):
            assert sp.sender == self.data.owner, "You are not the owner"
            
            sp.send(sp.sender, sp.balance)
            
            
            


@sp.add_test(name = "Simple Wallet")
def testWallet():
    #set scenario
    sc = sp.test_scenario([utils,main])
    #create admin
    admin = sp.test_account("admin")
    #create object simple wallet
    simpleWallet = main.SimpleWallet(admin.address)
    #start scenario
    sc += simpleWallet

    #create users
    pippo = sp.test_account("pippo")
    sofia = sp.test_account("sofia")
    sergio = sp.test_account("sergio")

    sc.h1("Deposit")
    simpleWallet.deposit().run(sender = admin, amount = sp.mutez(100))
    sc.h1("Create Transaction")
    transaction = sp.record(_recipient = pippo.address, _value = sp.mutez(10), _data = ()) 
    simpleWallet.createTransaction(transaction).run(sender = admin)
    sc.h1("Execute Transaction")
    simpleWallet.executeTransaction(1)
    sc.h1("Withdraw")
    simpleWallet.withdraw().run(sender = admin)
    
    


            
            


    