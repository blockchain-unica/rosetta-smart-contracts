import solcx
import os
#solcx.install_solc('0.8.18')
#PROJECT_ROOT = os.path.dirname(os.path.dirname(__file__))
#print(os.path.join(PROJECT_ROOT,"smart-contracts-cost-analysis/example.sol"))

def compile(contractFile):
    """Return ABI and Bytecode of a solidity file
    present in the folder /solidity of this project"""

    #contractName= "Escrow" #without extention
    contractName = contractFile
    with open("solidity/"+contractName+".sol","r") as sc_file:
        sc = ''
        lines = sc_file.readlines()
        for line in lines:
            sc = sc+line
    #print(sc)
    contract_id, contract_interface = solcx.compile_source(sc, output_values=['abi', 'bin']).popitem()
    #result = solcx.compile_source(sc,output_values=["abi", "bin-runtime"], solc_version="0.8.18")
    #print(result)
    #print(result)
    #abi = result['<stdin>:'+contractName]['abi']
    #bin_runtime= result['<stdin>:'+contractName]['bin-runtime']
    abi = contract_interface['abi']
    bytecode = contract_interface['bin']
    return (abi, bytecode)
    #return(abi,bin_runtime)
    #print(result['<stdin>:SaveValue']['abi'])
    #print(result['<stdin>:SaveValue']['bin-runtime'])

def saveAbi(contractFile):
    abi,bin = compile(contractFile)
    contractName = contractFile
    with open(contractName+".abi","w") as write_abi:
        write_abi.write(str(abi))
