from wrapper import Env
from contracts.factory import app as appf
from contracts.product import app as appp

env = Env()

wappf = env.wapp(appf)
userf = wappf.fetch_client()


#print(userp.create(
#    owner_ = userp.pk,
#    tag_ = "Some tag",
#))
#exit()
userf.create()

tag1 = "A very very very long tag"
p1 = userf.call("create_product", flat_fee=2000,
    deposit=userf.pay_txn(wappf.address, 300000),
    tag=tag1,
).return_value
wappp1 = env.wapp(appp, p1)
userp1 = wappp1.get_client(userf)
#assert userp1.drycall("get_tag").return_value == tag1

tag2 = "A shorter tag"
p2 = userf.call("create_product", flat_fee=2000,
    deposit=userf.pay_txn(wappf.address, 300000),
    tag=tag2,
).return_value
wappp2 = env.wapp(appp, p2)
userp2 = wappp2.get_client(userf)
# assert userp2.drycall("get_tag").return_value == tag2

print("total cost:", env.total_fees)
