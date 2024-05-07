from pyteal import *
import beaker

class TokenTransferState:
    recipient = beaker.GlobalStateValue(
        stack_type=TealType.bytes,
    )
    owner = beaker.GlobalStateValue(
        stack_type=TealType.bytes,
    )
    tokenId = beaker.GlobalStateValue(
        stack_type=TealType.uint64,
    )

app = (
    beaker.Application("TokenTransfer", state=TokenTransferState())
)

@app.create
def create(
    recipient: abi.Address,
    tokenId: abi.Uint64
): 
    return Seq(
        app.state.recipient.set(recipient.get()),
        app.state.tokenId.set(tokenId.get())
    )

@app.external
def deposit(
    payment: abi.AssetTransferTransaction
):
    return Seq(
        Assert(payment.get().sender() == app.state.owner.get()),
        Assert(payment.get().receiver() == Global.current_application_address()),
        Assert(payment.get().application_id() == app.state.tokenId.get()),
        Assert(payment.get().asset_sender() == app.state.owner.get()),
        Assert(payment.get().asset_receiver() == Global.current_application_address()),
    )

@app.external
def withdraw(
    payment: abi.AssetTransferTransaction
):
    return Seq(
        Assert(payment.get().sender() == Global.current_application_address()),
        Assert(payment.get().receiver() == app.state.recipient.get()),
        Assert(payment.get().application_id() == app.state.tokenId.get()),
        Assert(payment.get().asset_sender() == Global.current_application_address()),
        Assert(payment.get().asset_receiver() == app.state.recipient.get()),
)

if __name__ == "__main__":
    print(app.build().approval_program)