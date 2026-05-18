import smartpy as sp

@sp.module
def main():
    import smartpy.stdlib.utils as utils
    
    states: type = sp.variant(
        IDLE=sp.unit,
        REQ=sp.unit
    )
    
    class VaultRosetta(sp.Contract):
        def __init__(self, owner: sp.address, recovery: sp.address, wait_time: sp.nat):
            self.data.owner = owner
            self.data.recovery = recovery
            self.data.wait_time = wait_time
            self.data.receiver = sp.cast(None, sp.option[sp.address])
            self.data.request_time = sp.cast(None, sp.option[sp.nat])
            self.data.amount = sp.mutez(0)
            self.data.state = sp.cast(sp.variant.IDLE(), states)

        @sp.entrypoint
        def receive(self):
            assert sp.amount > sp.mutez(0)

        @sp.entrypoint
        def withdraw(self, receiver: sp.address, amount: sp.nat):
            assert self.data.state == sp.cast(sp.variant.IDLE(), states)
            assert utils.nat_to_mutez(amount) <= sp.balance
            assert sp.sender == self.data.owner
            self.data.request_time = sp.Some(sp.level)
            self.data.amount = utils.nat_to_mutez(amount)
            self.data.receiver = sp.Some(receiver)
            self.data.state = sp.cast(sp.variant.REQ(), states)

        @sp.entrypoint
        def finalize(self):
            assert self.data.state == sp.cast(sp.variant.REQ(), states)
            assert sp.level >= self.data.request_time.unwrap_some() + self.data.wait_time
            assert sp.sender == self.data.owner
            self.data.state = sp.cast(sp.variant.IDLE(), states)
            sp.send(self.data.receiver.unwrap_some(), self.data.amount)

        @sp.entrypoint
        def cancel(self):
            assert self.data.state == sp.cast(sp.variant.REQ(), states)
            assert sp.sender == self.data.recovery
            self.data.state = sp.cast(sp.variant.IDLE(), states)

def _compile_targets():
    owner = sp.address("tz1SL2xBdmLSD2W3Hs84SfH912xDpYtAjsaa")
    recovery = sp.address( "tz1aLPm3WynyHRXFvjjdHZDKEjHZVvQMGxqU")
    wait_time = sp.nat(30)
    
    """Entry point for in-process compilation by the toolchain."""
    return [
        (main.VaultRosetta, (owner, recovery, wait_time)),
    ]

