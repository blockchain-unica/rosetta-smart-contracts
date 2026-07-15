import smartpy as sp
import requests

@sp.module
def main():
    import smartpy.stdlib.utils as utils

    class VestingRosetta(sp.Contract):
        def __init__(self, beneficiaryAddress: sp.address, start_timestamp: sp.nat, duration_seconds: sp.nat):
            assert beneficiaryAddress != sp.address("0"), "Beneficiary is zero address"
            self.data.released = sp.nat(0)
            self.data.beneficiary = beneficiaryAddress
            self.data.start = start_timestamp
            self.data.duration = duration_seconds

        @sp.entrypoint
        def release(self):
            amount = sp.nat(0)
            if (sp.level < self.data.start):
                amount = sp.nat(0)
            else:
                if (sp.level > self.data.start + self.data.duration):
                    amount = utils.mutez_to_nat(sp.balance) + self.data.released
                else:
                    amount = ((utils.mutez_to_nat(sp.balance) + self.data.released) * sp.as_nat(sp.level - self.data.start)) / self.data.duration
            amount = sp.as_nat(amount - self.data.released)
            self.data.released = self.data.released + amount
            sp.send(self.data.beneficiary, utils.nat_to_mutez(amount))
            sp.emit(sp.record(beneficiary=self.data.beneficiary, amount=amount), tag="Released")

def _compile_targets():
    beneficiary = sp.address("tz1SL2xBdmLSD2W3Hs84SfH912xDpYtAjsaa")
    start_level = sp.nat(0)
    duration = sp.nat(30)
    
    rpc = "https://rpc.tzkt.io/ghostnet"
    head = requests.get(f"{rpc}/chains/main/blocks/head/header").json()
    current_level = int(head["level"])
    
    """Entry point for in-process compilation by the toolchain."""
    return [
        (main.VestingRosetta, (beneficiary, start_level + current_level, duration)),
    ]

