from utils.execution_flow import *
from utils import etherPrice, network

# USE CASE: Simple transfer
# two accounts for this use case: the onwer(user) and the recipient
# network can set to .truffle, .sepolia (Ethereum), .mordor(Ethereum classic), or .avalancheFuji
chainID,w3,owner,recipient = network.truffle()

### SET THE COINPRICE and the GASPRICE
# set the value of coinPrice =
#   etherPrice.getEtherPrice() * 10**-18 to have the cost in USD
#   10**-18 to have the cost in ether
#
coinPrice = 10**-18 # cost in Ether
gasprice = etherPrice.getGasPrice("baseFee")*(10**9)  # the method returns GWei

print("network ID:", w3.net.version)
print("gasprice: ",gasprice, " - CoinPrice: ", coinPrice)

# cost lists
totalcost=[]
totalgas=[]
chain_cost_data = [w3,coinPrice, chainID,gasprice, totalcost,totalgas]

# 1. Set recipient and deploy

#### Deploy ####
print("--- Deploy. Actor: the owner ---")
contract_address, contract = deploy(chain_cost_data, "simple_transfer",owner, recipient.address)

### 2. Deposit money (the user deposits the amout equal to price)
print("--- Deposit. Actor: the onwer ---")
amount = int(0.01*(10**18))
msg_execution(chain_cost_data,contract, "deposit", owner, amount )

### 3. partial Whitdraw
print("--- Partial Whitdraw. Actor: the recipient ---")
withdraw_amount = int(amount/2)
msg_execution(chain_cost_data, contract, "withdraw", recipient,0,withdraw_amount)

### 4. total Whitdraw
print("--- Total Whitdraw. Actor: the recipient ---")
withdraw_amount = amount
msg_execution(chain_cost_data, contract, "withdraw", recipient,0,withdraw_amount)


####### total costs #####

print("........")
print("total gas: ",sum(totalgas))
print("total cost: ",sum(totalcost))