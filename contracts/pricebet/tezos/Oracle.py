import smartpy as sp
    
@sp.module
def main():
class Oracle(sp.Contract):
        def __init__(self):
            self.data.price = sp.tez(40)
            
        @sp.entrypoint
        def getPrice(self, callBack):
            #callBack
            contract = sp.contract(sp.mutez, callBack , "setter").unwrap_some(error="ContractNotFound")
            sp.transfer(self.data.price, sp.tez(0),contract)      
        
