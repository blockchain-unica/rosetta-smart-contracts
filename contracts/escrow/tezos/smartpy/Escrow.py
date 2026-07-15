import smartpy as sp

@sp.module
def main():
    states: type = sp.variant(
        WAIT_DEPOSIT=sp.unit,
        WAIT_RECIPIENT=sp.unit,
        CLOSED=sp.unit)
    
    class EscrowRosetta(sp.Contract):
        def __init__(self, amount: sp.mutez, buyer: sp.address, seller: sp.address):
            self.data.buyer = buyer
            self.data.seller = seller
            self.data.amount = amount
            self.data.state = sp.cast(sp.variant.WAIT_DEPOSIT(), states)
        
        @sp.entrypoint
        def deposit(self):
            assert sp.sender == self.data.buyer, "Only the buyer"
            assert self.data.state == sp.cast(sp.variant.WAIT_DEPOSIT(), states), "Invalid State"
            assert sp.amount == self.data.amount, "Invalid amount"
            self.data.state = sp.cast(sp.variant.WAIT_RECIPIENT(), states)

        @sp.entrypoint
        def pay(self):
            assert sp.sender == self.data.buyer, "Only the buyer"
            assert self.data.state == sp.cast(sp.variant.WAIT_RECIPIENT(), states), "Invalid State"
            self.data.state = sp.cast(sp.variant.CLOSED(), states)
            
            sp.send(self.data.seller, self.data.amount)

        @sp.entrypoint
        def refund(self):
            assert sp.sender == self.data.seller, "Only the seller"
            assert self.data.state == sp.cast(sp.variant.WAIT_RECIPIENT(), states), "Invalid State"
            self.data.state = sp.cast(sp.variant.CLOSED(), states)
            
            sp.send(self.data.buyer, self.data.amount)

def _compile_targets():
    seller = sp.address("tz1SL2xBdmLSD2W3Hs84SfH912xDpYtAjsaa")
    buyer = sp.address("tz1aLPm3WynyHRXFvjjdHZDKEjHZVvQMGxqU")
    amount = sp.mutez(1000)
    
    """Entry point for in-process compilation by the toolchain."""
    return [
        (main.EscrowRosetta, (amount, buyer, seller)),
    ]

