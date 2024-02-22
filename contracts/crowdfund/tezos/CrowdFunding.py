import smartpy as sp


@sp.module
def main():
    class CrowdFunding(sp.Contract):
        def __init__(self, _admin, _recipient, _deadline, goal):
            self.data.admin = _admin
            self.data.recipient = _recipient
            self.data.startDate = sp.now
            self.data.deadline = _deadline
            self.data.contributors = {None: None}
            self.data.goal = sp.mutez(goal)

        @sp.entrypoint
        def withdraw(self):
            assert sp.sender == self.data.recipient, "You are not the Admin"
            assert sp.now >= self.data.deadline, "The time is not over"
            assert sp.balance >= self.data.goal, "Crowdfund failed"
            # send all money to Admin
            sp.send(self.data.recipient, sp.balance)

        @sp.entrypoint
        def donate(self):
            self.data.contributors = sp.update_map(sp.Some(sp.sender), sp.Some(sp.Some(sp.amount)),
                                                   self.data.contributors)

        @sp.entrypoint
        def reclaim(self):
            # check if sender is a contributor
            assert self.data.contributors.contains(sp.Some(sp.sender)), "You are not a contributor"
            # assert time >= sp.add_seconds(self.data.startDate, self.data.deadline*60 ) ,"The time is not over"
            assert sp.balance >= self.data.goal, "Crowdfund failed"

            # refund
            sp.send(sp.sender, self.data.contributors[sp.Some(sp.sender)].unwrap_some())


@sp.add_test()
def testCrowd():
    # set scenario
    sc = sp.test_scenario("Crowdfunding", main)
    # create admin
    admin = sp.test_account("admin")
    # create recipient
    recipient = sp.test_account("recipient")
    # create object crowdfunding
    crowdFunding = main.CrowdFunding(admin.address, recipient.address, sp.now, 10000)
    # start scenario
    sc += crowdFunding