from wrapper import WApp
import algosdk
from algosdk.transaction import OnComplete
from algosdk.encoding import checksum
from contracts.decentralized_identity import app

wapp = WApp(app)

user1 = wapp.fetch_client()
user2 = wapp.fetch_client()
user3 = wapp.fetch_client()

rnd = wapp.curr_round()

user1.create()

user1.opt_in()
user1.call("change_owner",
    identity=user1.pk,
    new_owner=user2.pk,
)

user2.call("change_owner",
    identity=user1.pk,
    new_owner=user3.pk,
)

user3.call("add_delegate",
    _=user3.pay_txn(wapp.address, 120000),
    identity=user1.pk,
    delegate_type=checksum(b"type1"),
    delegate=user2.pk,
    validity=10,
    boxes=[(wapp.id, checksum(algosdk.encoding.decode_address(user1.pk) + checksum(b"type1") + algosdk.encoding.decode_address(user2.pk)))],
)

print(user1.call("valid_delegate",
    identity=user1.pk,
    delegate_type=checksum(b"type1"),
    delegate=user2.pk,
    boxes=[(wapp.id, checksum(algosdk.encoding.decode_address(user1.pk) + checksum(b"type1") + algosdk.encoding.decode_address(user2.pk)))],
).raw_value)

wapp.wait_rounds(10)

print(user1.call("valid_delegate",
    identity=user1.pk,
    delegate_type=checksum(b"type1"),
    delegate=user2.pk,
    boxes=[(wapp.id, checksum(algosdk.encoding.decode_address(user1.pk) + checksum(b"type1") + algosdk.encoding.decode_address(user2.pk)))],
).raw_value)

print("data:", user1.app_client.get_global_state())
print("data:", user1.app_client.get_local_state())
print("total cost:", wapp.total_fees)
