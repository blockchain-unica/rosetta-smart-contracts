from typing import Literal
from pyteal import *
import beaker

pragma(compiler_version="^0.23.0")

class Delegation(abi.NamedTuple):
    identity: abi.Field[abi.Address]
    delegate_type: abi.Field[abi.StaticBytes[Literal[32]]]
    delegate: abi.Field[abi.Address]

class DecentralizedIdentityState:
    owner = beaker.LocalStateValue(
        stack_type=TealType.bytes,
        descr="The owner of an identity",
    )
    delegates = beaker.lib.storage.BoxMapping(
        key_type=abi.StaticBytes[Literal[32]],
        value_type=abi.Uint64,
    )

app = (
    beaker.Application("DecentralizedIdentity", state=DecentralizedIdentityState())
)

@app.create
def create():
    return Approve()

@app.opt_in
def create_identity():
    return Seq(
        app.state.owner[Txn.sender()].set(Txn.sender()),
    )

@app.external
def change_owner(
    identity: abi.Account,
    new_owner: abi.Address,
):
    return Seq(
        Assert(app.state.owner[identity.address()] == Txn.sender()),
        app.state.owner[identity.address()].set(new_owner.encode())
    )

@app.external
def add_delegate(
    _: abi.PaymentTransaction,
    identity: abi.Account,
    delegate_type: abi.StaticBytes[Literal[32]],
    delegate: abi.Address,
    validity: abi.Uint64,
):
    return Seq(
        Assert(app.state.owner[identity.address()] == Txn.sender()),
        (id_addr := abi.Address()).set(identity.address()),
        (delegation := Delegation()).set(id_addr, delegate_type, delegate),
        app.state.delegates[Sha512_256(delegation.encode())].set(Itob(Global.round() + validity.get())),
    )

@app.external
def valid_delegate(
    identity: abi.Account,
    delegate_type: abi.StaticBytes[Literal[32]],
    delegate: abi.Address,
    *, output: abi.Uint64,
):
    return Seq(
        (id_addr := abi.Address()).set(identity.address()),
        (delegation := Delegation()).set(id_addr, delegate_type, delegate),
        output.set(Btoi(app.state.delegates[Sha512_256(delegation.encode())].get()) > Global.round()),
    )

if __name__ == "__main__":
    app.build().export("artifacts")
