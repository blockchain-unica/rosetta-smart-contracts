import web3
from web3 import Web3

# network configuration
def truffle():
    chainID = 1337
    w3 = Web3(Web3.HTTPProvider('http://127.0.0.1:9545/'))
    pk_account1 = "bc0acc845ed3dd70256b132a818e1851bf04a0b87e439232e1b67c0c75e328bc"
    pk_account2 = "1e358391118f91d81491d549b324c679836ef58d9b1ebecaebed08b623379386"
    account1 = w3.eth.account.from_key(pk_account1)
    account2 = w3.eth.account.from_key(pk_account2)
    return chainID,w3,account1,account2

def sepolia():
    chainID= 11155111 #Sepolia Ethereum PoS testnet
    w3 = Web3(Web3.HTTPProvider('https://rpc.sepolia.org/'))
    pk_account1 = "90c8549ae45449bc204a43ff23b60096579f0ae34da3cf6f0cbd2ff2452b8d20"
    pk_account2 = "6a56b69e3307f1d6351eb74346aa4e429d22817975ac3353156f0ce95cc2f3bc"
    account1 = w3.eth.account.from_key(pk_account1)
    account2 = w3.eth.account.from_key(pk_account2)
    return chainID, w3, account1, account2


def mordor():
    chainID= 63 #Mordor: Ethereum classic PoW testnet
    w3 = Web3(Web3.HTTPProvider('https://geth-mordor.etc-network.info'))#https://www.ethercluster.com/mordor'))
    pk_account1 = "90c8549ae45449bc204a43ff23b60096579f0ae34da3cf6f0cbd2ff2452b8d20"
    pk_account2 = "6a56b69e3307f1d6351eb74346aa4e429d22817975ac3353156f0ce95cc2f3bc"
    account1 = w3.eth.account.from_key(pk_account1)
    account2 = w3.eth.account.from_key(pk_account2)
    return chainID, w3, account1, account2



def avalancheFuji():
    chainID = 43113
    w3 =Web3(web3.HTTPProvider('https://api.avax-test.network/ext/bc/C/rpc'))
    pk_account1 = "90c8549ae45449bc204a43ff23b60096579f0ae34da3cf6f0cbd2ff2452b8d20"
    pk_account2 = "6a56b69e3307f1d6351eb74346aa4e429d22817975ac3353156f0ce95cc2f3bc"
    account1 = w3.eth.account.from_key(pk_account1)
    account2 = w3.eth.account.from_key(pk_account2)
    return chainID, w3, account1, account2


def hederaTest():
    chainID = 296
    w3 = Web3(web3.HTTPProvider('https://testnet.hashio.io/api'))
    # TODO: create testnet accounts
    #pk_account1 = ""
    #pk_account2 = ""
    #account1 = w3.eth.account.from_key(pk_account1)
    #account2 = w3.eth.account.from_key(pk_account2)
    #return chainID, w3, account1, account2

# Accounts
#pk_buyer = "90c8549ae45449bc204a43ff23b60096579f0ae34da3cf6f0cbd2ff2452b8d20"
#pk_seller="6a56b69e3307f1d6351eb74346aa4e429d22817975ac3353156f0ce95cc2f3bc"

#account truffle
#pk_buyer = "bc0acc845ed3dd70256b132a818e1851bf04a0b87e439232e1b67c0c75e328bc"
#pk_seller = "1e358391118f91d81491d549b324c679836ef58d9b1ebecaebed08b623379386"

#chainID, w3, account1, account2 = mordor()
#print(w3.eth.gas_price)