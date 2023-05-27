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
        descr="Buyer address",
    )
    seller = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
        static=True,
        descr="Seller address",
    )
    amount = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        static=True,
        descr="Amount that must be paid",
    )
    state = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        default=Int(0),
        descr="Contract logical state: WAIT_DEPOSIT/WAIT_RECIPIENT/CLOSED",
    )

app = beaker.Application("Escrow", state=EscrowState())

@app.create
def create(
    amount_: pt.abi.Uint64,
    buyer_: pt.abi.Address,
):
    return Seq(
        Assert(buyer_.get() != Global.zero_address(),
               comment="Buyer must be an account"),
        
        # Initialize static variables
        app.state.amount.set(amount_.get()),
        app.state.buyer.set(buyer_.get()),
        app.state.seller.set(Txn.sender()),

        # Transition into initial state
        app.state.state.set(States.WAIT_DEPOSIT),
    )

@app.external
def deposit(
    deposit: pt.abi.PaymentTransaction,
):
    return Seq(
        Assert(app.state.state == States.WAIT_DEPOSIT, 
               comment="Contract must be in deposit state"),
        Assert(Txn.sender() == app.state.buyer,
               comment="Only the buyer can deposit funds"),
        Assert(deposit.get().receiver() == Global.current_application_address(),
               comment="Funds must be deposited to the contract"),
        Assert(deposit.get().amount() == app.state.amount,
               comment="Right amount must be deposited"),
        
        # Transition into new state
        app.state.state.set(States.WAIT_RECIPIENT),
    )

@app.external
def pay(
    # Make contract able to send funds to seller
    _: pt.abi.Account = app.state.seller, # type: ignore[assignment]
):
    return Seq(
        Assert(app.state.state == States.WAIT_RECIPIENT,
               comment="The funds must already have been deposited"),
        Assert(Txn.sender() == app.state.buyer,
               comment="Only the buyer can finalize the payment"),
        
        # Send all the funds to the seller
        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.amount: Int(0),
            TxnField.close_remainder_to: app.state.seller,
            TxnField.fee: Int(0),
        }),
        
        # Transition contract into final state
        app.state.state.set(States.CLOSED),
    )

@app.external
def refund(
    # Make contract able to send funds to buyer
    _: pt.abi.Account = app.state.buyer, # type: ignore[assignment]
):
    return Seq(
        Assert(app.state.state == States.WAIT_RECIPIENT,
               comment="The funds must already have been deposited"),
        Assert(Txn.sender() == app.state.seller,
               comment="Only the seller can refund the buyer"),

        # Send all the funds to the buyer
        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.amount: Int(0),
            TxnField.close_remainder_to: app.state.buyer,
            TxnField.fee: Int(0),
        }),

        # Transition contract into final state
        app.state.state.set(States.CLOSED),
    )


if __name__ == "__main__":
    app.build().export("artifacts")
