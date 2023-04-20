from utils.execution_flow import *
from utils import etherPrice, network

# USE CASE: token transfer
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

#### SETUP ####
#### 1 Deploy the token ####
print("--- Deploy the token. Actor: the owner ---")
token_contract_address, tokenContract = deploy(chain_cost_data, ["token_transfer","TheToken"],owner)

### 2. Mint token
print("--- Mint. Actor: the onwer ---")
amount = 100
msg_execution(chain_cost_data,tokenContract, "mint", owner, 0, owner.address, amount)


### 3. Deploy the TokenTransfer contract
print("--- Deploy the tokenTransfer. Actor: the owner ---")
contract_address, tokenTransferContract = deploy(chain_cost_data, ["token_transfer","TokenTransfer"],owner, 0, recipient.address, token_contract_address)

### 4. Approval
print("--- Apoval. Actor: the onwer ---")
amount = 100
msg_execution(chain_cost_data,tokenContract, "approve", owner,0, contract_address, amount)

### 5. Deposit token (the user trasfer token to the contract)
print("--- Deposit. Actor: the onwer ---")
amount = 100
msg_execution(chain_cost_data,tokenTransferContract, "deposit", owner,0, amount)

### 6. Partial Withdraw
print("--- Partial Withdraw. Actor: the recipient ---")
amount = 50
msg_execution(chain_cost_data,tokenTransferContract, "withdraw", recipient,0, amount)

### 6. total Withdraw
print("--- Partial Withdraw. Actor: the recipient ---")
amount = 100
msg_execution(chain_cost_data,tokenTransferContract, "withdraw", recipient,0, amount)


####### total costs #####

print("........")
print("total gas: ",sum(totalgas))
print("total cost: ",sum(totalcost))