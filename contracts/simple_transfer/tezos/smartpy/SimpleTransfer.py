import smartpy as sp

@sp.module
def main():
    class SimpleTransferRosetta(sp.Contract):
        def __init__(self, owner: sp.address, recipient: sp.address):
            self.data.recipient = recipient
            self.data.owner = owner

        @sp.entrypoint(with_storage="read-only")
        def deposit(self):
            assert sp.sender == self.data.owner
            assert sp.amount > sp.mutez(0)
            sp.emit(sp.record(sender=sp.sender, amount=sp.amount), tag="Deposited")

        @sp.entrypoint(with_storage="read-only")
        def withdraw(self, amount: sp.mutez):
            assert sp.sender == self.data.recipient, "only the recipient can withdraw"
            assert amount <= sp.balance, "the contract balance is less then required amount"
            sp.send(self.data.recipient, amount)
            sp.emit(sp.record(recipient=self.data.recipient, amount=amount), tag="Withdrawn")

def _compile_targets():
    owner = sp.address("tz1SL2xBdmLSD2W3Hs84SfH912xDpYtAjsaa")
    recipient = sp.address("tz1aLPm3WynyHRXFvjjdHZDKEjHZVvQMGxqU")
    
    """Entry point for in-process compilation by the toolchain."""
    return [
        (main.SimpleTransferRosetta, (owner, recipient)),
    ]

