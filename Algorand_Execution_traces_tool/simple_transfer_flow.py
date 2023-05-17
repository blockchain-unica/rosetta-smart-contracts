from wrapper import WApp
from contracts.simple_transfer import app

wapp = WApp(app)

owner = wapp.fetch_client()
recipient = wapp.fetch_client()

owner.create(
    recipient_ = recipient.pk,
)

owner.pay(wapp.address, 1000000)

### 3. Partial withdraw
recipient.call("withdraw", flat_fee=2000,
    amount  = 200000
)

### 4. Total withdraw
recipient.call("withdraw_all", flat_fee=2000)

print("total cost:", wapp.total_fees)
