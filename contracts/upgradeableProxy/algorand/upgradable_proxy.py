from pyteal import *
import beaker

pragma(compiler_version="^0.23.0")

app = (
    beaker.Application("UpgradableProxy")
)

@app.create
def create(): 
    return Approve()

@app.update
def update():
    return Seq(
        Assert(Txn.sender() == Global.creator_address())
    )

@app.external
def logic():
    return Approve()

if __name__ == "__main__":
    app.build().export("artifacts")
