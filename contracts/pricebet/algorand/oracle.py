from typing import Literal
from pyteal import *
import beaker

pragma(compiler_version="^0.24.1")

app = beaker.Application("Oracle")

@app.no_op
def get_exchange_rate(*, output: abi.Uint64):
    return output.set(Int(10))
