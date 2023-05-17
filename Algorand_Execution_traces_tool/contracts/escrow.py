import pyteal as pt
from pyteal import Seq, Assert, Txn, Global, TxnField, TxnType, InnerTxnBuilder, Int
import beaker

pt.pragma(compiler_version="^0.23.0")

class States:
    WAIT_DEPOSIT = Int(0)
    WAIT_RECIPIENT = Int(1)
    CLOSED = Int(2)

class EscrowState:
    buyer = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
        static=True,
    )
    seller = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
        static=True,
    )
    amount = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        static=True,
    )
    state = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        default=Int(0),
    )

app = beaker.Application("Escrow", state=EscrowState())

@app.create
def create(
    amount_: pt.abi.Uint64,
    buyer_: pt.abi.Address,
    seller_: pt.abi.Address
):
    return Seq(
        Assert(seller_.get() != Global.zero_address(), comment="Seller non-zero"),
        Assert(buyer_.get() != Global.zero_address(), comment="Buyer non-zero"),
        Assert(Txn.sender() == seller_.get(), comment="Caller must be the seller"),
        
        app.state.amount.set(amount_.get()),
        app.state.buyer.set(buyer_.get()),
        app.state.seller.set(seller_.get()),
        app.state.state.set(States.WAIT_DEPOSIT),
    )

@app.external(authorize=beaker.Authorize.only(app.state.buyer))
def deposit(
    deposit: pt.abi.PaymentTransaction,
):
    return Seq(
        Assert(deposit.get().receiver() == Global.current_application_address(), comment="Sending to contract"),
        Assert(deposit.get().amount() == app.state.amount, comment="Sending right amount"),
        Assert(app.state.state == States.WAIT_DEPOSIT, comment="Contract in deposit state"),
        app.state.state.set(States.WAIT_RECIPIENT),
    )

@app.external(authorize=beaker.Authorize.only(app.state.buyer))
def pay(
    _: pt.abi.Account = app.state.seller, # type: ignore[assignment]
):
    return Seq(
        Assert(app.state.state == States.WAIT_RECIPIENT, comment="Contract in recipient state"),
        app.state.state.set(States.CLOSED),
        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.amount: Int(0),
            TxnField.close_remainder_to: app.state.seller,
            TxnField.fee: Int(0),
        }),
    )

@app.external(authorize=beaker.Authorize.only(app.state.seller))
def refund(
    _: pt.abi.Account = app.state.buyer, # type: ignore[assignment]
):
    return Seq(
        Assert(app.state.state == States.WAIT_RECIPIENT, comment="Contract in recipient state"),
        app.state.state.set(States.CLOSED),
        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.amount: Int(0),
            TxnField.close_remainder_to: app.state.buyer,
            TxnField.fee: Int(0),
        }),
    )

if __name__ == "__main__":
    app.build().export("escrow_src")
