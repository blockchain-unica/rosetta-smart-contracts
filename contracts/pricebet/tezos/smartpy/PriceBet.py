import smartpy as sp
import requests

@sp.module
def main():
    class PriceBetRosetta(sp.Contract):
        def __init__(self, owner: sp.address, initial_pot: sp.mutez ,oracle: sp.address, deadline: sp.nat, exchange_rate: sp.nat):
            self.data.initial_pot = initial_pot
            self.data.deadline_block = sp.level + deadline
            self.data.exchange_rate = exchange_rate
            self.data.oracle = oracle
            self.data.owner = owner
            self.data.player = sp.cast(None, sp.option[sp.address])

        @sp.entrypoint
        def join(self):
            assert sp.amount == self.data.initial_pot, "Amount invalid"
            assert self.data.player.is_none(), "Player already joined"
            self.data.player = sp.Some(sp.sender)
            sp.emit(sp.record(player=sp.sender), tag="PlayerJoined")

        @sp.entrypoint(with_storage="read-only")
        def win(self):
            assert sp.level < self.data.deadline_block, "deadline expired"
            assert sp.sender == self.data.player.unwrap_some(), "invalid sender"
            price = sp.view("get_exchange_rate", self.data.oracle, (), sp.nat).unwrap_some()
            assert price >= self.data.exchange_rate, "you lost the bet"
            sp.send(sp.sender, sp.balance)

        @sp.entrypoint(with_storage="read-only")
        def timeout(self):
            assert sp.level >= self.data.deadline_block, "deadline not expired"
            sp.send(self.data.owner, sp.balance)
            sp.emit(sp.record(owner=self.data.owner), tag="Timeout")

    class Oracle(sp.Contract):
        def __init__(self):
            self.data.exchange_rate = sp.nat(10)

        @sp.onchain_view
        def get_exchange_rate(self):
            return self.data.exchange_rate

_ORACLE_PLACEHOLDER = "KT1burnburnburnburnburnburnburjAYjjX"

def _compile_targets():
    """Entry point for in-process compilation by the toolchain."""
    owner = sp.address("tz1SL2xBdmLSD2W3Hs84SfH912xDpYtAjsaa")
    initial_pot = sp.mutez(1000)
    deadline = sp.nat(30)
    exchange_rate = sp.nat(10)

    rpc = "https://rpc.tzkt.io/ghostnet"
    head = requests.get(f"{rpc}/chains/main/blocks/head/header").json()
    current_level = int(head["level"])
    
    return [
        (main.Oracle, (), _ORACLE_PLACEHOLDER, "Oracle"),
        (main.PriceBetRosetta, (
            owner,
            initial_pot,
            sp.address(_ORACLE_PLACEHOLDER),
            deadline + current_level,
            exchange_rate,
        ), None, "PriceBetRosetta"),
    ]

