from utils.execution_flow import *
from utils import etherPrice, network

# USE CASE: ESCROW
# two accounts for this use case: buyer and seller
# network can set to .truffle, .sepolia (Ethereum), .mordor(Ethereum classic), or .avalancheFuji
chainID,w3,a_buyer,a_seller = network.avalancheFuji()

### SET THE COINPRICE and the GASPRICE
gasprice = 25 # etherPrice.getGasPrice("baseFee")  # GWei
coinPrice = 18.04 # etherPrice.getEtherPrice()
print("gasprice: ",gasprice, " - CoinPrice: ", coinPrice)

# cost lists
totalcost=[]
totalgas=[]

# 1. ESCROW: Set price and deploy
price = int(0.001 * 10**18)
#### Deploy ####
print("--- Deploy ---")
contract_address, contract = deploy(w3, coinPrice, "Escrow", a_buyer, chainID, gasprice, totalcost,totalgas, price)
###  Set buyer and seller addresses in the SC
print("--- set buyer ---")
msg_execution(w3, coinPrice, contract,"setBuyer", a_buyer, chainID,gasprice, totalcost,totalgas)
print("--- set seller ---")
msg_execution(w3, coinPrice, contract,"setSeller", a_seller, chainID,gasprice, totalcost,totalgas)

### 2. send money (the buyer deposits the amout equal to price)
print("--- send value: price ---")
msg_transaction(w3, coinPrice, a_buyer, contract_address, price, chainID,gasprice, totalcost,totalgas)

### 3. Shipping (The seller ships the goods and sends the "shipped" message)
print("--- shipping ---")
msg_execution(w3, coinPrice, contract, "shipped", a_seller, chainID,gasprice, totalcost,totalgas)

### 4. Payment (The buyer receives the goods and triggers the payment)
print("--- payment ---")
msg_execution(w3, coinPrice, contract, "payment", a_buyer, chainID,gasprice, totalcost,totalgas)

####### total costs #####

print("........")
print("total gas: ",sum(totalgas))
print("total cost: ",sum(totalcost))