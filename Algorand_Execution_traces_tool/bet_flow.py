from wrapper import WApp
from algosdk.transaction import OnComplete
from contracts.bet import app

###################################

wapp = WApp(app)

player1 = wapp.fetch_client()
player2 = wapp.fetch_client()
oracle = wapp.fetch_client()

player1.create()

player1.call("join1",
    txn=player1.pay_txn(wapp.address, 200000),
    oracle_=oracle.pk,
    opponent_=player2.pk,
    timeout_=10,
)

player2.call("join2",
    txn=player1.pay_txn(wapp.address, 200000),
)

oracle.call("win", on_complete=OnComplete.DeleteApplicationOC,
    winner=player2.pk,    
    flat_fee=2000
)

print("total cost:", wapp.total_fees)

###################################

wapp = WApp(app)

player1 = wapp.fetch_client()
player2 = wapp.fetch_client()
oracle = wapp.fetch_client()

player1.create()

player1.call("join1",
    txn=player1.pay_txn(wapp.address, 200000),
    oracle_=oracle.pk,
    opponent_=player2.pk,
    timeout_=10,
)

rnd = wapp.curr_round()

player2.call("join2",
    txn=player1.pay_txn(wapp.address, 200000),
)

wapp.wait_rounds_from(rnd, 15)

player2.call("timeout", on_complete=OnComplete.DeleteApplicationOC,
    flat_fee=3000,
    _owner=player1.pk,
    _opponent=player2.pk,
)

print("total cost:", wapp.total_fees)
