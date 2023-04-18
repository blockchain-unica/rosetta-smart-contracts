from utils.execution_flow import *
from utils import etherPrice, network

# USE CASE: Simple Wallet
# two accounts for this use case: the owner and a recipient
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

print("owner balance: ", w3.eth.get_balance(owner.address))
print("recipient balance: ", w3.eth.get_balance(recipient.address))

# 1. wallet: Set an amount to deposit
#### 1. initialization  ####
print("--- Deploy ---")
contract_address, contract = deploy(chain_cost_data, "simple_wallet", owner, owner.address)

### 2. Deposit money
print("--- Deposit. Actor: the owner ---")
deposit = int(0.001 * 10**18)
msg_execution(chain_cost_data,contract, "deposit", owner, deposit)

### 3. Create transaction
print("--- Creation TX. Actor: the owner ---")
#data = contract.encodeABI(fn_name="functionName", args=["anArg", 10])
value = 10**20 #int(deposit/2)
msg_execution(chain_cost_data,contract, "createTransaction", owner, 0, recipient.address, value,"0x00" )

### 4. execute transaction
print("--- Execution. Actor: the owner ---")
id = 0
msg_execution(chain_cost_data,contract, "executeTransaction", owner, 0, id )

### 5. withdraw
print("--- Withdraw. Actor: the owner ---")
msg_execution(chain_cost_data,contract, "withdraw", owner, 0 )

####### total costs #####

print("........")
print("total gas: ",sum(totalgas))
print("total cost USD: ",sum(totalcost))

print("owner balance: ", w3.eth.get_balance(owner.address))
print("recipient balance: ", w3.eth.get_balance(recipient.address))
