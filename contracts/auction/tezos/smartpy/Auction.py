import smartpy as sp

@sp.module
def main():
    states: type = sp.variant(
        WAIT_START=sp.unit,
        WAIT_CLOSING=sp.unit,
        CLOSED=sp.unit)

    class AuctionRosetta(sp.Contract):
        def __init__(self, seller: sp.address, object: sp.string, starting_bid: sp.mutez):
            self.data.state = sp.cast(sp.variant.WAIT_START(), states)
            self.data.object = object
            self.data.seller = seller
            self.data.end_time = sp.cast(None, sp.option[sp.nat])
            self.data.highest_bidder = sp.cast(None, sp.option[sp.address])
            self.data.highest_bid = starting_bid
            self.data.bids = sp.cast(sp.big_map(), sp.big_map[sp.address, sp.mutez])

        @sp.entrypoint
        def start(self, duration):
            assert self.data.state == sp.cast(sp.variant.WAIT_START(), states), "Auction already started"
            assert sp.sender == self.data.seller, "Only the seller"
            self.data.state = sp.cast(sp.variant.WAIT_CLOSING(), states)
            self.data.end_time = sp.Some(sp.level + duration)
            sp.emit(sp.record(seller=self.data.seller, end_time=self.data.end_time.unwrap_some()), tag="AuctionStarted")

        @sp.entrypoint
        def bid(self):
            assert self.data.state == sp.cast(sp.variant.WAIT_CLOSING(), states), "Auction not started or already closed"
            assert sp.level < self.data.end_time.unwrap_some(), "Bidding time expired"

            assert sp.amount > self.data.highest_bid, "value must be greater than highest"

            if (self.data.highest_bidder.is_some()):
                self.data.bids[self.data.highest_bidder.unwrap_some()] = self.data.highest_bid

            if (sp.sender in self.data.bids and self.data.bids[sp.sender] != sp.mutez(0)):
                sp.transfer((), sp.mutez(0), sp.self_entrypoint("withdraw"))

            self.data.highest_bidder = sp.Some(sp.sender)
            self.data.highest_bid = sp.amount
            sp.emit(sp.record(bidder=sp.sender, amount=sp.amount), tag="NewBid")

        @sp.entrypoint
        def withdraw(self):
            assert self.data.state == sp.cast(sp.variant.WAIT_CLOSING(), states), "Auction not started"
            if sp.sender in self.data.bids:
                bal = self.data.bids[sp.sender]
                self.data.bids[sp.sender] = sp.mutez(0)
                sp.send(sp.sender, bal)
                sp.emit(sp.record(bidder=sp.sender, amount=bal), tag="BidWithdrawn")

        @sp.entrypoint
        def end(self):
            assert sp.sender == self.data.seller, "Only the seller"
            assert self.data.state == sp.cast(sp.variant.WAIT_CLOSING(), states), "Auction not started"
            assert sp.level >= self.data.end_time.unwrap_some(), "Auction not ended"
            self.data.state = sp.cast(sp.variant.CLOSED(), states)
            sp.send(self.data.seller, self.data.highest_bid)
            sp.emit(sp.record(winner=self.data.highest_bidder, final_bid=self.data.highest_bid), tag="AuctionEnded")

def _compile_targets():
    seller = sp.address("tz1SL2xBdmLSD2W3Hs84SfH912xDpYtAjsaa")
    
    """Entry point for in-process compilation by the toolchain."""
    return [
        (main.AuctionRosetta, (seller, "object", sp.mutez(5))),
    ]

