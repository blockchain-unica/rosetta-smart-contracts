import pyteal as pt
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
        descr="Address of recovery account",
    )
    wait_time = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        static=True,
        descr="Time to be waited before withdraw finalization",
    )
    request_time = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        descr="Round in which the withdrawal was requested",
    )
    receiver = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
        descr="Receiving address of scheduled withdrawal",
    )
    amount = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        descr="Amount scheduled to be withdrawn",
    )
    state = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        descr="Contract logical state: IDLE/REQ",
    )

app = beaker.Application("Vault", state=VaultState())

@app.create
def create(
    recovery_: pt.abi.Address,
    wait_time_: pt.abi.Uint64,
):
    return pt.Seq(
        # Initialize static parameters
        app.state.recovery.set(recovery_.get()),
        app.state.wait_time.set(wait_time_.get()),

        # Transition to initial state
        app.state.state.set(States.IDLE),
    )

@app.external
def withdraw(
    amount_: pt.abi.Uint64,
    receiver_: pt.abi.Address,
):
    return Seq(
        Assert(app.state.state == States.IDLE,
               comment="No withdrawal request in progress"),
        Assert(app.state.amount <=  pt.Balance(Global.current_application_address()),
               comment="Amount to be withdrawn is available"),
        Assert(Txn.sender() == Global.creator_address(),
               comment="Creator requested the withdraw"),
        
        # Set withdrawal information
        app.state.request_time.set(Global.round()),
        app.state.amount.set(amount_.get()),
        app.state.receiver.set(receiver_.get()),

        # Transition to REQ state (withdrawal in progress)
        app.state.state.set(States.REQ),
    )

@app.external
def finalize():
    return Seq(
        Assert(app.state.state == States.REQ,
               comment="Withdrawal request in progress"),
        Assert(Global.round() >= app.state.request_time + app.state.wait_time,
               comment="Enough time has passed"),
        Assert(Txn.sender() == Global.creator_address(),
               comment="Only the creator can authorize the withdrawal finalization"),

        # Finalize withdrawal
        pay_or_close(app.state.receiver, app.state.amount),

        # Transition to IDLE state (wait for withdrawal)
        app.state.state.set(States.IDLE),
    )

@app.external
def cancel():
    return Seq(
        Assert(app.state.state == States.REQ,
               comment="Withdrawal request in progress"),
        Assert(Txn.sender() == app.state.recovery,
               comment="Only the recovery account can cancel a withdrawal"),

        # Transition to IDLE state (wait for withdrawal)
        app.state.state.set(States.IDLE),
    )
    
@pt.Subroutine(pt.TealType.none)
def pay_or_close(receiver, amt):
    return (
        # If full balance is being transferred, close
        pt.If(pt.Balance(Global.current_application_address()) == amt).Then(
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


if __name__ == "__main__":
    app.build().export("artifacts")
