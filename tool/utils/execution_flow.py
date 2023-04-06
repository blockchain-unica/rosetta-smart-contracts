from EVM_transactions import deployer, messages
from utils import etherPrice, network
from utils.printlogs import print_receipt


def current_nonce(address,w3):
    return w3.eth.get_transaction_count(address)


def msg_execution(w3, contract, function, account, chainID, gasprice, totalcost,totalgas, *params):
    tx_receipt = messages.function_call(w3, contract, function, account, chainID, current_nonce(account.address,w3),*params)
    cost = gasprice * tx_receipt['gasUsed'] * etherPrice.getEtherPrice() * (10 ** -9)
    totalcost.append(cost)
    totalgas.append(tx_receipt['gasUsed'])
    print_receipt(tx_receipt)
    print("cost USD: ", cost)


def msg_transaction(w3, account, contract_address, value, chainID,gasprice, totalcost,totalgas,):
    tx_receipt = messages.send_value(w3, account, contract_address, value, chainID, current_nonce(account.address,w3))
    cost = gasprice * tx_receipt['gasUsed'] * etherPrice.getEtherPrice() * (10 ** -9)
    totalcost.append(cost)
    totalgas.append(tx_receipt['gasUsed'])
    print_receipt(tx_receipt)
    print("cost USD: ", cost)


def deploy(w3, contractName, account, chainID,gasprice, totalcost,totalgas, *args):
    tx_receipt, contract = deployer.deploy_sc(w3, contractName, account, chainID, current_nonce(account.address,w3), *args)
    contract_address = tx_receipt["contractAddress"]
    totalgas.append(tx_receipt['gasUsed'])
    cost = gasprice * tx_receipt['gasUsed'] * etherPrice.getEtherPrice() * (10 ** -9)
    totalcost.append(cost)
    print_receipt(tx_receipt)
    print("cost USD: ", cost)
    return contract_address,contract

