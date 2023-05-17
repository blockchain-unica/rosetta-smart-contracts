from wrapper import WApp
from contracts.simple_wallet import app

wapp = WApp(app)

owner = wapp.fetch_client()
recipient = wapp.fetch_client()

owner.create()

owner.pay(wapp.address, 300000)

owner.call("create_transaction",
    to=recipient.pk,
    value=100000,
    data=b"ciao",
    boxes=[(wapp.id, b"txn_0")],
)

owner.call("execute_transaction", flat_fee=2000,
    tx_id=0,
    boxes=[(wapp.id, b"txn_0")],
    accounts=[recipient.pk],
)

owner.call("withdraw", flat_fee=2000)

print("total cost:", wapp.total_fees)
