from wrapper import WApp
from algosdk.transaction import OnComplete
from algosdk.encoding import checksum
from contracts.anonymous_data import app

wapp = WApp(app)

owner = wapp.fetch_client()
user = wapp.fetch_client()

rnd = wapp.curr_round()

owner.create()

id = checksum(b"id123")
user.call("store_data",
    _=user.pay_txn(wapp.address, 120000),
    user_id=id,
    data="data",
    boxes=[(wapp.id, id)])

print("data:", user.app_client.get_box_contents(id))

print("total cost:", wapp.total_fees)
