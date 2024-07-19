from typing import Literal
from pyteal import *
import beaker

pragma(compiler_version="^0.24.1")

class States:
    JOIN0 = Int(0)
    JOIN1 = Int(1)
    COMMIT0 = Int(2)
    COMMIT1 = Int(3)
    REVEAL0 = Int(4)
    REVEAL1 = Int(5)
    WIN = Int(6)
    END = Int(7)

class LotteryState:
    end_join = beaker.GlobalStateValue(
        stack_type=TealType.uint64,
        static=True,
    )
    end_reveal = beaker.GlobalStateValue(
        stack_type=TealType.uint64,
        static=True,
    )
    bet_amount = beaker.GlobalStateValue(
        stack_type=TealType.uint64,
    )
    state = beaker.GlobalStateValue(
        stack_type=TealType.uint64,
        descr="The current logical state.",
    )
    player0 = beaker.GlobalStateValue(
        stack_type=TealType.bytes,
    )
    hash0 = beaker.GlobalStateValue(
        stack_type=TealType.bytes,
    )
    secret0 = beaker.GlobalStateValue(
        stack_type=TealType.bytes,
    )
    player1 = beaker.GlobalStateValue(
        stack_type=TealType.bytes,
    )
    hash1 = beaker.GlobalStateValue(
        stack_type=TealType.bytes,
    )
    secret1 = beaker.GlobalStateValue(
        stack_type=TealType.bytes,
    )

app = beaker.Application("Lottery", state=LotteryState())

@app.create
def create():
    return Seq(
        app.state.end_join.set(Global.round() + Int(1000)),
        app.state.end_reveal.set(Global.round() + Int(2000)),

        app.state.state.set(States.JOIN0),
    )

@app.no_op
def join0(
    hash_: abi.StaticBytes[Literal[32]],
    payment: abi.PaymentTransaction,
):
    return Seq(
        Assert(app.state.state.get() == States.JOIN0),
        Assert(payment.get().receiver() == Global.current_application_address()),

        app.state.player0.set(Txn.sender()),
        app.state.hash0.set(hash_.get()),
        app.state.bet_amount.set(payment.get().amount()),

        app.state.state.set(States.JOIN1),
    )

@app.close_out
def redeem0_nojoin1():
    return Seq(
        Assert(app.state.state.get() == States.JOIN1),
        Assert(Global.round() > app.state.end_join.get()),

        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.close_remainder_to: app.state.player0.get(),
            TxnField.fee: Int(0),
        }),

        app.state.state.set(States.END),
    )

@app.no_op
def join1(
    hash_: abi.StaticBytes[Literal[32]],
    payment: abi.PaymentTransaction,
):
    return Seq(
        Assert(app.state.state.get() == States.JOIN1),
        Assert(app.state.hash0.get() != hash_.get()),
        Assert(payment.get().receiver() == Global.current_application_address()),
        Assert(payment.get().amount() == app.state.bet_amount.get()),

        app.state.player1.set(Txn.sender()),
        app.state.hash1.set(hash_.get()),

        app.state.state.set(States.REVEAL0),
    )

@app.close_out
def redeem1_noreveal0():
    return Seq(
        Assert(app.state.state.get() == States.REVEAL0),
        Assert(Global.round() > app.state.end_reveal.get()),

        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.close_remainder_to: app.state.player1.get(),
            TxnField.fee: Int(0),
        }),

        app.state.state.set(States.END),
    )

@app.no_op
def reveal0(
    secret_: abi.String,
):
    return Seq(
        Assert(app.state.state.get() == States.REVEAL0),
        Assert(Txn.sender() == app.state.player0.get()),
        Assert(Keccak256(secret_.get()) == app.state.hash0.get()),

        app.state.secret0.set(secret_.get()),

        app.state.state.set(States.REVEAL1),
    )


@app.close_out
def redeem0_noreveal1():
    return Seq(
        Assert(app.state.state.get() == States.REVEAL1),
        Assert(Global.round() > app.state.end_reveal.get()),

        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.close_remainder_to: app.state.player0.get(),
            TxnField.fee: Int(0),
        }),

        app.state.state.set(States.END),
    )

@app.no_op
def reveal1(
    secret_: abi.String,
):
    return Seq(
        Assert(app.state.state.get() == States.REVEAL1),
        Assert(Txn.sender() == app.state.player1.get()),
        Assert(Keccak256(secret_.get()) == app.state.hash1.get()),

        app.state.secret1.set(secret_.get()),

        app.state.state.set(States.WIN),
    )


@app.no_op
def win():
    return Seq(
        Assert(app.state.state.get() == States.WIN),


        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.close_remainder_to:
                If(Mod(Len(app.state.secret0.get()) + Len(app.state.secret1.get()), Int(2)) == Int(0)).Then(
                    app.state.player0.get()
                ).Else(
                    app.state.player1.get()
                ),
        }),

        app.state.state.set(States.END),
    )

if __name__ == "__main__":
    app.build().export("artifacts")
