import pyteal as pt
from pyteal import Seq, Assert, Txn, Global, TxnField, TxnType, InnerTxnBuilder, Int
import beaker

pt.pragma(compiler_version="^0.23.0")

class States:
    IDLE = Int(0)
    REQ = Int(1)

class VaultState:
    recovery = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        static=True,
    )
    wait_time = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        static=True,
    )
    
    receiver = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
    )
    request_time = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
    )
    amount = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
    )
    state = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
    )

app = beaker.Application("Vault", state=VaultState())

@app.create
def create(
    recovery_: pt.abi.Address,
    wait_time_: pt.abi.Uint64,
):
    return pt.Seq(
        app.state.recovery.set(recovery_),
        app.state.wait_time.set(wait_time_),
        app.state.state.set(States.IDLE),
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
