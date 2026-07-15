import smartpy as sp


@sp.module
def main():
    import smartpy.stdlib.utils as utils

    class PaymentSplitterRosetta(sp.Contract):
        def __init__(self, shares: sp.list[sp.nat], payees: sp.list[sp.address]):
            payees_len = sp.len(payees)
            assert payees_len == sp.len(shares), "PaymentSplitter: payees and shares length mismatch"
            assert payees_len > 0, "PaymentSplitter: no payees"

            self.data.total_shares = sp.nat(0)
            self.data.total_released = sp.mutez(0)
            self.data.shares = sp.cast(sp.big_map(), sp.big_map[sp.address, sp.nat])
            self.data.released = sp.cast(sp.big_map(), sp.big_map[sp.address, sp.mutez])
            self.data.payees = payees

            counter_p = 0
            counter_s= 0
            done = False
            for payee in payees:
                done = False
                counter_s = 0
                for share in shares:
                    if not done:
                        for i in range(payees_len):
                            if i == counter_s and i == counter_p:
                                assert payee != sp.address("0"), "PaymentSplitter: account is the zero address"
                                assert share > 0, "PaymentSplitter: shares are 0"
                                assert not self.data.shares.contains(payee), "PaymentSplitter: account already has shares"

                                self.data.shares[payee] = share
                                self.data.total_shares += share

                                done = True

                        counter_s += 1
                counter_p += 1

        @sp.entrypoint(with_storage="no-access")
        def receive(self):
            assert sp.amount > sp.mutez(0)
            sp.emit(sp.record(sender=sp.sender, amount=sp.amount), tag="Received")

        @sp.offchain_view()
        def total_shares(self):
            return self.data.total_shares

        @sp.offchain_view()
        def total_released(self):
            return self.data.total_released

        @sp.offchain_view()
        def shares(self, account: sp.address):
            return self.data.shares[account]

        @sp.offchain_view()
        def released(self, account: sp.address):
            return self.data.released[account]

        @sp.offchain_view()
        def payee(self, index: sp.nat):
            response = sp.cast(None, sp.option[sp.address])
            counter = 0
            for payee in self.data.payees:
                if counter == index:
                    response = sp.Some(payee)
                counter += 1
            return response.unwrap_some()

        @sp.offchain_view()
        def releasable(self, account: sp.address):
            total_received = utils.mutez_to_nat(sp.balance + self.data.total_released)
            already_released = utils.mutez_to_nat(
                self.data.released.get(account, default=sp.mutez(0))
            )
            due = sp.fst(sp.ediv(total_received * self.data.shares[account], self.data.total_shares).unwrap_some())
            return sp.as_nat(due - already_released)

        @sp.entrypoint
        def release(self, account: sp.address):
            assert self.data.shares.contains(account) and self.data.shares[account] > sp.nat(0), "PaymentSplitter: account has no shares"
            total_received = utils.mutez_to_nat(sp.balance + self.data.total_released)
            already_released = utils.mutez_to_nat(
                self.data.released.get(account, default=sp.mutez(0))
            )
            due = sp.fst(sp.ediv(total_received * self.data.shares[account], self.data.total_shares).unwrap_some())
            payment = sp.as_nat(due - already_released)
            assert payment != 0, "PaymentSplitter: account is not due payment"

            self.data.released[account] = self.data.released.get(account, default=sp.mutez(0)) + utils.nat_to_mutez(payment)
            self.data.total_released += utils.nat_to_mutez(payment)

            sp.send(account, utils.nat_to_mutez(payment))
            sp.emit(sp.record(account=account, amount=utils.nat_to_mutez(payment)), tag="Released")

def _compile_targets():
    admin = sp.address("tz1SL2xBdmLSD2W3Hs84SfH912xDpYtAjsaa")
    mario = sp.address("tz1aLPm3WynyHRXFvjjdHZDKEjHZVvQMGxqU")
    payees = [
        admin,
        mario
    ]
    shares = [
        sp.nat(70),
        sp.nat(30)
    ]
    
    """Entry point for in-process compilation by the toolchain."""
    return [
        (main.PaymentSplitterRosetta, (shares, payees)),
    ]

