import smartpy as sp

@sp.module
def main():
    class HashTimedLockedContract(sp.Contract):
        def __init__(self):
            self.data.deadline = None
            self.data.committer = None
            self.data.receiver = None
            self.data.hash = None
    
        @sp.entry_point
        def commit(self, deadline, receiver, hash):
            #save into data
            self.data.deadline = sp.Some(sp.level + deadline)
            self.data.receiver = sp.Some(receiver)
            self.data.hash = sp.Some(hash)
            
            self.data.committer = sp.Some(sp.sender)
    
        @sp.entry_point
        def reveal(self, word):
            #hash
            bytes = sp.pack(word) 
            hash = sp.keccak(bytes) #created
            assert self.data.hash == sp.Some(hash), "Wrong word" #checked

            #transfer collateral to commiter
            sp.send(self.data.committer.unwrap_some(), sp.balance)
    
    
        @sp.entry_point
        def timeout(self):
            #check if deadline is reached and if sender is the commiter
            assert self.data.deadline <= sp.Some(sp.level), "Deadline not reached"
            assert self.data.receiver == sp.Some(sp.sender), "You're not the receiver"
    
            #transfer collateral to receiver
            sp.send(self.data.receiver.unwrap_some(), sp.balance)

        
    

@sp.add_test(name = "HTLC")
def testHTLC():
    #set scenario
    sc = sp.test_scenario(main)
    #create object HashTimedLockedContract
    htlc = main.HashTimedLockedContract()
    #start scenario
    sc += htlc

    #create users
    sofia = sp.test_account("sofia")
    pippo = sp.test_account("pippo")

    #create hash
    secret = "love"
    bytes = sp.pack(secret)
    hash = sp.keccak(bytes)
    #first commit
    htlc.commit(sp.record(deadline = sp.nat(10) , receiver = sofia.address, hash = hash)).run(sender = pippo, amount = sp.mutez(1000))
    #reveal after 50 rounds
    htlc.reveal("love").run(sender = pippo)
    #timeout after 100 rounds
    htlc.timeout().run(sender = sofia, level = 1000)




