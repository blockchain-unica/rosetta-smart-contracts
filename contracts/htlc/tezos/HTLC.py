import smartpy as sp


@sp.module
def main():
    class HashTimedLockedContract(sp.Contract):
        def __init__(self):
            self.data.deadline = None
            self.data.committer = None
            self.data.receiver = None
            self.data.hash = None

        @sp.entrypoint
        def commit(self, deadline, receiver, hash):
            # save into data
            self.data.deadline = sp.Some(sp.level + deadline)
            self.data.receiver = sp.Some(receiver)
            self.data.hash = sp.Some(hash)

            self.data.committer = sp.Some(sp.sender)

        @sp.entrypoint
        def reveal(self, word):
            # hash
            bytes = sp.pack(word)
            hash = sp.keccak(bytes)  # created
            assert self.data.hash == sp.Some(hash), "Wrong word"  # checked

            # transfer collateral to commiter
            sp.send(self.data.committer.unwrap_some(), sp.balance)

        @sp.entrypoint
        def timeout(self):
            # check if deadline is reached and if sender is the commiter
            assert self.data.deadline <= sp.Some(sp.level), "Deadline not reached"
            assert self.data.receiver == sp.Some(sp.sender), "You're not the receiver"

            # transfer collateral to receiver
            sp.send(self.data.receiver.unwrap_some(), sp.balance)


@sp.add_test()
def testHTLC():
    # set scenario
    sc = sp.test_scenario("HTLC", main)
    # create object HashTimedLockedContract
    htlc = main.HashTimedLockedContract()
    # start scenario
    sc += htlc