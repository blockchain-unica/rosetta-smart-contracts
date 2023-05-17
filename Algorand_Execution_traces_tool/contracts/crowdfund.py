import pyteal as pt
from pyteal import Seq, Assert, Txn, Global, TxnField, TxnType, InnerTxnBuilder, Int
import beaker

pt.pragma(compiler_version="^0.23.0")

class CrowdfundState:
    end_donate = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        static=True,
        descr="last round in which user can donate"
    )
    goal = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        static=True,
        descr="amount of uALGO that must be donated for the crowdfunding to be succesful",
    )
    receiver = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
        static=True,
        descr="receiver of the donated funds",
    )
    total_donated = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        static=False,
        descr="total amount donated",
        default=Int(0),
    )
    donated = beaker.LocalStateValue(
        stack_type=pt.TealType.uint64,
        static=False,
        descr="amount donated by each donor",
        default=Int(0),
    )

app = (
    beaker.Application("Crowdfund", state=CrowdfundState())
)

@app.create
def create(
    receiver_: pt.abi.Address, 
    end_donate_: pt.abi.Uint64,
    goal_: pt.abi.Uint64
):
    return pt.Seq(
        app.state.receiver.set(receiver_),
        app.state.end_donate.set(end_donate_),
        app.state.goal.set(goal_),
    )

@app.external(method_config=pt.MethodConfig(
    opt_in=pt.CallConfig.ALL,
    no_op=pt.CallConfig.ALL,
))
def donate(
    donation: pt.abi.PaymentTransaction,
):
    """
    anyone can transfer native cryptocurrency to the contract until the deadline;
    """
    return Seq(
        Assert(donation.get().receiver() == Global.current_application_address()),
        Assert(Global.round() <= app.state.end_donate),
        app.state.total_donated.set(app.state.total_donate + donation.get().amount()),
        app.state.donated[Txn.sender()].set(app.state.donate[Txn.sender()] + donation.get().amount()),
    )

@app.external
def withdraw():
    """
    after the deadline, the recipient can withdraw the funds stored in the contract, provided that the goal has been reached;
    """
    return Seq(
        Assert(Global.round() > app.state.end_donate),
        Assert(app.state.total_donated >= app.state.goal),
        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.amount: app.state.total_donated,
            TxnField.receiver: Txn.sender(),
            TxnField.fee: Int(0),
        }),
        app.state.total_donated.set(Int(0)),
    )

@app.close_out
def reclaim():
    """after the deadline, if the goal has not been reached donors can withdraw the amounts they have donated.
    """
    return Seq(
        Assert(Global.round() > app.state.end_donate),
        Assert(app.state.total_donated < app.state.goal),
        Assert(app.state.donated[Txn.sender()] > 0),
        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.amount: app.state.donated[Txn.sender()],
            TxnField.receiver: Txn.sender(),
            TxnField.fee: Int(0),
        }),
        app.state.donated[Txn.sender()].set(Int(0)),
    )

if __name__ == "__main__":
    app.build().export("crowdfunding_src")
