from wrapper import WApp
from contracts.upgradable_proxy import app

wapp = WApp(app)

owner = wapp.fetch_client()
user = wapp.fetch_client()

owner.create()

owner.update()

print("total cost:", wapp.total_fees)
