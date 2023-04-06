from EVM_transactions import deployer, messages
from utils import etherPrice, network
from utils.printlogs import print_receipt


def current_nonce(address,w3):
    """Returns the current nonce for a given address
    and given web3 instance"""
    return w3.eth.get_transaction_count(address)

def msg_execution(w3, contract, function, account, chainID, gasprice, totalcost,totalgas, *params):
    """Executes a contract function, saves and prints the cost.
    This function calls the function function_call of the module messages
    Arguments:
        w3 - web3 instance
        contract - smart contract address string
        function - name of the sc function
        account - web3 account object who sends the message
        chainID - chain ID of the network
        gasprice - gasprice for the transaction
        totalcost,totalgas - lists where the cost will be saved
        *params - arguments for the smart contract function
    """
    tx_receipt = messages.function_call(w3, contract, function, account, chainID, current_nonce(account.address,w3),*params)
    cost = gasprice * tx_receipt['gasUsed'] * etherPrice.getEtherPrice() * (10 ** -9)
    totalcost.append(cost)
    totalgas.append(tx_receipt['gasUsed'])
    print_receipt(tx_receipt)
    print("cost USD: ", cost)


def msg_transaction(w3, account, destination, value, chainID, gasprice, totalcost,totalgas,):
    """Executes a simple value transaction, saves and prints the cost.
    This function calls the function send_value of the module messages
    Arguments:
        w3 - web3 instance
        function - name of the sc function
        account - web3 account object who sends the message
        destination - destination address
        value - the value of the transaction
        chainID - chain ID of the network
        gasprice - gasprice for the transaction
        totalcost,totalgas - lists where the cost will be saved
    """
    tx_receipt = messages.send_value(w3, account, destination, value, chainID, current_nonce(account.address,w3))
    cost = gasprice * tx_receipt['gasUsed'] * etherPrice.getEtherPrice() * (10 ** -9)
    totalcost.append(cost)
    totalgas.append(tx_receipt['gasUsed'])
    print_receipt(tx_receipt)
    print("cost USD: ", cost)


def deploy(w3, contractName, account, chainID,gasprice, totalcost,totalgas, *args):
    """Executes the deploy of a contract, saves and prints the cost.
    This function calls the function deploy in the deployer module
    Arguments:
        w3 - web3 instance
        contractName - string with the name of the solidity source code without the extention
        account - web3 account object who sends the message
        chainID - chain ID of the network
        gasprice - gasprice for the transaction
        totalcost,totalgas - lists where the cost will be saved
        *args - arguments for the contract constructor
    """
    tx_receipt, contract = deployer.deploy_sc(w3, contractName, account, chainID, current_nonce(account.address,w3), *args)
    contract_address = tx_receipt["contractAddress"]
    totalgas.append(tx_receipt['gasUsed'])
    cost = gasprice * tx_receipt['gasUsed'] * etherPrice.getEtherPrice() * (10 ** -9)
    totalcost.append(cost)
    print_receipt(tx_receipt)
    print("cost USD: ", cost)
    return contract_address,contract

