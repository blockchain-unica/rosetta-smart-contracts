import urllib.request
import ast
import json

def getEtherPrice():
    """Return the value current price for one Ether in USD as from cryptocompare"""
    contents = urllib.request.urlopen("https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD").read()
    dict_str = contents.decode("UTF-8")
    mydata = ast.literal_eval(dict_str)
    return mydata["USD"]

def getGasPrice(type):
    """Return the current gasprice in GWei, by using the gasprice.io API.
    Argument:
    type = instant, fast, eco, basefee, ethPrice
    """
    contents = urllib.request.urlopen("https://api.gasprice.io/v1/estimates?countervalue=USD")
    mydata = json.loads(contents.read().decode("UTF-8"))
    value = mydata["result"][type]
    if type in ['baseFee','ethPrice']:
        return value
    else:
        return value["feeCap"]

