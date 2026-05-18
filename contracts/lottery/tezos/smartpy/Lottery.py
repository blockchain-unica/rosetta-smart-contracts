import smartpy as sp

@sp.module
def main():
    status: type = sp.variant(Join0=sp.unit,
        Join1=sp.unit,
        Commit0=sp.unit,
        Commit1=sp.unit,
	    Reveal0=sp.unit,
	    Reveal1=sp.unit,
	    Win=sp.unit,
        End=sp.unit)
    
    class LotteryRosetta(sp.Contract):
        def __init__(self, owner: sp.address):
            self.data.owner = owner
            self.data.player0 = sp.cast(None, sp.option[sp.address])
            self.data.player1 = sp.cast(None, sp.option[sp.address])
            self.data.winner = sp.cast(None, sp.option[sp.address])
            self.data.hash0 = sp.cast(None, sp.option[sp.bytes])
            self.data.hash1 = sp.cast(None, sp.option[sp.bytes])
            self.data.secret0 = ""
            self.data.secret1 = ""
            self.data.bet_amount = sp.mutez(0)
            self.data.end_join = sp.level + sp.nat(30)
            self.data.end_reveal = sp.level + sp.nat(30)
            self.data.status = sp.cast(sp.variant.Join0(), status)
            
        @sp.entrypoint
        def join0(self, h):
            assert self.data.status == sp.cast(sp.variant.Join0(), status) and sp.amount > sp.mutez(0), "Status not join0 or wrong amount"
            
            self.data.player0 = sp.Some(sp.sender)
            self.data.hash0 = sp.Some(h)
            self.data.status = sp.cast(sp.variant.Join1(), status)
            self.data.bet_amount = sp.amount
        
        @sp.entrypoint
        def join1(self, h):
            assert self.data.status == sp.cast(sp.variant.Join1(), status) and h!=self.data.hash0.unwrap_some() and sp.amount == self.data.bet_amount, "Status not join1 or same hash or wrong amount"
            
            self.data.player1 = sp.Some(sp.sender)
            self.data.hash1 = sp.Some(h)
            self.data.status = sp.cast(sp.variant.Reveal0(), status)
        
        @sp.entrypoint
        def redeem0_nojoin1(self):
            assert self.data.status == sp.cast(sp.variant.Join1(), status) and sp.level > self.data.end_join, "Status not join1 or block level not over end join"
            
            sp.send(self.data.player0.unwrap_some(), sp.balance)
            self.data.status = sp.cast(sp.variant.End(), status)
            
        @sp.entrypoint
        def reveal0(self, s):
            assert self.data.status == sp.cast(sp.variant.Reveal0(), status) and sp.sender == self.data.player0.unwrap_some(), "Status not reveal0 or sender not player0"
            assert self.data.hash0.unwrap_some() == sp.keccak(sp.pack(s))

            self.data.secret0 = s
            self.data.status = sp.cast(sp.variant.Reveal1(), status)
        
        @sp.entrypoint
        def redeem1_noreveal0(self):
            assert self.data.status == sp.cast(sp.variant.Reveal0(), status) and sp.level > self.data.end_reveal, "Status not reveal0 or block level not over deadline"
            
            sp.send(self.data.player1.unwrap_some(), sp.balance)
            self.data.status = sp.cast(sp.variant.End(), status)
        
        @sp.entrypoint 
        def reveal1(self, s):
            assert self.data.status == sp.cast(sp.variant.Reveal1(), status) and sp.sender == self.data.player1.unwrap_some(), "Status not reveal1 or sender not player1"
            assert self.data.hash1.unwrap_some() == sp.keccak(sp.pack(s))
            
            self.data.secret1 = s
            self.data.status = sp.cast(sp.variant.Win(), status)
        
        @sp.entrypoint
        def redeem0_noreveal1(self):
            assert self.data.status == sp.cast(sp.variant.Reveal1(), status) and sp.level > self.data.end_reveal, "Status not reveal1 or block level not over deadline"
            
            sp.send(self.data.player0.unwrap_some(), sp.balance)
            self.data.status = sp.cast(sp.variant.End(), status)
        
        @sp.entrypoint
        def win(self):
            assert self.data.status == sp.cast(sp.variant.Win(), status), "not status Win"
            
            l0 = sp.cast(len(self.data.secret0), sp.nat)
            l1 = sp.cast(len(self.data.secret1), sp.nat)
            
            if (sp.mod(l0+l1, 2) == 0):
                self.data.winner = self.data.player0
            else:
                self.data.winner = self.data.player1
                
            sp.send(self.data.winner.unwrap_some(), sp.balance)
            
            self.data.status = sp.cast(sp.variant.End(), status)

def _compile_targets():
    owner = sp.address("tz1SL2xBdmLSD2W3Hs84SfH912xDpYtAjsaa")
    
    """Entry point for in-process compilation by the toolchain."""
    return [
        (main.LotteryRosetta, (owner,)),
    ]

