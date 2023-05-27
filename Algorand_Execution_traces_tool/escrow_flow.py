from wrapper import WApp
from contracts.escrow import app

wapp = WApp(app)

seller = wapp.fetch_client()
buyer = wapp.fetch_client()

seller.create(
    amount_=100000,
    buyer_=buyer.pk,
)

### 2. Deposit money (the buyer deposits the amout equal to price)
buyer.call("deposit",
    deposit=buyer.pay_txn(wapp.address, 100000)
)

### 3. Payment
buyer.call("pay", flat_fee=2000)

### 4. Refund
# seller.call("refund", flat_fee=2000)

print("total cost:", wapp.total_fees)
