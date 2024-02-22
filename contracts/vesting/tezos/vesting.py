import smartpy as sp


@sp.module
def main():
    class Vesting(sp.Contract):
        # Define the contract's data
        def __init__(self, _beneficiary, _start, _duration, _amount):
            self.data.amount = _amount
            self.data.beneficiary = _beneficiary
            self.data.start = _start
            self.data.duration = _duration
            self.data.released = sp.mutez(0)

        @sp.entrypoint
        def release(self):
            assert sp.sender == self.data.beneficiary, "you are not the beneficiary"

            assert sp.now >= self.data.start, "Release not started"

            if sp.now > sp.add_days(self.data.start, self.data.duration):
                sp.send(sp.sender, self.data.amount - self.data.released)
            else:
                vesting = sp.ediv(sp.mul(self.data.amount, sp.as_nat(sp.now - self.data.start)),
                                  sp.as_nat(self.data.duration))
                released = sp.fst(vesting.unwrap_some()) - self.data.released
                sp.send(sp.sender, released)
                self.data.released += released


@sp.add_test()
def test():
    # set scenario
    sc = sp.test_scenario("Vesting", main)
    # create users
    beneficiary = sp.test_account("Beneficiary")
    # create object
    c1 = main.Vesting(beneficiary.address, sp.now, 5, sp.mutez(10))
    # start scenario
    sc += c1


