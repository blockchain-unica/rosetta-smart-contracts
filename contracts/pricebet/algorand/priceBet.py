from typing import Literal
from pyteal import *
import beaker
import oracle

pragma(compiler_version="^0.24.1")

class PriceBetState:
    initial_pot = beaker.GlobalStateValue(
        stack_type=TealType.uint64,
    )
    deadline_block = beaker.GlobalStateValue(
        stack_type=TealType.uint64,
        static=True,
    )
    exchange_rate = beaker.GlobalStateValue(
        stack_type=TealType.uint64,
    )
    oracle_id = beaker.GlobalStateValue(
        stack_type=TealType.uint64,
    )
    owner = beaker.GlobalStateValue(
        stack_type=TealType.bytes,
    )
    player = beaker.GlobalStateValue(
        stack_type=TealType.bytes,
        default=Bytes("0x00")
    )

app = beaker.Application("PriceBet", state=PriceBetState())

@app.create
def create(oracle: abi.Application, deadline: abi.Uint64, exchange_rate: abi.Uint64, initial_pot: abi.PaymentTransaction):
    return Seq(
        app.state.initial_pot.set(initial_pot.get().amount()),
        app.state.owner.set(Txn.sender()),
        app.state.oracle_id.set(oracle.application_id()),
        app.state.deadline_block.set(deadline.get()),
        app.state.exchange_rate.set(exchange_rate.get())
    )

@app.no_op
def join(bet: abi.PaymentTransaction):
    return Seq(
        Assert(bet.get().amount() == app.state.initial_pot.get()),
        Assert(app.state.player.get() == Bytes("0x00")),
        app.state.player.set(Txn.sender())
    )

@app.no_op
def win():
    return Seq(
        Assert(Global.round() < app.state.deadline_block.get()),
        Assert(Txn.sender() == app.state.player.get()),
        InnerTxnBuilder.ExecuteMethodCall(
            app_id=app.state.oracle_id.get(),
            method_signature=oracle.get_exchange_rate.method_signature(),
            args=[],
            extra_fields={
                TxnField.fee: Int(0)
            }
        ),
        # Getting application call returned value from logs, chopping first 4 bytes=hash(return)
        Assert(Suffix(InnerTxn.last_log(), Int(4)) == app.state.exchange_rate.get()),

        # payment to player
        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.close_remainder_to: app.state.player.get(),
        })
    )

@app.no_op
def timeout():
    return Seq(
        Assert(Global.round() >= app.state.deadline_block.get()),
        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.close_remainder_to: app.state.owner.get(),
        })
    )

if __name__ == "__main__":
    compiled = app.build().export("./playground/price_bet/Artifacts")

