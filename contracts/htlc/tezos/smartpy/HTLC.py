import smartpy as sp
import requests

@sp.module
def main():
    class HTLCRosetta(sp.Contract):
        def __init__(self, owner: sp.address, v: sp.address, h: sp.bytes, delay: sp.nat):
            self.data.owner = owner
            self.data.verifier = v
            self.data.hash = h
            self.data.reveal_timeout = sp.level + delay

        @sp.entrypoint(with_storage="read-only")
        def reveal(self, s: sp.string):
            assert sp.balance - sp.amount >= sp.mutez(1), "Balance is empty" #check solidity constructor
            assert sp.sender == self.data.owner, "Sender is not the owner"
            assert sp.keccak(sp.pack(s)) == self.data.hash, "Hash incorrect"
            sp.send(self.data.owner, sp.balance)
            sp.emit(sp.record(owner=self.data.owner), tag="Revealed")

        @sp.entrypoint(with_storage="read-only")
        def timeout(self):
            assert sp.level >= self.data.reveal_timeout, "Timeout not reached"
            sp.send(self.data.verifier, sp.balance)
            sp.emit(sp.record(verifier=self.data.verifier), tag="TimedOut")

def _compile_targets():
    owner = sp.address("tz1SL2xBdmLSD2W3Hs84SfH912xDpYtAjsaa")
    verifier = sp.address("tz1aLPm3WynyHRXFvjjdHZDKEjHZVvQMGxqU")
    secret = "Test"
    secret_hash = sp.keccak(sp.pack(secret))
    delay = sp.nat(30)
    
    rpc = "https://rpc.tzkt.io/ghostnet"
    head = requests.get(f"{rpc}/chains/main/blocks/head/header").json()
    current_level = int(head["level"])
    
    """Entry point for in-process compilation by the toolchain."""
    return [
        (main.HTLCRosetta, (owner, verifier, secret_hash, delay + current_level)),
    ]

