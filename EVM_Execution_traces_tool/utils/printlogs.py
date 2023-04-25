
def print_receipt(tx_receipt):
    print('contractAddress =', tx_receipt["contractAddress"])
    print('cumulativeGasUsed =', tx_receipt['cumulativeGasUsed'])
    #print('gasPrice Mainet =', gasprice)
    #print('effectiveGasPrice =', tx_receipt['effectiveGasPrice'])
    print('gasUsed =', tx_receipt['gasUsed'])
    #print('COST(USD) =', gasprice*tx_receipt['gasUsed']*etherPrice.getEtherPrice()*(10**-9))

