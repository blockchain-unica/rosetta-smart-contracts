from wrapper import WApp
from contracts.vesting import app
from algosdk.atomic_transaction_composer import AtomicTransactionComposer

wapp = WApp(app)

owner = wapp.fetch_client()
beneficiary = wapp.fetch_client()

start = wapp.curr_round()+1

owner.create()
owner.call("init",
    beneficiary_ = beneficiary.pk,
    start_ =  start,
    duration_ = 10,
    deposit = owner.pay_txn(wapp.address, 200000)
)

wapp.wait_rounds_from(start, 3)
#print(beneficiary.drycall("releasable").return_value)
beneficiary.call("release", flat_fee=2000)


wapp.wait_rounds_from(start, 7)
#print(beneficiary.drycall("releasable").return_value)
beneficiary.call("release", flat_fee=2000)

wapp.wait_rounds_from(start, 10)
#print(beneficiary.drycall("releasable").return_value)
beneficiary.call("release", flat_fee=2000)

print("total cost:", wapp.total_fees)
