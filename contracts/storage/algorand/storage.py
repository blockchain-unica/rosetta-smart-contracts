from pyteal import *
import beaker

pragma(compiler_version="^0.24.1")

class StorageState:
    bytes = beaker.GlobalStateValue(
        stack_type=TealType.bytes,
    )
    string = beaker.GlobalStateValue(
        stack_type=TealType.bytes,
    )

app = (
    beaker.Application("Storage", state=StorageState())
)

@app.create
def create(): 
    return Approve()

@app.external
def storeBytes(
    bytes_: abi.DynamicBytes
):
    return Seq(
        app.state.bytes.set(bytes_.get())
    )

@app.external(read_only=True)
def storeString(
    string_: abi.String
):
    return Seq(
        app.state.string.set(string_.get())
    )


if __name__ == "__main__":
    print(app.build().to_json())
