import pyteal as pt
import pytealutils.transaction as ptt
from pyteal import Seq, Assert, Txn, Global, TxnField, TxnType, InnerTxnBuilder, Int
import beaker

pt.pragma(compiler_version="^0.23.0")

class States:
    IDLE = Int(0)
    REQ = Int(1)

class VaultState:
    recovery = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
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
        app.state.recovery.set(recovery_.get()),
        app.state.wait_time.set(wait_time_.get()),
        app.state.state.set(States.IDLE),
    )

@app.external
def withdraw(
    amount_: pt.abi.Uint64,
    receiver_: pt.abi.Address,
):
    return Seq(
        Assert(app.state.state == States.IDLE),
        Assert(app.state.amount <=  pt.Balance(Global.current_application_address())),
        Assert(Txn.sender() == Global.creator_address()),
        
        app.state.request_time.set(Global.round()),
        app.state.amount.set(amount_.get()),
        app.state.receiver.set(receiver_.get()),
        app.state.state.set(States.REQ),
    )

@app.external
def finalize():
    return Seq(
        Assert(app.state.state == States.REQ),
        Assert(Global.round() >= app.state.request_time + app.state.wait_time),
        Assert(Txn.sender() == Global.creator_address()),

        app.state.state.set(States.IDLE),
        ptt.pay(app.state.receiver, app.state.amount),
    )

@app.external
def cancel():
    return Seq(
        Assert(app.state.state == States.REQ),
        Assert(Txn.sender() == app.state.recovery),
        app.state.state.set(States.IDLE),
    )

if __name__ == "__main__":
    app.build().export("vault_src")
