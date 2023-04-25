from utils.execution_flow import *
from utils import etherPrice, network

# USE CASE: HTLC
# two accounts for this use case: a commiter (the owner) and a receiver
# network can set to .truffle, .sepolia (Ethereum), .mordor(Ethereum classic), or .avalancheFuji
chainID,w3,committer,receiver = network.truffle()

### SET THE COINPRICE and the GASPRICE
# set the value of coinPrice = commiter, receiver
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

# TRACE 1
#### Deploy ####
print("TRACE 1")
print("--- Deploy. Actor: the commiter ---")
deposit =int(0.006*10**18)
deadline = 10
startRound= w3.eth.get_block_number()
#Web3.solidity_keccak(['uint8', 'uint8', 'uint8'], [97, 98, 99])
messageHash = w3.solidity_keccak(['string'],["solution"])
print("Message hash:", messageHash)
contract_address, contract = deploy(chain_cost_data, "HTLC", committer, deposit, receiver.address, messageHash, deadline)
print("Start block:", w3.eth.get_block_number())

### 2. REVEAL After N rounds
N = 2
print("--- Reveal. Actor: the owner ---")
currentRound = w3.eth.get_block_number()
while currentRound != N + startRound:
    newRound = w3.eth.get_block_number()
    if newRound!= currentRound:
        currentRound= newRound
        print("Current block:", w3.eth.get_block_number())
textString ="solution"
msg_execution(chain_cost_data,contract, "reveal", committer, 0, textString)


# TRACE 2
#### Deploy ####
print("## TRACE 2 ##")
print("--- Deploy. Actor: the commiter ---")
deposit =int(0.006*10**18)
deadline = 5
startRound= w3.eth.get_block_number()
messageHash = w3.solidity_keccak(['string'],["solution"])
print(messageHash)
contract_address, contract = deploy(chain_cost_data, "HTLC", committer, deposit, receiver.address, messageHash, deadline)
print("Start block:", w3.eth.get_block_number())

### 2. call "Timeout"  After Deadline+1 rounds
print("--- timeout. Actor: the receiver ---")
currentRound = w3.eth.get_block_number()
while currentRound < deadline + 1 + startRound:
    newRound = w3.eth.get_block_number()
    if newRound != currentRound:
        currentRound = newRound
        print("Current block:", w3.eth.get_block_number())
msg_execution(chain_cost_data,contract, "timeout", committer, 0)


####### total costs #####

print("........")
print("total gas: ",sum(totalgas))
print("total cost: ",sum(totalcost))