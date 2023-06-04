from wrapper import WApp
from contracts.storage import app

wappf = WApp(app)
user = wappf.fetch_client()

user.create()
user.call("store",
    number_=42
)

#res = user.drycall("retrieve").return_value
#assert res == 42

print("total cost:", wappf.total_fees)
