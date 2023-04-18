from utils.execution_flow import *
from utils import etherPrice, network

# USE CASE: ESCROW
# two accounts for this use case: buyer and seller
# network can set to .truffle, .sepolia (Ethereum), .mordor(Ethereum classic), or .avalancheFuji
chainID,w3,a_buyer,a_seller = network.truffle()

### SET THE COINPRICE and the GASPRICE
gasprice = etherPrice.getGasPrice("baseFee")  # GWei
coinPrice = etherPrice.getEtherPrice()
print("network ID:", w3.net.version)
print("gasprice: ",gasprice, " - CoinPrice: ", coinPrice)

# cost lists
totalcost=[]
totalgas=[]
chain_cost_data = [w3,coinPrice, chainID,gasprice, totalcost,totalgas]

# 1. ESCROW: Set price and deploy
price = int(0.001 * 10**18)
#### Deploy ####
print("--- Deploy. Actor: the seller ---")
contract_address, contract = deploy(chain_cost_data, "Escrow",a_seller, price, a_buyer.address, a_seller.address)

### 2. Deposit money (the buyer deposits the amout equal to price)
print("--- Deposit. Actor: the buyer ---")
msg_execution(chain_cost_data,contract, "deposit", a_buyer, price )

### 3. Payment
print("--- Pay. Actor: the buyer ---")
msg_execution(chain_cost_data, contract, "pay", a_buyer,0)


### 4. Refund
#print("--- Refund. Actor: the seller ---")
#msg_execution(chain_cost_data, contract, "refund", a_seller,0)

####### total costs #####

print("........")
print("total gas: ",sum(totalgas))
print("total cost: ",sum(totalcost))