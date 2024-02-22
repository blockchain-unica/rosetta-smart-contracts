import smartpy as sp


@sp.module
def main():
    class Vault(sp.Contract):
        def __init__(self, _recoveryKey, _wait_time):
            self.data.recoveryKey = _recoveryKey
            self.data.wait_time = sp.add_seconds(sp.now, _wait_time)
            self.data.depositDone = False
            self.data.requestDone = False
            self.data.receiver = None

        @sp.entrypoint
        def deposit(self):
            self.data.depositDone = True
            pass

        @sp.entrypoint
        def withdraw(self):
            assert self.data.depositDone == True, "Deposit not done"
            tmp = self.data.wait_time - sp.now
            self.data.wait_time = sp.add_seconds(sp.now, tmp)
            self.data.requestDone = True
            self.data.receiver = sp.Some(sp.sender)

        @sp.entrypoint
        def finalize(self):
            assert self.data.requestDone == True, "Request not done"
            assert self.data.wait_time <= sp.now, "Wait time not over"

            sp.send(self.data.receiver.unwrap_some(), sp.balance)

        @sp.entrypoint
        def cancel(self, _recoverKey):
            assert self.data.requestDone == True, "Request not done"
            assert self.data.wait_time > sp.now, "Wait time over"
            assert self.data.recoveryKey == _recoverKey, "Wrong recovery key"

            self.data.requestDone = False
            self.data.receiver = None


@sp.add_test()
def test():
    # set scenario
    sc = sp.test_scenario("Vault", main)
    # create object
    Vault = main.Vault("ciao", 10)
    # start scenario
    sc += Vault