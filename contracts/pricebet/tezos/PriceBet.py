import smartpy as sp
    
@sp.module
def main():
    class PriceBet(sp.Contract):
        def __init__(self, owner, oracle, deadline, exchangeRate):
            self.data.owner  = owner
            self.data.oracle = oracle
            self.data.deadline = deadline
            self.data.exchangeRate = sp.cast(exchangeRate, sp.mutez)
            self.data.bettor = sp.cast(owner, sp.address)

        @sp.entrypoint
        def join (self):
            #check if amount correspond
            assert sp.amount == sp.balance-sp.amount, "The amount is incorrect" 
            
            self.data.bettor = sp.sender    
            
        @sp.entrypoint
        def win(self):
            #check if join was called
            assert self.data.bettor != self.data.owner, "Anyone joined"
            #check deadline
            assert sp.now < self.data.deadline, "Deadline reached"
            #call oracle 
            contract = sp.contract(sp.address, self.data.oracle , "getPrice").unwrap_some(error="ContractNotFound")
            sp.transfer(sp.self_address(), sp.tez(0), contract)

        @sp.entrypoint 
        def setter(self, price):
            sp.cast(price, sp.mutez)
            #set price
            assert price > self.data.exchangeRate, "Not Win"
            
            sp.send(self.data.bettor, sp.balance)
            
        @sp.entrypoint
        def timeout(self):
            #check if is the admin
            assert sp.sender == self.data.owner, "You are not the admin"
            #check deadline
            assert sp.now > self.data.deadline, "Deadline not reached"
            
            sp.send(self.data.owner, sp.balance)   
        
    
    
