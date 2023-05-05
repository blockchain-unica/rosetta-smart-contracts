
This tool allows to run traces for various smart contracts in the Solana Blockchain in order to perform a cost analysis.

## Requirements

You will need [Solana Tools](https://docs.solana.com/cli/install-solana-cli-tools) to compile the source files, deploy and generate your own File System Wallet Keypair. In the following sections we will explain in detail how to use Solana Tools to do these operations.

For cost analysis, however, it will be necessary to run the off chain code via npm, so you will need to install [Node.js and npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm).

## Initial Configurations

Generete your own File System Wallet Keypair (in case you don't have one).
```sh
$ solana-keygen new
```

Connect to the Testnet cluster:
```sh
$ solana config set --url https://api.testnet.solana.com
```

For subsequent operatios as deployment and other transactions you will need to have a certain amount of SOL. You can request a free SOL airdrop to your new wallet.
```sh
$ solana airdrop 5
```

Then you can see if the airdrop operation was successful by checking your balance 
by running:
```sh
$ solana balance
```

The address can be obtained with:
```sh
$ solana address 	
```

Afterwards you can install packages and their dependencies by running:
```sh
$ npm install
```

## Cost Analysis

Now you can compile the source code of a contract, deploy it on the blockchain and run our fee analysis.

Transactions can be tracked using different software such as:
- [Explorer | Solana](https://explorer.solana.com/?cluster=testnet)
- [Solscan](https://solscan.io/?cluster=testnet)

Make sure you select the right cluster. In our examples we use the Testnet.

In the following example `<SMART_CONTRACT_NAME>` stands for a contract chosen by the user and could be one of the following
- simple_transfer
- htlc
- token_transfer
- vault

Now we can compile and deploy the on chain program. 
```sh
$ npm run build:<SMART_CONTRACT_NAME>
```
```sh
$ npm run deploy:<SMART_CONTRACT_NAME>
```
At the end of the dolpoyment the program id of the contract should be displayed.

Now we can run the off chain script to see the execution costs.
```sh
$ npm run costs:<SMART_CONTRACT_NAME> 
```