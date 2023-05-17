import pyteal as pt
import pytealutils.strings as pts
from pyteal import Seq, Assert, Txn, Global, TxnField, TxnType, InnerTxnBuilder, Int
import beaker
from beaker import GlobalStateValue
from beaker.consts import FALSE
from beaker.lib.storage import BoxMapping

pt.pragma(compiler_version="^0.23.0")

class TransactionRecord(pt.abi.NamedTuple):
    executed: pt.abi.Field[pt.abi.Bool]
    to: pt.abi.Field[pt.abi.Address]
    value: pt.abi.Field[pt.abi.Uint64]
    data: pt.abi.Field[pt.abi.DynamicBytes]

class SimpleWalletState:
    amount = GlobalStateValue(pt.TealType.uint64)
    transactions = BoxMapping(pt.abi.Uint64, TransactionRecord, pt.Bytes("txn_"))

app = beaker.Application("Auction", state=SimpleWalletState())

@app.create
def create():
    return Seq(
        app.state.amount.set(Int(0))
    )

@app.external
def create_transaction(
    to: pt.abi.Address ,
    value: pt.abi.Uint64,
    data: pt.abi.DynamicBytes,
):
    return Seq(
        Assert(Txn.sender() == Global.creator_address(),
               comment="Only the creator"),
        
        (executed := pt.abi.Bool()).set(FALSE),
        (to_ := pt.abi.Address()).set(to.get()),
        (value_ := pt.abi.Uint64()).set(value.get()),
        (data_ := pt.abi.DynamicBytes()).set(data.get()),
        (txn := TransactionRecord()).set(executed, to_, value_, data_),
        app.state.transactions[pts.itoa(app.state.amount)].set(txn),

        app.state.amount.set(app.state.amount + Int(1))
    )

@app.external
def execute_transaction(
    tx_id: pt.abi.Uint64,
): 
    return Seq(
        (txn := TransactionRecord()).decode(
            app.state.transactions[pts.itoa(tx_id.get())].get()
        ),
        (executed := pt.abi.Bool()).set(txn.executed),
        (to := pt.abi.Address()).set(txn.to),
        (value := pt.abi.Uint64()).set(txn.value),
        (data := pt.abi.DynamicBytes()).set(txn.data),
        
        Assert(Txn.sender() == Global.creator_address(),                                 
               comment="Only the creator"),
        Assert(executed.get() == Int(0),
               comment="Transaction already executed"),
        
        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.receiver: to.get(),
            TxnField.amount: value.get(),
            TxnField.note: data.get(),
            TxnField.fee: Int(0),
        }),
        
        pt.Pop(app.state.transactions[pts.itoa(tx_id.get())].delete()),
    )

@app.external
def withdraw():
    return Seq(
        Assert(Txn.sender() == Global.creator_address(),                          
               comment="Only the creator"),
        
        InnerTxnBuilder.Execute({
            TxnField.type_enum: TxnType.Payment,
            TxnField.close_remainder_to: Global.creator_address(),
            TxnField.fee: Int(0),
        })
    )

if __name__ == "__main__":
    app.build().export("auction_src")
