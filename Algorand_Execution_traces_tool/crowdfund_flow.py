from wrapper import WApp
from algosdk.transaction import OnComplete
from contracts.crowdfund import app

wapp = WApp(app)

receiver = wapp.fetch_client()
donator1 = wapp.fetch_client()
donator2 = wapp.fetch_client()

rnd = wapp.curr_round()

receiver.create(
    receiver_=receiver.pk,
    end_donate_=rnd+10,
    goal_=250000,
)

donator1.call("donate", on_complete=OnComplete.OptInOC,
    donation=donator1.pay_txn(wapp.address, 200000)
)

donator2.call("donate", on_complete=OnComplete.OptInOC,
    donation=donator2.pay_txn(wapp.address, 100000)
)

wapp.wait_rounds_from(rnd, 10)

receiver.call("withdraw", flat_fee=2000)

print("total cost:", wapp.total_fees)
