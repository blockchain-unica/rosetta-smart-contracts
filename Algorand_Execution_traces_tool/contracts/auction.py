import pyteal as pt
from pyteal import Seq, Assert, Txn, Global, TxnField, TxnType, InnerTxnBuilder, Int
import beaker

pt.pragma(compiler_version="^0.23.0")

class States:
    WAIT_START = Int(0)
    WAIT_CLOSING = Int(1)
    CLOSED = Int(2)

class AuctionState:
    obj = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
        static=True,
        descr="Descriptor of the auctioned object",
    )
    seller = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
        static=True,
        descr="Seller of the object",
    )
    end_time = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        static=True,
        descr="The last round of the bidding window",
    )
    highest_bid = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        descr="The current winning bid",
    )
    highest_bidder = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
        descr="The current winning bidder",
    )
    state = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        descr="The current logical state: WAIT_START/WAIT_CLOSING/CLOSED",
    )
    bid = beaker.LocalStateValue(
        stack_type=pt.TealType.uint64,
        descr="Bid of an actor",
    )

app = beaker.Application("Auction", state=AuctionState())

@app.create
def create(
    obj_: pt.abi.String,
    starting_bid_: pt.abi.Uint64,
):
    return Seq(
        # If not present we would have multiple problems:
        # - the first bidder would not be able to bid, as the MBR of the contract would not be satisfied
        # - when reclaiming the bidded funds, bidder could be stuck not being able to reclaim their bid 
        #   amount, as that would make the contract balance go below the MBR
        Assert(starting_bid_.get() >= Int(100000),
               comment="Must provide at least MBR"),

        # Initialize contract state
        app.state.obj.set(obj_.get()),
        app.state.seller.set(Txn.sender()),
        app.state.highest_bid.set(starting_bid_.get()),

        # Transition into WAIT_START
        app.state.state.set(States.WAIT_START),
    )

@app.external
def start(
    duration_: pt.abi.Uint64,
):
    return Seq(
        Assert(app.state.state == States.WAIT_START,
               comment="Action must be waiting to be started"),
        Assert(Txn.sender() == app.state.seller,
               comment="Callable only by the seller"),

        # Set auction end time
        app.state.end_time.set(Global.round() + duration_.get()),

        # Transition into WAIT_CLOSING
        app.state.state.set(States.WAIT_CLOSING),
    )

@app.external(method_config=pt.MethodConfig(
    opt_in=pt.CallConfig.CALL,
    no_op=pt.CallConfig.CALL,
))
def bid(
    deposit: pt.abi.PaymentTransaction,
):
    return Seq(
        Assert(app.state.state == States.WAIT_CLOSING,
               comment="Auction must be running"),
        Assert(Global.round() < app.state.end_time,
               comment="Bids can only happen before the end of the bid period"),
        Assert(deposit.get().amount() > app.state.highest_bid,
               comment="Bid must be higher than previous bid"),

        # Send back to the bidder their previous bid (0 at first bid)
        pay_or_close(Txn.sender(), app.state.bid[Txn.sender()]),

        # Update bid and highest bid info
        app.state.bid[Txn.sender()].set(deposit.get().amount()),
        app.state.highest_bidder.set(Txn.sender()),
        app.state.highest_bid.set(deposit.get().amount()),
    )

@app.external
def withdraw():
    return Seq(
        Assert(app.state.state != States.WAIT_START,
               comment="Auction must be running"),
        Assert(Txn.sender() != app.state.highest_bidder,
               comment="The highest bidder cannot withdraw their bid"),

        # Send bid back to caller
        pay_or_close(Txn.sender(), app.state.bid[Txn.sender()]),

        # Reset bid amount
        app.state.bid[Txn.sender()].set(Int(0)),
    )

@app.external
def end():
    return Seq(
        Assert(Txn.sender() == app.state.seller,
               comment="Only the seller can close the contract"),
        Assert(app.state.state == States.WAIT_CLOSING,
               comment="Auction must be running"),
        Assert(Global.round() >= app.state.end_time,
               comment="Bid period must be over"),

        # Pay seller the highest bid
        pay_or_close(app.state.seller, app.state.highest_bid),

        # Transition to end state
        app.state.state.set(States.CLOSED),
    )

@pt.Subroutine(pt.TealType.none)
def pay_or_close(receiver, amt):
    return (
        # Only do something if an amount > 0 is being sent
        pt.If(amt > Int(0)).Then(
            # If it is the full balance (minus some < MBR amount), send all
            # Note that any amount < MBR must have been sent outside of the contracts logic, as the starting
            # bid is at least the MBR
            pt.If(pt.Balance(Global.current_application_address()) - amt < Int(100000)).Then(
                InnerTxnBuilder.Execute({
                    TxnField.type_enum: TxnType.Payment,
                    TxnField.close_remainder_to: receiver,
                    TxnField.fee: Int(0),
                })
            # Otherwise, just send the specified amount
            ).Else(
                InnerTxnBuilder.Execute({
                    TxnField.type_enum: TxnType.Payment,
                    TxnField.receiver: receiver,
                    TxnField.amount: amt,
                    TxnField.fee: Int(0),
                })
            )
        )
    )


if __name__ == "__main__":
    app.build().export("artifacts")
