import smartpy as sp
from utils import utils


@sp.module
def main():
    class OracleBet(sp.Contract):
        def __init__(self):
            self.data.player1 = None
            self.data.player1Deposit = False
            self.data.player2 = None
            self.data.player2Deposit = False
            self.data.oracle = None
            self.data.winner = None
            self.data.deadline = sp.level + 1000

            
        @sp.entrypoint
        def deposit(self, params):
            player2 = sp.Some(params._player2)
            oracle = sp.Some(params._oracle)
            if self.data.player1 == None:
                assert sp.amount == sp.tez(1), "Amount incorrect, must be 1 tez"
                
                self.data.player1 = sp.Some(sp.sender)
                self.data.player1Deposit = True
                assert not oracle.unwrap_some() == sp.sender, "You can't be the oracle"
                self.data.oracle = oracle

                self.data.player2 = player2

            else: 
                assert sp.sender == self.data.player1.unwrap_some(), "You are already player 1"
                assert sp.sender == self.data.player2.unwrap_some(), "You are not player 2"
                assert sp.amount == sp.tez(1), "Amount incorrect, must be 1 tez"
                
                self.data.player2 = sp.Some(sp.sender)
                self.data.player2Deposit = True



        @sp.entrypoint
        def withdraw(self):
            assert sp.sender == self.data.player1.unwrap_some() or sp.sender == self.data.player2.unwrap_some(), "You are not a player"
            assert not self.data.winner == None, "The oracle didn't select any winner yet"
            assert sp.sender == self.data.winner.unwrap_some(), "You are not the winner"

            sp.send(sp.sender, sp.balance)

        @sp.entrypoint
        def election(self, _winner):
            assert sp.sender == self.data.oracle.unwrap_some(), "You are not the oracle"
            assert self.data.player1Deposit == True and self.data.player2Deposit == True, "1(2) player(s) didn't deposit yet"
            assert sp.level >= self.data.deadline, "You have to wait for deadline"

            self.data.winner = sp.Some(_winner)



@sp.add_test(name = "Oracle Bet")
def test():
    #set scenario
    sc = sp.test_scenario([utils,main])
    #create admin
    admin = sp.test_account("admin")
    #create object simple wallet
    OracleBet = main.OracleBet()
    #start scenario
    sc += OracleBet

    #create users
    pippo = sp.test_account("pippo")
    sofia = sp.test_account("sofia")
    sergio = sp.test_account("sergio")

    #entrypoint calls
    sc.h1("Deposit")
    OracleBet.deposit(_player2 = pippo.address, _oracle = sofia.address).run(amount = sp.tez(1), sender = sergio)

    
    

    
    
    


            
            


    