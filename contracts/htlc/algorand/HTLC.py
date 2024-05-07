import beaker as bk
import pyteal as pt
from pyteal import Seq, Assert, Txn, Global, TxnField, TxnType, InnerTxnBuilder, Int, TealType, abi

class HTLCState:
    # Owner
    owner = bk.GlobalStateValue(
        stack_type = pt.TealType.bytes
    )
    # Verifier
    verifier = bk.GlobalStateValue(
        stack_type = pt.TealType.bytes
    )
    # Hash
    hash = bk.GlobalStateValue(
        stack_type = pt.TealType.bytes
    )
    # Reveal timeout
    reveal_timeout = bk.GlobalStateValue(
        stack_type = pt.TealType.uint64
    )

app = bk.Application("HTLC", state=HTLCState())

@app.create
def create(
    verifier: abi.Address,
    hash: abi.String,
    delay: abi.Uint64,
    payment_txn: abi.PaymentTransaction
):
    return pt.Seq([
        Assert(payment_txn.get().amount() >= pt.Int(1000000), comment="Payment must be at least 1 ALGO"),
        Assert(payment_txn.get().sender() == Global.creator_address(), comment="Only the creator can create the contract"),
        Assert(payment_txn.get().receiver() == Global.current_application_address(), comment="Funds must be deposited to the contract"),
        app.state.owner.set(Txn.sender()),
        app.state.verifier.set(verifier.get()),
        app.state.hash.set(hash.get()),
        app.state.reveal_timeout.set(delay.get())
    ])

@app.external
def reveal(
    s: abi.String
):
    return pt.Seq([
        pt.Assert(pt.Txn.sender() == app.state.owner.get(), comment="Only the owner can reveal"),
        pt.Assert(pt.Keccak256(s.get()) == app.state.hash.get(), comment="Hashes do not match"),
        pt.InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.receiver: app.state.owner.get(),
            TxnField.amount: Int(1000000),
            TxnField.fee: Int(0),
        }),
    ])

@app.external
def timeout():
    return Seq([
        Assert(Global.round() > app.state.reveal_timeout.get()),
        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.receiver: app.state.verifier.get(),
            TxnField.amount: Int(1000000),
            TxnField.fee: Int(0),
        }),
    ])

app_spec = app.build()
print(app_spec.to_json())