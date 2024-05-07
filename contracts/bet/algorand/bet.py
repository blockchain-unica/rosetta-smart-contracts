import pyteal as pt
from pyteal import Seq, Assert, Txn, Global, TxnField, TxnType, InnerTxnBuilder, Int
import beaker

pt.pragma(compiler_version="^0.23.0")

class States:
    CREATED = Int(0)
    JOINED1 = Int(1)
    JOINED2 = Int(2)

class BetState:
    deadline = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        static=True,
        descr=""
    )
    oracle = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
        static=True,
        descr="",
    )
    opponent = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
        static=True,
        descr="",
    )
    wager = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        descr="",
    )
    state = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        descr="",
    )

app = (
    beaker.Application("Bet", state=BetState())
)

@app.create
def create():
    return pt.Approve()

@app.external
def init(
    timeout_: pt.abi.Uint64,
    oracle_: pt.abi.Address
):
    return pt.Seq(
        app.state.oracle.set(oracle_.get()),
        app.state.deadline.set(Global.round() + timeout_.get())
    )

@app.external
def join1(
    txn: pt.abi.PaymentTransaction,
    opponent_: pt.abi.Address,
):
    return pt.Seq(
        Assert(app.state.state.get() == States.CREATED),
        Assert(txn.get().sender() == Global.creator_address()),
        Assert(txn.get().receiver() == Global.current_application_address()),
        app.state.opponent.set(opponent_.get()),
        app.state.wager.set(txn.get().amount()),
        app.state.state.set(States.JOINED1),
    )

@app.external
def join2(
    txn: pt.abi.PaymentTransaction,
):
    return pt.Seq(
        Assert(app.state.state.get() == States.JOINED1),
        Assert(Txn.sender() == app.state.opponent.get()),
        Assert(txn.get().receiver() == Global.current_application_address()),
        Assert(txn.get().amount() == app.state.wager.get()),
        Assert(Global.round() <= app.state.deadline.get()),
        app.state.wager.set(txn.get().amount()),
        app.state.state.set(States.JOINED2),
    )

@app.delete
def timeout(
    _owner: pt.abi.Account,
    _opponent: pt.abi.Account,
): 
    return pt.Seq(
        Assert(Global.round() > app.state.deadline.get()),
        pt.If(app.state.state.get() == States.JOINED2).Then(
            InnerTxnBuilder.Execute({
                TxnField.type_enum: TxnType.Payment,
                TxnField.receiver: app.state.opponent.get(),
                TxnField.amount: app.state.wager.get(),
                TxnField.fee: Int(0),
            })
        ),
        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.close_remainder_to: Global.creator_address(),
            TxnField.fee: Int(0),
        })
    )

@app.delete
def win(
    winner: pt.abi.Account,
):
    return pt.Seq(
        Assert(winner.address() == app.state.opponent.get() 
                or winner.address() == Global.creator_address()),
        Assert(Txn.sender() == app.state.oracle.get()),
        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.close_remainder_to: winner.address(),
            TxnField.fee: Int(0),
        })
    )

if __name__ == "__main__":
    app.build().export("artifacts")
