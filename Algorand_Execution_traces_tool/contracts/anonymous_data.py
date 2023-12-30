from typing import Literal
from pyteal import *
import beaker

class AnonymousDataState:
    data = beaker.lib.storage.BoxMapping(
        key_type=abi.StaticBytes[Literal[32]],
        value_type=abi.String,
    )

app = beaker.Application("AnonymousData", state=AnonymousDataState())

@app.create
def create():
    return Seq()

@app.external
def store_data(
    _: abi.PaymentTransaction,
    user_id: abi.StaticBytes[Literal[32]],
    data: abi.String,
):
    return Seq(
        app.state.data[user_id].set(data),
    )

if __name__ == "__main__":
    app.build().export("artifacts")
