from wrapper import WApp
from contracts.vault import app

wapp = WApp(app)

owner = wapp.fetch_client()
recovery = wapp.fetch_client()

owner.create(
    recovery_  = recovery.pk,
    wait_time_ = 2,
)

owner.pay(wapp.address, 300000)

owner.call("withdraw",
    amount_   = 100000,
    receiver_ = owner.pk
)

wapp.wait_rounds(2)

owner.call("finalize", flat_fee=2000)

owner.call("withdraw",
    amount_   = 100000,
    receiver_ = owner.pk
)

### 3. Payment
recovery.call("cancel")

print("total cost:", wapp.total_fees)
