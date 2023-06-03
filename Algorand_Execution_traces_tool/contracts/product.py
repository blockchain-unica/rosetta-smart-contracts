from pyteal import *
import beaker

pragma(compiler_version="^0.23.0")

class ProductState:
    tag = beaker.GlobalStateValue(
        stack_type=TealType.bytes,
        static=True
    )
    owner = beaker.GlobalStateValue(
        stack_type=TealType.bytes,
        static=True,
    )

app = beaker.Application("Product", state=ProductState())

@app.create
def create(
    owner_: abi.Address,
    tag_: abi.String,
):
    return Seq(
        app.state.owner.set(owner_.get()),
        app.state.tag.set(tag_.get()),
    )

@app.external(read_only=True)
def get_tag(*, output: abi.String):
    return Seq(
        Assert(Txn.sender() == app.state.owner,
               comment="Only the owner can read the tag"),
        
        output.set(app.state.tag.get()),
    )

@app.external(read_only=True)
def get_factory(*, output: abi.Address):
    return output.set(Global.creator_address())


if __name__ == "__main__":
    app.build().export("artifacts")
