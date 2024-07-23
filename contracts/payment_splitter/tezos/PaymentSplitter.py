import smartpy as sp
    
@sp.module
def main():
    class PaymentSplitter(sp.Contract):
        def __init__(self, admin, owners):
            self.data.admin = admin
            self.data.owners = sp.cast(owners, sp.map[sp.address, sp.nat])

        @sp.entrypoint
        def receive(self):
            #deposit
            pass
            
        
        @sp.entrypoint
        def release(self):
            #send shares
            sp.send(sp.sender, sp.split_tokens(sp.balance, self.data.owners[sp.sender], 100))
