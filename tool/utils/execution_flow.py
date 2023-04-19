from EVM_transactions import deployer, messages
from utils.printlogs import print_receipt


def current_nonce(address,w3):
    """Returns the current nonce for a given address
    and given web3 instance"""
    return w3.eth.get_transaction_count(address)

def msg_execution(chain_cost_data, contract, function, account, value, *params):
    w3 = chain_cost_data[0]
    coinPrice = chain_cost_data[1]
    chainID = chain_cost_data[2]
    gasprice = chain_cost_data[3]
    totalcost = chain_cost_data[4]
    totalgas = chain_cost_data[5]
    """Executes a contract function, saves and prints the cost.
    This function calls the function function_call of the module messages
    Arguments:
        w3 - web3 instance
        coinPrice - the price in USD of the coin (ETH, ETC, AVAX, ... )
        contract - smart contract address string
        function - name of the sc function
        account - web3 account object who sends the message
        chainID - chain ID of the network
        gasprice - gasprice for the transaction in base unit (i.e. wei)
        totalcost,totalgas - lists where the cost will be saved
        *params - arguments for the smart contract function
    """
    tx_receipt = messages.function_call(w3, contract, function, account, chainID, current_nonce(account.address,w3), value, *params)
    # cost = gasprice * tx_receipt['gasUsed'] * coinPrice * (10 ** -9)
    cost = gasprice * tx_receipt['gasUsed'] * coinPrice
    totalcost.append(cost)
    totalgas.append(tx_receipt['gasUsed'])
    print_receipt(tx_receipt)
    print("cost: ", cost)


def msg_transaction(chain_cost_data, account, destination, value):
    w3 = chain_cost_data[0]
    coinPrice = chain_cost_data[1]
    chainID = chain_cost_data[2]
    gasprice = chain_cost_data[3]
    totalcost = chain_cost_data[4]
    totalgas = chain_cost_data[5]
    """Executes a simple value transaction, saves and prints the cost.
    This function calls the function send_value of the module messages
    Arguments:
        w3 - web3 instance
        coinPrice - the price in USD of the coin (ETH, ETC, AVAX, ... )
        function - name of the sc function
        account - web3 account object who sends the message
        destination - destination address
        value - the value of the transaction
        chainID - chain ID of the network
        gasprice - gasprice for the transaction in base unit (i.e. wei)
        totalcost,totalgas - lists where the cost will be saved
    """
    tx_receipt = messages.send_value(w3, account, destination, value, chainID, current_nonce(account.address,w3))
    cost = gasprice * tx_receipt['gasUsed'] * coinPrice
    totalcost.append(cost)
    totalgas.append(tx_receipt['gasUsed'])
    print_receipt(tx_receipt)
    print("cost: ", cost)


def deploy(chain_cost_data,contractInfo, account, *contract_args):
    w3 = chain_cost_data[0]
    coinPrice= chain_cost_data[1]
    chainID= chain_cost_data[2]
    gasprice=  chain_cost_data[3]
    totalcost = chain_cost_data[4]
    totalgas = chain_cost_data[5]
    """Executes the deploy of a contract, saves and prints the cost.
    This function calls the function deploy in the deployer module
    Arguments:
        w3 - web3 instance
        coinPrice - the price in USD of the coin (ETH, ETC, AVAX, ... )
        contractName - string with the name of the solidity source code without the extention
        account - web3 account object who sends the message
        chainID - chain ID of the network
        gasprice - gasprice for the transaction in base unit (i.e. wei)
        totalcost,totalgas - lists where the cost will be saved
        *args - arguments for the contract constructor
    """
    tx_receipt, contract = deployer.deploy_sc(w3, contractInfo, account, chainID, current_nonce(account.address,w3), *contract_args)
    contract_address = tx_receipt["contractAddress"]
    totalgas.append(tx_receipt['gasUsed'])
    cost = gasprice * tx_receipt['gasUsed'] * coinPrice
    totalcost.append(cost)
    print_receipt(tx_receipt)
    print("cost: ", cost)
    return contract_address,contract

