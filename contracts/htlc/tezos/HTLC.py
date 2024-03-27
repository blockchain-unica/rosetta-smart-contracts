import smartpy as sp


@sp.module
def main():
    class HashTimedLockedContract(sp.Contract):
        def __init__(self, commiter, deadline, receiver, hash):
            self.data.committer = commiter
            self.data.deadline = sp.level + deadline
            self.data.receiver = receiver
            self.data.hash = hash

        @sp.entrypoint
        def reveal(self, word):
            sp.cast(word, sp.string)
            # hash
            bytes = sp.pack(word)
            hash = sp.keccak(bytes)  # created
            assert self.data.hash == hash, "Wrong word"  # checked

            # transfer collateral to commiter
            sp.send(self.data.committer, sp.balance)

        
        @sp.entrypoint
        def timeout(self):
            # check if deadline is reached and if sender is the commiter
            assert self.data.deadline <= sp.level, "Deadline not reached"
            assert self.data.receiver == sp.sender, "You're not the receiver"

            # transfer collateral to receiver
            sp.send(self.data.receiver, sp.balance)
        
            


@sp.add_test()
def testHTLC():
    # set scenario
    sc = sp.test_scenario("HTLC", main)
    committer = sp.test_account("committer")
    receiver = sp.test_account("receiver")
    bytes = sp.pack("Hello")
    hash = sp.keccak(bytes)
    # create object HashTimedLockedContract
    htlc = main.HashTimedLockedContract(committer.address, 10, receiver.address, hash)
    htlc.set_initial_balance(sp.mutez(10))
    # start scenario
    sc += htlc