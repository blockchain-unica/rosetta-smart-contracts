
# Solana Execution Traces Tool

Welcome to the Solana Cost Analysis Tool! This tool is designed for analyzing and understanding the costs associated with transactions and smart contract execution on the [Solana blockchain](https://solana.com).

## Contents

- [Prereqs](#prereqs_anchor)
- [Initial Configurations](#initial_configurations_anchor)
- [Costs Analysis](#costs_analysis_anchor)
- [How to add a use case](#add_use_case_anchor)
- [Differences respect to solidity](#differences_anchor)

<a name="prereqs_anchor"></a>
## Prereqs

You will need [Solana Tools](https://docs.solana.com/cli/install-solana-cli-tools) to compile the source files, deploy and generate your own File System Wallet Keypair. In the following sections we will explain in detail how to use Solana Tools to do these operations.

In addition, for cost analysis it will be necessary to run the off chain code via npm, so you will need [Node.js and npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm).

So before proceeding you should be able to run the following commands:

```sh
$ solana --version
$ cargo --version
$ node -v
```

<a name="initial_configurations_anchor"></a>
## Initial Configurations

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

<a name="costs_analysis_anchor"></a>
## Costs Analysis

Now you can compile the source code of a contract, deploy it on the blockchain and run our fee analysis.

Transactions can be tracked using different explorers like:
- [Explorer | Solana](https://explorer.solana.com/?cluster=testnet)
- [Solscan](https://solscan.io/?cluster=testnet)

Make sure you select the right cluster. In our examples we use the Testnet.

In the following example `<SMART_CONTRACT_NAME>` stands for a contract chosen by the user and could be one of the following:

1. [simple_transfer](../contracts/simple_transfer)
1. [token_transfer](../contracts/token_transfer)
1. [htlc](../contracts/htlc)
1. [escrow](../contracts/escrow)
1. [auction](../contracts/auction)
1. [crowdfund](../contracts/crowdfund)
1. [vault](../contracts/vault)
1. [vesting](../contracts/vesting)
1. [storage](../contracts/storage)
1. [simple_wallet](../contracts/simple_wallet)

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

<a name="add_use_case_anchor"></a>
## How to add a use case

    .
    ├── contracts                   
    │   ├── new_use_case             
    │   │   ├── Cargo.toml           
    │   │   ├── src                  
    │   │   │   ├── lib.rs           # On chain logic
    └── execution_traces
        ├── new_use_case_flow.ts     # Off chain logic

To add a new use case to those already present, you can use the following command:

```sh
$ npm run add <SMART_CONTRACT_NAME>
```

After execution, the folder `<SMART_CONTRACT_NAME>` will be created for the on-chain program and the `<SMART_CONTRACT_NAME>_flow.ts` file for the off-chain program. These files will already be initialized with a basic structure for the user's convenience.

Then the `"scripts"` section of the `package.json` should be updated for greater convenience in development by adding the following lines and replacing `<SMART_CONTRACT_NAME>` with the name of the new use case.

```sh
"build:<SMART_CONTRACT_NAME>": "cargo build-bpf --manifest-path=./contracts/<SMART_CONTRACT_NAME>/Cargo.toml --bpf-out-dir=contracts/dist/<SMART_CONTRACT_NAME>",

"deploy:<SMART_CONTRACT_NAME>": "solana program deploy contracts/dist/<SMART_CONTRACT_NAME>/<SMART_CONTRACT_NAME>.so",

"costs:<SMART_CONTRACT_NAME>": "ts-node execution_traces/<SMART_CONTRACT_NAME>_flow.ts",

"clean:<SMART_CONTRACT_NAME>": "cargo clean --manifest-path=./contracts/<SMART_CONTRACT_NAME>/Cargo.toml && rm -rf ./contracts/dist/<SMART_CONTRACT_NAME>"
```

At the end you will be able to build, deploy and run cost analysis for the new contract exactly as described in the section [Costs Analysis](#costs_analysis_anchor).

<a name="differences_anchor"></a>
## Differences respect to solidity

Since Solana follows a very different paradigm compared to the EVM compatible blockchains, small changes have been introduced in the developed contracts compared to those developed in Solidity.

### Initialization
A brief observation is that Solana does not offer the option to initialize data at the time of deployment. As a result, we are unable to simply build up data using a constructor because we lack one. This indicates that one function was introduced in some use cases. 

Despite this challenge, in some other cases a way was found to maintain a one to one mapping with contracts written in Solidity. 

In the Solidity implementation of the following contracts some data is initialized at the time of deployment. 
For instance, HTLC requires initialization of the owner, the verifier, the hash, and the reveal timeout at the time of deployment.
- [HTLC](../contracts/htlc)
- [Escrow](../contracts/escrow)
- [Vault](../contracts/vault)
- [Vesting](../contracts/vesting)
- [Crowdfund](../contracts/crowdfund)

After the contract has been deployed in Solana, a transaction should be issued to initialize those data. After this initialization, the actors can interact with the contract by carrying out the same operations as they would with Solidity-written contracts.

### Other differences
The [Auction](../contracts/auction) contract in the implementation for Solana stores only the highest bidder. The previous bidders are not stored because the Solana contract sends the money back to the previous bidder in the same transaction in which the new bid is made.  


### Contracts with less differences
An implementation that is nearly identical to Solidity's has been found for the contracts listed below.
- [Token Transfer](../contracts/token_transfer)
- [Simple Transfer](../contracts/simple_transfer)
- [Storage](../contracts/storage)
- [Simple Wallet](../contracts/simple_wallet)