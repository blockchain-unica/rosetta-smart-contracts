from EVM_transactions import compiler
from web3 import Web3

def deploy_sc(w3,contractInfo,account, value, chainID,nonce, *params):
    """Function to deploy a smart contract form source code
    The function compile the source code via the compile
    function in the compiler module.

    Arguments:
        w3 - web3 instance
        sc_name - the smart contract filename without extention
        *params - arguments for the constructor
    """
    priv_key = account.key
    address = account.address
    # contract (name of the file without extention)
    abi, bytecode = compiler.compile(contractInfo)
    contract = w3.eth.contract(abi=abi, bytecode=bytecode)
    # creation of the tx. Docs: https://web3py.readthedocs.io/en/stable/web3.contract.html
    transaction = contract.constructor(*params).build_transaction(
            {"chainId": chainID,
             "from": address,
             "nonce": nonce,
             'gasPrice' : w3.eth.gas_price,
             "value": value,
             })

    #transaction.update({ 'nonce' : w3.eth.get_transaction_count('Your_Wallet_Address') })
    signed_tx = w3.eth.account.sign_transaction(transaction, priv_key)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
    tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    contract = w3.eth.contract(address=tx_receipt["contractAddress"], abi=abi)
    return tx_receipt, contract




if __name__ == "__main__":
    #DEMO
    # network configuration
    chainID= 11155111 #Sepolia
    w3 = Web3(Web3.HTTPProvider('https://rpc.sepolia.org/'))

    # deployer account
    priv_key="90c8549ae45449bc204a43ff23b60096579f0ae34da3cf6f0cbd2ff2452b8d20"
    account=w3.eth.account.from_key(priv_key)
    nonce = w3.eth.get_transaction_count(account.address)

    tx_receipt = deploy_sc("Storage",account,chainID,nonce)

    print(tx_receipt)
    print('contractAddress =', tx_receipt["contractAddress"])
    print('cumulativeGasUsed =', tx_receipt['cumulativeGasUsed'])
    print('effectiveGasPrice =', tx_receipt['effectiveGasPrice'])
    print('gasUsed =', tx_receipt['gasUsed'])



