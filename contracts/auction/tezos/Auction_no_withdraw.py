import smartpy as sp
from utils import utils

@sp.module
def main():
    class Auction(sp.Contract):
        def __init__ (self, startingBid, time, admin):
            self.data.admin = admin
            self.data.top = sp.record(address = None ,amount = sp.mutez(0))
            self.data.startBid = startingBid
            self.data.duration = time
            self.data.isStart = False
            
        
        @sp.entry_point
        def start(self):
           #check if the caller is the admin
            assert sp.sender == self.data.admin, "You are not the admin"
            
            #start the auction
            self.data.isStart = True 
        
        @sp.entry_point
        def bid(self):
            #check if the Auction is started
            assert self.data.isStart == True, "The auction is not started yet"
            
            #check if the bid is grater then the current one
            assert sp.amount > self.data.top.amount, "The bid has to be greater"
            
            if not self.data.top.address == None: #refund
                sp.send(self.data.top.address.unwrap_some(), self.data.top.amount)
                
            self.data.top.address = sp.Some(sp.sender)
            self.data.top.amount = sp.amount
            

        @sp.entry_point
        def end(self, time):
            #check if the caller is the admin
            assert sp.sender == self.data.admin, "You are not the admin"

            #check if deadline is reached
            assert time >= self.data.duration, "Deadline is not reached"
            
            #withdraw all the assets
            sp.send(self.data.admin, sp.balance)
    
