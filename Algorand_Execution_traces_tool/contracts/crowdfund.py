import pyteal as pt
from pyteal import Seq, Assert, Txn, Global, TxnField, TxnType, InnerTxnBuilder, Int
import beaker

pt.pragma(compiler_version="^0.23.0")

class CrowdfundState:
    end_donate = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        static=True,
        descr="Last round in which users can donate"
    )
    goal = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        static=True,
        descr="Amount of uALGO that must be donated for the crowdfunding to be succesful",
    )
    receiver = beaker.GlobalStateValue(
        stack_type=pt.TealType.bytes,
        static=True,
        descr="Receiver of the donated funds",
    )
    total_donated = beaker.GlobalStateValue(
        stack_type=pt.TealType.uint64,
        descr="Total amount donated",
    )
    donated = beaker.LocalStateValue(
        stack_type=pt.TealType.uint64,
        descr="Amount donated by each donor",
    )

app = (
    beaker.Application("Crowdfund", state=CrowdfundState())
)

@app.create
def create(
    receiver_: pt.abi.Address,
    end_donate_: pt.abi.Uint64,
    goal_: pt.abi.Uint64
):
    return pt.Seq(
        # Initialize static parameters
        app.state.receiver.set(receiver_.get()),
        app.state.end_donate.set(end_donate_.get()),
        app.state.goal.set(goal_.get()),
    )

@app.external(method_config=pt.MethodConfig(
    opt_in=pt.CallConfig.CALL,
    no_op=pt.CallConfig.CALL,
))
def donate(
    donation: pt.abi.PaymentTransaction,
):
    return Seq(
        # If not present we would have multiple problems:
        # - the first donator would not be able to donate, as the MBR of the contract would not be satisfied
        # - when reclaiming the donated funds, the donator could be stuck not being able to reclaim their 
        #   donated amount, as that would make the contract balance go below the MBR
        Assert(donation.get().amount() + app.state.donated[Txn.sender()] >= Int(100000),
               comment="Each donor must donate at least MBR"),
        Assert(donation.get().receiver() == Global.current_application_address(),
               comment="Donation must be sent to the contract"),
        Assert(Global.round() <= app.state.end_donate,
               comment="Donation period must still be open"),
        
        # Update total and local donated amounts
        app.state.total_donated.set(app.state.total_donated + donation.get().amount()),
        app.state.donated[Txn.sender()].set(app.state.donated[Txn.sender()] + donation.get().amount()),
    )

@app.external
def withdraw():
    return Seq(
        Assert(Global.round() > app.state.end_donate,
               comment="Donation period must be over"),
        Assert(app.state.total_donated >= app.state.goal,
               comment="Goal must have been reached"),
        
        # Send collected funds to receiver
        pay_or_close(app.state.receiver, app.state.total_donated),
 
        # Remember that funds have been withdrawn
        app.state.total_donated.set(Int(0)),
    )

@app.close_out
def reclaim():
    return Seq(
        Assert(Global.round() > app.state.end_donate,
               comment="Donation period must be over"),
        Assert(app.state.total_donated < app.state.goal,
               comment="Goal must not have been reached"),
        Assert(app.state.donated[Txn.sender()] > Int(0),
               comment="Caller must have donated something"),
        
        # Send donated funds back
        pay_or_close(Txn.sender(), app.state.donated[Txn.sender()]),

        # Remember that funds have been withdrawn
        app.state.donated[Txn.sender()].set(Int(0)),
    )

@pt.Subroutine(pt.TealType.none)
def pay_or_close(receiver, amt):
    return (
        # Only do something if an amount > 0 is being sent
        pt.If(amt > Int(0)).Then(
            # If it is the full balance (minus some < MBR amount), send all
            # Note that any amount < MBR must have been sent outside of the contracts logic, as any donation
            # must be >= MBR
            pt.If(pt.Balance(Global.current_application_address()) - amt < Int(100000)).Then(
                InnerTxnBuilder.Execute({
                    TxnField.type_enum: TxnType.Payment,
                    TxnField.close_remainder_to: receiver,
                    TxnField.fee: Int(0),
                })
            # Otherwise, just send the specified amount
            ).Else(
                InnerTxnBuilder.Execute({
                    TxnField.type_enum: TxnType.Payment,
                    TxnField.receiver: receiver,
                    TxnField.amount: amt,
                    TxnField.fee: Int(0),
                })
            )
        )
    )


if __name__ == "__main__":
    app.build().export("artifacts")
