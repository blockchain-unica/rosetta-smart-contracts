#from EVM_transactions import compiler
#from web3 import Web3
#w3 = Web3(Web3.HTTPProvider('https://rpc.sepolia.org/'))

import asyncio
# function_call accept

def function_call(w3,contract,function,account,chainID,nonce, *params):
    """Returns the receipt of a transaction that involves the
    smart contract calling.

    The function calls the method "function" passed as a string,
    create a raw transaction ans signs it via the account passed
    as an argument
    """
    transaction = getattr(contract.functions,function)(*params).build_transaction(
        {"chainId": chainID,
         "from": account.address,
         'gasPrice' : w3.eth.gas_price,
         "nonce": nonce})
    #transaction = contract.functions.function(10).build_transaction({"chainId": chainID, "from": account.address, "nonce": nonce(account.address)})
    signed_tx = w3.eth.account.sign_transaction(transaction, account.key)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
    tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    return tx_receipt


def send_value(w3,account, to_address, value, chainID, nonce, *vals):
    """Returns the receipt of a value transaction from the account
    to to_addres.

    The function creates a raw transaction and signs it via the a
    account passed as an argument
    """
    transaction = {
        'to': to_address,
        'value': value,
        'gas': 2000000,
        'gasPrice': w3.eth.gas_price,
        #'maxFeePerGas': 2000000000,
        #'maxPriorityFeePerGas': 1000000000,
        'nonce': nonce,
        'chainId': chainID
    }
    signed = w3.eth.account.sign_transaction(transaction, account.key)
    #print(signed)
    tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)
    tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    return tx_receipt






