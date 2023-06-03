from pyteal import *
import beaker

pragma(compiler_version="^0.23.0")

class States:
    WAITING = Int(0)
    VESTING = Int(1)

class VestingState:
    released = beaker.GlobalStateValue(
        stack_type=TealType.uint64,
        descr="The amount of uALGOs that have been already sent to the beneficiary",
    )
    amount = beaker.GlobalStateValue(
        stack_type=TealType.uint64,
        static=True,
        descr="The total amount of uALGOs to send to the beneficiary",
    )
    beneficiary = beaker.GlobalStateValue(
        stack_type=TealType.bytes,
        static=True,
        descr="The beneficiary of the vesting, whom will receive the ALGOs",
    )
    start = beaker.GlobalStateValue(
        stack_type=TealType.uint64,
        static=True,
        descr="The starting round",
    )
    duration = beaker.GlobalStateValue(
        stack_type=TealType.uint64,
        static=True,
        descr="The amount of rounds that will take for the vesting to complete",
    )
    state = beaker.GlobalStateValue(
        stack_type=TealType.uint64,
        descr="The logical state of the contract",
    )

app = beaker.Application("Vesting", state=VestingState())

@app.create
def create():
    return Seq(
        app.state.state.set(States.WAITING),
    )

@app.external
def init(
    beneficiary_: abi.Address,
    start_: abi.Uint64,
    duration_: abi.Uint64,
    deposit: abi.PaymentTransaction,
):
    return Seq(
        Assert(app.state.state == States.WAITING,
               comment="Contract must not have been initialized yet"),
        Assert(Txn.sender() == Global.creator_address(),
               comment="Only the creator can initialize the contract"),
        Assert(beneficiary_.get() != Global.zero_address(),
               comment="The beneficiary must be some account"),
        Assert(deposit.get().receiver() == Global.current_application_address(),
               comment="On initialization, some funds must be sent to the contract"),
        Assert(deposit.get().amount() > Int(100000),
               comment="An amount higher than the MBR must be sent"),

        # Initialize contract state
        app.state.beneficiary.set(beneficiary_.get()),
        app.state.start.set(start_.get()),
        app.state.duration.set(duration_.get()),
        # The MBR is removed from the vested amount
        app.state.amount.set(deposit.get().amount() - Int(100000)),

        app.state.state.set(States.VESTING),
    )

@app.external
def release():
    return Seq(
        # Compute amount to be sent
        (amount := abi.Uint64()).set(_releasable()),
        # Send the amount to be released to the beneficiary
        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.receiver: app.state.beneficiary,
            TxnField.amount: amount.get(),
            TxnField.fee: Int(0),
        }),
        # Remember that the amount has been released
        app.state.released.set(app.state.released + amount.get()),
    )

def releasable(*, output: abi.Uint64):
    return Seq(
        # The releasable amount is the vested amount, minus what has already been released
        (timestamp := abi.Uint64()).set(Global.round()),
        (vested := abi.Uint64()).set(_vested_amount(timestamp)),
        output.set(vested.get() - app.state.released),
    )
_releasable = ABIReturnSubroutine(releasable)
app.external(releasable, read_only=True)

def vested_amount(timestamp: abi.Uint64, *, output: abi.Uint64):
    return Seq(
        (total_allocation := abi.Uint64()).set(app.state.amount),
        output.set(_vesting_schedule(total_allocation, timestamp)),
    )
_vested_amount = ABIReturnSubroutine(vested_amount)
app.external(vested_amount, read_only=True)

@ABIReturnSubroutine
def _vesting_schedule(total_allocation: abi.Uint64, timestamp: abi.Uint64, *, output: abi.Uint64):
    return output.set(
        # Before start, no amount is vested
        If(timestamp.get() < app.state.start).Then(
            Int(0),
        # After vesting end, the total amount is vested
        ).ElseIf(timestamp.get() > app.state.start + app.state.duration).Then(
            total_allocation.get(),
        # Otherwise, scale linearly
        ).Else(
            total_allocation.get() * (timestamp.get() - app.state.start) / app.state.duration
        )
    )


if __name__ == "__main__":
    app.build().export("artifacts")
