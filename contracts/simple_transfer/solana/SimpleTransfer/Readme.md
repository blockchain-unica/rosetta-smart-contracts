Below we show how, after a quick initial configuration, you can perform the various steps, 
both for the on-chain program and the client to allow a user to deposit native 
cryptocurrency in the contract, and another user (the recipient) to withdraw.

## Initial Configurations

Connecting to the cluster:
```sh
$ solana config set --url https://api.devnet.solana.com
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

Create a simple file system wallet for the of the donation receiver.
```sh
$ solana-keygen new -o keypair-receiver.json
```

The addresses of the two participants can be obtained with:
```sh
$ solana address 	
$ solana address -k keypair-receiver.json
```

Install packages and their dependencies.
```sh
$ npm install
```

## Building and Deloyment
Now we can compile the on chain program and deploy it to your currently selected cluster by running:

```sh
$ npm run build:program-rust
```

```sh
$ npm run deploy:program-rust
```
After successfully deploying and confirming the transaction, the command 
will display the public address of the program.

## Usage
Now we can run the off chain program scripts.

To deposit native cryptocurrency in the contract.
```sh
$ npm run deposit
```

The output should be:
```
Using account 7dwC8ZsLoEuo3xVSRwapn1TftCxNC4G6ffEPqVXin2gZ containing 499999997.90750116 SOL
On chain program address: 5hzcBTd59nktZ1aUzVegDSF1SWThN4nufTM5KCmbxEsr
---------------------
Ammount in lamports:  500000000
Receiver address:     DW8amadXu6SVecDeh6KYnNMsYuZjUc4ruT2REUHstfM9
---------------------
```

Then another user (the receiver) can withdraw part or all the amount.
```sh
$ npm run withdraw
```

The output shoul be:
```
Using account DW8amadXu6SVecDeh6KYnNMsYuZjUc4ruT2REUHstfM9 containing 0.60280856 SOL
On chain program address: FLW5Cmy8Y5xjYW3kaWL8kNxG5ArjSdnReSWU6C8F5cM
Now the receiver account has 0.70280356 SOL
```
