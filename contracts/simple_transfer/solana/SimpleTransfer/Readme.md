## Initial Configurations

Connecting to the cluster:
```
solana config set --url https://api.devnet.solana.com
```

Create a simple file system wallet for testing if you don't have one. 
This will serve as the keypair for the partecipant who intends to contribute a certain amount of SOL.
```
solana-keygen new
```

For subsequent operatios as deployment and other transactions you will need to have a certain amount of SOL.
```
solana airdrop 1
```

Check your balance with:
```
solana balance
```

Create a simple file system wallet for the of the donation recipient.
```
solana-keygen new -o keypair-receiver.json
```

The addresses of the two participants can be obtained with:
```
solana address 	
solana address -k keypair-receiver.json
```

Install packages and their dependencies.
```
npm install
```

## Building and Deloyment
Now we can compile the on chain program and deploy it to your currently selected cluster by running:

```
npm run build:program-rust
```

```
npm run deploy:program-rust
```
After successfully deploying and confirming the transaction, the command 
will display the public address of the program.


## Usage
Now we can run the off chain program scripts.

To deposit native cryptocurrency in the contract.
```
npm run donate
```

The output shoul be:
```
Using account 7dwC8ZsLoEuo3xVSRwapn1TftCxNC4G6ffEPqVXin2gZ containing 499999997.90750116 SOL
On chain program address: 5hzcBTd59nktZ1aUzVegDSF1SWThN4nufTM5KCmbxEsr
---------------------
Ammount in lamports:  500000000
Receiver address:     DW8amadXu6SVecDeh6KYnNMsYuZjUc4ruT2REUHstfM9
---------------------
```

Then another user (the recipient) can withdraw the amount.
```
npm run withdraw
```

The output shoul be:
```
On chain program address: 5hzcBTd59nktZ1aUzVegDSF1SWThN4nufTM5KCmbxEsr
Now the receiver account  (DW8amadXu6SVecDeh6KYnNMsYuZjUc4ruT2REUHstfM9) has 0.50281356 SOL
```
