import smartpy as sp
from utils import utils

@sp.module
def main():
    class Auction(sp.Contract):
        def __init__ (self, startingBid, time, admin):
            self.data.admin = admin
            self.data.bidders = {}
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

            #check if someone already bidded and sender alredy bidded
            if self.data.top.address.is_some(): 
                #save the loosing bidder in map
                self.data.bidders = sp.update_map(self.data.top.address, sp.Some(sp.Some(self.data.top.amount)),self.data.bidders)
                #check for sender
                if self.data.bidders.contains(sp.Some(sp.sender)): 
                    #refund
                    sp.send(sp.sender, self.data.bidders.get(sp.Some(sp.sender), default = sp.Some(sp.mutez(0))).unwrap_some())
                    #delete from map
                    del self.data.bidders[sp.Some(sp.sender)]
                
                    
            #update top bidder    
            self.data.top.address = sp.Some(sp.sender)
            self.data.top.amount = sp.amount
            
            
        @sp.entry_point
        def withdraw(self):
            #check if the caller is a bidder
            assert self.data.bidders.contains(sp.Some(sp.sender)), "You are not a bidder"

            #refund
            sp.send(sp.sender, self.data.bidders.get(sp.Some(sp.sender), default = sp.Some(sp.mutez(0))).unwrap_some())
        
        @sp.entry_point
        def end(self, time):
            #check if the caller is the admin
            assert sp.sender == self.data.admin, "You are not the admin"

            #check if deadline is reached
            assert time >= self.data.duration, "Deadline is not reached"
            
            #withdraw all the assets
            sp.send(self.data.admin, sp.balance)
            
                      
        


@sp.add_test(name = "auctionTest")
def auctionTest():
    #set scenario
    sc = sp.test_scenario(main)
    #create admin
    admin = sp.test_account("admin")
    #create time 
    time = sp.timestamp_from_utc_now() #calculate execution time
    #new object Auction
    auction = main.Auction(sp.mutez(5), time, admin.address)
    #start scenario
    sc += auction

    #users
    sofia = sp.test_account("sofia")
    piero = sp.test_account("piero")
    carla = sp.test_account("carla")

    #start auction
    sc.h1("Start Auction")
    auction.start().run(sender = admin)
    #first bid
    sc.h1("First Bid")
    auction.bid().run(sender = sofia, amount = sp.mutez(100))
    auction.bid().run(sender = sofia, amount = sp.mutez(100),valid = False)
    #second bid
    sc.h1("Second Bid")
    auction.bid().run(sender = piero, amount = sp.mutez(10), valid = False)
    auction.bid().run(sender = piero, amount = sp.mutez(150))
    #sofia bid again
    sc.h1("Sofia Bid again")
    auction.bid().run(sender = sofia, amount = sp.mutez(160))
    #third bid
    sc.h1("Third Bid")
    auction.bid().run(sender = carla, amount = sp.mutez(1000))
    #sofia ask refund
    sc.h1("Sofia Refund")
    auction.withdraw().run(sender = sofia)
    #ending
    sc.h1("ending")
    time = time.add_minutes(2)
    auction.end(time).run(sender = sofia, valid = False)
    auction.end(time).run(sender = admin)
    
