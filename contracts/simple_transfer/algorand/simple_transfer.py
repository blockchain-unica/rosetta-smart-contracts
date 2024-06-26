import pyteal as pt
from pyteal import Seq, Assert, Txn, Global, TxnField, TxnType, InnerTxnBuilder, Int
import beaker

pt.pragma(compiler_version="^0.23.0")

class SimpleTransferState:
    recipient = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
        static=True,
        descr="Receiver of the transfer",
    )

    owner = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
        static=True,
        descr="Owner of the contract",
    )

app = beaker.Application("SimpleTransfer", state=SimpleTransferState())

@app.create
def create(
    recipient_: pt.abi.Address,
):
    return Seq(
        # Initialize recipient
        app.state.recipient.set(recipient_.get()),
        app.state.owner.set(Txn.sender())
    )

@app.external
def deposit(
    payment: pt.abi.PaymentTransaction
):
    return seq(
        Assert(Txn.sender() == app.state.owner,
            comment="Only owner can deposit"),
        Assert(Txn.receiver() == Global.current_application_address())
    )

@app.external
def withdraw(
    amount: pt.abi.Uint64
):
    return Seq(
        Assert(Txn.sender() == app.state.recipient,
            comment="Only the recipient can withdraw"),

        # Withdraw specified amount
        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.receiver: app.state.recipient,
            TxnField.amount: amount.get(),
            TxnField.fee: Int(0),
        })
    )


if __name__ == "__main__":
    app.build().export("artifacts")
