from utils.execution_flow import *

# network.sepolia() to run on the testnet
gasprice = etherPrice.getGasPrice("baseFee")  # GWei

print("gasprice: ",gasprice)

# cost list
totalcost=[]
totalgas=[]

# USE CASE: ESCROW

# two accounts for this use case: buyer and seller
# network can set to truffle or sepolia
chainID,w3,a_buyer,a_seller = network.truffle() #network.sepolia()

# 1. ESCROW: Set price and deploy
price = int(0.001 * 10**18)
#### Deploy ####
print("--- Deploy ---")
contract_address, contract = deploy(w3, "Escrow", a_buyer, chainID, gasprice, totalcost,totalgas, price)
###  Set buyer and seller addresses in the SC
print("--- set buyer ---")
msg_execution(w3,contract,"setBuyer", a_buyer, chainID,gasprice, totalcost,totalgas)
print("--- set seller ---")
msg_execution(w3,contract,"setSeller", a_seller, chainID,gasprice, totalcost,totalgas)

### 2. send money (the buyer deposits the amout equal to price)
print("--- send value: price ---")
msg_transaction(w3, a_buyer, contract_address, price, chainID,gasprice, totalcost,totalgas)

### 3. Shipping (The seller ships the goods and sends the "shipped" message)
print("--- shipping ---")
msg_execution(w3, contract, "shipped", a_seller, chainID,gasprice, totalcost,totalgas)

### 4. Payment (The buyer receives the goods and triggers the payment)
print("--- payment ---")
msg_execution(w3, contract, "payment", a_buyer, chainID,gasprice, totalcost,totalgas)

####### total costs #####

print("........")
print("total gas: ",sum(totalgas))
print("total cost: ",sum(totalcost))