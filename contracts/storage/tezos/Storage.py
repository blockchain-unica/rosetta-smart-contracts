import smartpy as sp

@sp.module
def main():
    class Storage(sp.Contract):
        def __init__(self):
            self.data.bytes = sp.bytes("0x00")
            self.data.string = ""
            
        @sp.entrypoint
        def storeBytes(self, _bytes):
            self.data.bytes = _bytes
            
        @sp.entrypoint
        def storeString(self, _string):
            self.data.string = _string
            
@sp.add_test(name = "Storage")
def test():
    #set scenario
    sc = sp.test_scenario(main)
    #create admin
    admin = sp.test_account("admin")
    #create users
    pippo = sp.test_account("pippo")
    #create object
    Storage = main.Storage()
    #start scenario
    sc += Storage


    #entrypoint calls
    sc.h1("storeBytes")
    Storage.storeBytes(sp.bytes("0x01"))
    sc.h1("storeString")
    Storage.storeString("Hello World")