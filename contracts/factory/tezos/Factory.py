import smartpy as sp
from utils import utils


@sp.module
def main():
    class MyContract(sp.Contract):
        def __init__(self):
            self.data.tagstring = ""
            self.data.creator = None
        
        @sp.offchain_view()
        def getTag(self):
            assert sp.sender == self.data.creator.unwrap_some(), "you are not the creator"
            return self.data.tagstring

        @sp.offchain_view()
        def getFactory(self):
            return sp.self_address()
            
        
    class Factory(sp.Contract):
        def __init__(self, _owner):
            self.data.owner = _owner
            self.data.created = {None : None}
        
        @sp.entrypoint
        def createProduct(self, _tagstring, _creator):
            address = sp.Some(
                sp.create_contract(MyContract, None, sp.tez(0), sp.record(tagstring = _tagstring, creator = sp.Some(_creator)))
            )
            self.data.created = sp.update_map(sp.Some(_tagstring), sp.Some(address), self.data.created)

        @sp.offchain_view()
        def getProducts(self):
            return self.data.created


@sp.add_test(name = "Factory")
def testWallet():
    #set scenario
    sc = sp.test_scenario([utils,main])
    #create admin
    admin = sp.test_account("admin")
    #create object simple wallet
    Factory = main.Factory(admin.address)
    #start scenario
    sc += Factory

    #create users
    pippo = sp.test_account("pippo")
    sofia = sp.test_account("sofia")
    sergio = sp.test_account("sergio")

    sc.h1("Create Contract")
    Factory.createProduct(sp.record(_tagstring = "Primo", _creator = admin.address))
    #dyn0 = sc.dynamic_contract(0, Factory.createProduct("Primo"))
    sc.h1("All contracts created")
    sc.show(Factory.getProducts())
    sc.h1("getTag")
    

    
    
    


            
            


    