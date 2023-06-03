from pyteal import *
import beaker
from .product import app as product, create as pcreate
from algosdk.v2client.algod import AlgodClient

algod = AlgodClient('', 'https://testnet-api.algonode.cloud')
pragma(compiler_version="^0.23.0")

class States:
    WAITING = Int(0)
    VESTING = Int(1)

class FactoryState:
    length = beaker.GlobalStateValue(
        stack_type=TealType.uint64,
        descr="How many products are in state",
    )
    products = beaker.lib.storage.BoxMapping(
        key_type=abi.Uint64,
        value_type=abi.Address,
    )

app = beaker.Application("Factory", state=FactoryState())
pb = product.build()
pba = algod.compile(pb.approval_program)["result"]
pbc = algod.compile(pb.clear_program)["result"]

@app.create
def create():
    return Seq(
        app.state.length.set(Int(0))
    )

@app.external
def create_product(
    deposit: abi.PaymentTransaction,
    tag: abi.String,
    *, output: abi.Uint64
):
    return Seq(
        InnerTxnBuilder.ExecuteMethodCall(
            app_id=None,
            method_signature=pcreate.method_signature(),
            args=[Txn.sender(), tag],
            extra_fields={
                TxnField.approval_program: Bytes("base64", pba),
                TxnField.clear_state_program: Bytes("base64", pbc),
                TxnField.global_num_byte_slices: Int(2),
                TxnField.fee: Int(0),
            }
        ),
        output.set(InnerTxn.created_application_id())
    )

# @app.external(read_only = True)
# def get_products(*, output: abi.DynamicArray(abi.Address)):
#     return Seq(?)



if __name__ == "__main__":
    app.build().export("artifacts")
