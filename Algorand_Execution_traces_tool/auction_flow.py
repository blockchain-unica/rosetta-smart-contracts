from wrapper import WApp
from algosdk.transaction import OnComplete
from contracts.auction import app

wapp = WApp(app)

owner = wapp.fetch_client()
buyer1 = wapp.fetch_client()
buyer2 = wapp.fetch_client()

owner.create(
    obj_="Chair",
    starting_bid_=100000,
)

owner.call("start",
    duration_=10,
)

buyer1.call("bid", on_complete=OnComplete.OptInOC,
    deposit=buyer1.pay_txn(wapp.address, 100001)
)

buyer2.call("bid", on_complete=OnComplete.OptInOC,
    deposit=buyer2.pay_txn(wapp.address, 100002)
)

wapp.wait_rounds(10)

owner.call("end", flat_fee=2000)
buyer1.call("withdraw", flat_fee=2000)

print("total cost:", wapp.total_fees)
