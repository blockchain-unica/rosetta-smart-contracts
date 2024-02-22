import smartpy as sp


@sp.module
def main():
    class Auction(sp.Contract):
        def __init__(self, startingBid, time, admin):
            self.data.admin = admin
            self.data.bidders = {}
            self.data.top = sp.record(address=None, amount=sp.mutez(0))
            self.data.startBid = startingBid
            self.data.duration = time
            self.data.isStart = False

        @sp.entrypoint
        def start(self):
            # check if the caller is the admin
            assert sp.sender == self.data.admin, "You are not the admin"

            # start the auction
            self.data.isStart = True

        @sp.entrypoint
        def bid(self):
            # check if the Auction is started
            assert self.data.isStart == True, "The auction is not started yet"

            # check if the bid is grater then the current one
            assert sp.amount > self.data.top.amount, "The bid has to be greater"

            # check if someone already bidded and sender alredy bidded
            if self.data.top.address.is_some():
                # save the loosing bidder in map
                self.data.bidders = sp.update_map(self.data.top.address, sp.Some(sp.Some(self.data.top.amount)),
                                                  self.data.bidders)
                # check for sender
                if self.data.bidders.contains(sp.Some(sp.sender)):
                    # refund
                    sp.send(sp.sender,
                            self.data.bidders.get(sp.Some(sp.sender), default=sp.Some(sp.mutez(0))).unwrap_some())
                    # delete from map
                    del self.data.bidders[sp.Some(sp.sender)]

            # update top bidder
            self.data.top.address = sp.Some(sp.sender)
            self.data.top.amount = sp.amount

        @sp.entrypoint
        def withdraw(self):
            # check if the caller is a bidder
            assert self.data.bidders.contains(sp.Some(sp.sender)), "You are not a bidder"

            # refund
            sp.send(sp.sender, self.data.bidders.get(sp.Some(sp.sender), default=sp.Some(sp.mutez(0))).unwrap_some())

        @sp.entrypoint
        def end(self, time):
            # check if the caller is the admin
            assert sp.sender == self.data.admin, "You are not the admin"

            # check if deadline is reached
            assert time >= self.data.duration, "Deadline is not reached"

            # withdraw all the assets
            sp.send(self.data.admin, sp.balance)


@sp.add_test()
def auctionTest():
    # set scenario
    sc = sp.test_scenario("auctionTest", main)
    # create admin
    admin = sp.test_account("admin")
    # create time
    time = sp.timestamp_from_utc_now()  # calculate execution time
    # new object Auction
    auction = main.Auction(sp.mutez(5), time, admin.address)
    # start scenario
    sc += auction