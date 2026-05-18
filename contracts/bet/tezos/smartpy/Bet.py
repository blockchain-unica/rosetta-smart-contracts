import smartpy as sp
import requests 

@sp.module
def main():
    class BetRosetta(sp.Contract):
        def __init__(self, player1, oracle, timeout, wager):
            self.data.player1 = sp.cast(player1, sp.address)
            self.data.player2 = sp.cast(None, sp.option[sp.address])
            self.data.deadline = sp.level + timeout
            self.data.oracle = sp.cast(oracle, sp.address)
            self.data.wager = sp.cast(wager, sp.mutez)

        @sp.entrypoint
        def join(self):
            assert sp.amount == self.data.wager, "Invalid Value"
            assert self.data.player2.is_none(), "Player2 already joined"
            assert sp.level < self.data.deadline, "Timeout"
        
            self.data.player2 = sp.Some(sp.sender)

        @sp.entrypoint
        def win(self, winner: sp.nat):
            assert sp.sender == self.data.oracle, "Only the oracle"
            assert self.data.player2.is_some(), "Player2 has not joined"
            assert winner <= 1, "Invalid winner"

            addressWinner = sp.cast(None, sp.option[sp.address])

            if (winner == 0):
                addressWinner = sp.Some(self.data.player1)
            else:
                addressWinner = self.data.player2
                
            sp.send(addressWinner.unwrap_some(), sp.balance)

        @sp.entrypoint
        def timeout(self):
            assert sp.level >= self.data.deadline, "The timeout has not passed"
            sp.send(self.data.player1, self.data.wager)

            if (self.data.player2.is_some()):
                sp.send(self.data.player2.unwrap_some(), self.data.wager)

def _compile_targets():
    player1 = sp.address("tz1SL2xBdmLSD2W3Hs84SfH912xDpYtAjsaa")
    oracle = sp.address("tz1ZNfCeehri4t8oFNB187DDEAqtdu3Ayc1z")
    timeout = sp.nat(50)
    wager = sp.mutez(500)
    
    rpc = "https://rpc.tzkt.io/ghostnet"
    head = requests.get(f"{rpc}/chains/main/blocks/head/header").json()
    current_level = int(head["level"])
    
    """Entry point for in-process compilation by the toolchain."""
    return [
        (main.BetRosetta, (player1, oracle, timeout + current_level, wager)),
    ]

