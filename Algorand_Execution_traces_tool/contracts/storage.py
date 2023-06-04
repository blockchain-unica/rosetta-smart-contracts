from pyteal import *
import beaker

pragma(compiler_version="^0.23.0")

class StorageState:
    number = beaker.GlobalStateValue(
        stack_type=TealType.uint64,
    )

app = (
    beaker.Application("Storage", state=StorageState())
)

@app.create
def create(): 
    return Approve()

@app.external
def store(
    number_: abi.Uint64,
):
    return Seq(
        app.state.number.set(number_.get())
    )

@app.external(read_only=True)
def retrieve(*, output: abi.Uint64):
    return output.set(app.state.number)


if __name__ == "__main__":
    app.build().export("artifacts")
