import pyteal as pt
from pyteal import Seq, Assert, Txn, Global, TxnField, TxnType, InnerTxnBuilder, Int
import beaker

pt.pragma(compiler_version="^0.23.0")

class States:
    WAIT_START = Int(0)
    WAIT_CLOSING = Int(1)
    CLOSED = Int(2)

class AuctionState:
    object = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
        static=True,
    )
    seller = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
        static=True,
    )
    end_time = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        static=True,
    )
    highest_bid = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
    )
    highest_bidder = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
    )
    state = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
    )
    bid = beaker.LocalStateValue(
        stack_type=pt.TealType.uint64,
    )

app = beaker.Application("Auction", state=AuctionState())

@app.create
def create(
    object_: pt.abi.String,
    starting_bid_: pt.abi.Uint64,
):
    return Seq(
        app.state.object.set(object_.get()),
        app.state.seller.set(Txn.sender()),
        app.state.highest_bid.set(starting_bid_.get()),
        
        app.state.state.set(States.WAIT_START),
    )

@app.external
def start(
    duration_: pt.abi.Uint64,
):
    return Seq(
        Assert(app.state.state == States.WAIT_START,
               comment="Auction already started"),
        Assert(Txn.sender() == app.state.seller,
               comment="Only the seller"),

        app.state.end_time.set(Global.round() + duration_.get()),
        app.state.state.set(States.WAIT_CLOSING),
    )

@app.external
def bid(
    deposit: pt.abi.PaymentTransaction,
):
    return Seq(
        Assert(app.state.state == States.WAIT_CLOSING,                              
               comment="Auction not started"),
        Assert(Global.round() < app.state.end_time,                                 
               comment="Time ended"),
        Assert(deposit.get().amount() > app.state.bid[app.state.highest_bidder],
               comment="value < highest"),

        send_algos(app.state.seller, app.state.bid[Txn.sender()]),

        app.state.bid[Txn.sender()].set(deposit.get().amount()),
        app.state.highest_bidder.set(Txn.sender()),
        app.state.highest_bid.set(deposit.get().amount()),
    )

@app.external
def withdraw():
    return Seq(
        Assert(Txn.sender() != app.state.highest_bidder,
               comment="Not highest bidder"),
        Assert(app.state.state != States.WAIT_START,
               comment="Auction not started"),

        send_algos(Txn.sender(), app.state.bid[Txn.sender()]),

        app.state.bid[Txn.sender()].set(Int(0))
    )

@app.external
def end():
    return Seq(
        Assert(Txn.sender() == app.state.seller,
               comment="Only the seller"),
        Assert(app.state.state == States.WAIT_CLOSING,
               comment="Auction not started"),
        Assert(Global.round() >= app.state.end_time,
               comment="Auction not ended"),

        app.state.state.set(States.CLOSED),

        send_algos(app.state.seller, app.state.highest_bid)
    )

@pt.Subroutine(pt.TealType.none)
def send_algos(receiver: pt.Expr, amount: pt.Expr):
    return InnerTxnBuilder.Execute({
        TxnField.type_enum: TxnType.Payment,
        TxnField.receiver: receiver,
        TxnField.amount: amount,
        TxnField.fee: Int(0),
    })

if __name__ == "__main__":
    app.build().export("auction_src")
