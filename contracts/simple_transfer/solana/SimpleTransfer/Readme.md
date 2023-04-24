Below we show how, after a quick initial configuration, you can perform the various steps, 
both for the on-chain program and the client to allow a user to deposit native 
cryptocurrency in the contract, and another user (the recipient) to withdraw.

## Initial Configurations

Connecting to the cluster:
```sh
$ solana config set --url https://api.testnet.solana.com
```

Create a simple file system wallet for testing (in case you don't have one). 
This will serve as the keypair for the partecipant who intends to contribute a certain amount of SOL.
```sh
$ solana-keygen new
```

For subsequent operatios as deployment and other transactions you will need to have a certain amount of SOL.
```sh
$ solana airdrop 2
```

Check your balance with:
```sh
$ solana balance
```

The addresses can be obtained with:
```sh
$ solana address 	
```

Install packages and their dependencies.
```sh
$ npm install
```

## Building
Now we can compile and deploy the on chain program. 
For <SMART_CONTRACT_NAME> you can choose between 'htlc' and 'simpletransfer'.

```sh
$ npm run build:<SMART_CONTRACT_NAME>
$ npm run deploy:<SMART_CONTRACT_NAME>
```

## Usage
Now we can run the off chain script to see the execution costs.

```sh
$ npm run costs:<SMART_CONTRACT_NAME> 
```

This is an example of the output for simpletransfer:
```
owner:      7dwC8ZsLoEuo3xVSRwapn1TftCxNC4G6ffEPqVXin2gZ
recipient:  DW8amadXu6SVecDeh6KYnNMsYuZjUc4ruT2REUHstfM9

--- Deploy. Actor: the owner ---
programId:  WhbuBzD6yMkkLw3k8nW3k2aUfHq9CJc8rMPdKEyc8Ci

--- Deposit. Actor: the onwer ---
Rent fees:         0.001392  SOL
Transaction fees:  0.000005  SOL
Transaction fees:  0.000005  SOL
Transaction fees:  0.000005  SOL

--- Partial Whitdraw. Actor: the recipient ---
Transaction fees:  0.000005  SOL

--- Total Whitdraw. Actor: the recipient ---
Transaction fees:  0.000005  SOL

........
Total fees for deployment:               0  SOL
Total fees for sender (including rent):  0.001407  SOL
Total fees for recipient:                0.00001  SOL
Total fees:                              0.001417  SOL
```