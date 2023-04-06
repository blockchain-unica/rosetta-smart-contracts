import urllib.request
import ast
import json

def getEtherPrice():
    contents = urllib.request.urlopen("https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD").read()
    dict_str = contents.decode("UTF-8")
    mydata = ast.literal_eval(dict_str)
    return mydata["USD"]

def getGasPrice(type):
    contents = urllib.request.urlopen("https://api.gasprice.io/v1/estimates?countervalue=USD")
    mydata = json.loads(contents.read().decode("UTF-8"))
    return mydata["result"][type]
