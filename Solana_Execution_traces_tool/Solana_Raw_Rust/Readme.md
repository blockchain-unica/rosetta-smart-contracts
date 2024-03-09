
# Solana Execution Traces Tool with Raw Rust

Welcome to the Solana Cost Analysis Tool! This tool is designed for analyzing and understanding the costs associated with transactions and smart contract execution on the [Solana blockchain](https://solana.com) using the [Rust programming language](https://www.rust-lang.org/).

<a name="dependences_anchor"></a>
## Pre-requisites

You will need [Solana Tools](https://docs.solana.com/cli/install-solana-cli-tools) to compile the source files, deploy and generate your own File System Wallet Keypair. In the following sections we will explain in detail how to use Solana Tools to do these operations.

In addition, for cost analysis it will be necessary to run the off chain code via npm, so you will need [Node.js and npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm).

So before proceeding you should be able to run the following commands:

```sh
$ solana --version
$ cargo --version
$ node -v
```

<a name="getting_started_anchor"></a>
## Getting Started

Generete your own File System Wallet Keypair (in case you don't have one).
```sh
$ solana-keygen new
```

Connect to the Testnet cluster:
```sh
$ solana config set --url testnet
```

For subsequent operations as deployment and other transactions you will need to have a certain amount of SOL. You can request a free SOL airdrop to your new wallet by running:
```sh
$ solana airdrop 5
```

Then you can see if the airdrop operation was successful by checking your balance:
```sh
$ solana balance
```

To get your wallet address:
```sh
$ solana address 	
```

Afterwards you can install packages and their dependencies by running:
```sh
$ npm install
```

## Costs Analysis

Now you can compile the source code of a contract, deploy it on the blockchain and run our fee analysis.

Transactions can be tracked using different explorers like:
- [Explorer | Solana](https://explorer.solana.com/?cluster=testnet)
- [Solscan](https://solscan.io/?cluster=testnet)

Make sure you select the right cluster. In our examples we use the Testnet.

In the following example `<SMART_CONTRACT_NAME>` stands for a contract chosen by the user and could be one of the following:

1. [simple_transfer](../../contracts/simple_transfer)
1. [token_transfer](../../contracts/token_transfer)
1. [htlc](../../contracts/htlc)
1. [escrow](../../contracts/escrow)
1. [auction](../../contracts/auction)
1. [crowdfund](../../contracts/crowdfund)
1. [vault](../../contracts/vault)
1. [vesting](../../contracts/vesting)
1. [storage](../../contracts/storage)
1. [simple_wallet](../../contracts/simple_wallet)
1. [tinyamm](../../contracts/tinyamm)
1. [payment_splitter](../../contracts/payment_splitter)
1. [oracle_bet](../../contracts/oracle_bet)

Now we can compile and deploy the on chain program:
```sh
$ npm run build:<SMART_CONTRACT_NAME>
```
```sh
$ npm run deploy:<SMART_CONTRACT_NAME>
```
At the end of the deployment the program id of the contract should be displayed.

Now we can run the off chain script to see the execution costs.
```sh
$ npm run costs:<SMART_CONTRACT_NAME> 
```