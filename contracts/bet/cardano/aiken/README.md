# Bet Contract in Aiken

## Overview

The Bet contract involves two players and an oracle. The two players join the contract by depositing 1 token unit each in the contract, specifing an oracle and setting a deadline. The oracle is expected to determine the winner
between the two players. The winner can redeem the complessive amount of the bet. If the oracle does not choose the winner by the deadline,
then both players can withdraw their individual bets.

This is the contract implementation in [Aiken](https://aiken-lang.org/), a functional programming language for writing validators in Cardano.

<!-- -->

## Validator

Compared to other blockchain platforms and protocols, smart contracts in Cardano are mere **validators**. These scripts attached to the UTXOs represent the actual output's spending conditions. These scripts are in fact executed by the Cardano network when a transaction attempts to spend an UTXO with an attached validator.

Before analyzing the validation logic, it's worth recalling what datum and redeemer are.

### Datum

Validators have access to an additional section of data payload attached to UTXOs called *datum*, typically used to record the current state of the contract.

In our case, the datum contains the addresses of the players and of the oracle, and the deadline (a UNIX timestamp):

<!-- ml because, like Aiken, it is a functional language -->
```ml 
type Datum {
    oracle: VerificationKeyHash,
    player_1: VerificationKeyHash,
    player_2: VerificationKeyHash,
    deadline: POSIXTime
}
```

### Redeemer

When spending an output locked by a script, the transaction includes an additional payload, called **redeemer**, which can be used by the validator to verify the output's spending condition.
For example, if the spending condition requires to provide a preimage to a given hash, this preimage will likely be contained in the redeemer field.

In Cardano's [extended UTxO](https://docs.cardano.org/learn/eutxo-explainer/) model, the redeemer can contain *arbitrary data*, as long as it is supported by the underlying Plutus Core layer. 

In our Bet contract, we define the ```Redeemer``` type as the sum between three types corresponding to the three different **actions** supported by the contract.
```ml 
type Redeemer {
    Join
    Win { winner: VerificationKeyHash }
    Timeout
}
```

### Main logic 

The overall structure of the validator is the following: 
<!-- scala because it allows to highlight comment and types -->
```scala
validator {
    fn bet(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) {
        
        {
            // Preprocessing (retrieving values)
        }

        when ctx.purpose is {
            Spend(_) ->{
                when redeemer is {
                    Join -> {
                        // Join logic  
                    }
                    
                    Win(winner) -> {
                        // Win logic
                    }

                    Timeout -> {
                        // Timeout logic
                    }
                }
                _ -> False
            }
        }
    }
}
```

The ```bet``` function is declared under a ```validator``` block. This means that the function must return a boolean value representing whether the transaction is valid or not.
Inside this function, we perform a pattern matching on the ```ctx.purpose``` value representing the kind of script being executed. We accept as valid only spending transaction (ignoring then minting transactions and similar): in fact, if the purpose is not ```Spend```, the validator returns ```False```.

As mentioned [before](#redeemer), to discriminate between the three different actions, another pattern matching construct is applied to the ```redeemer``` value.   

#### Preprocessing

As a preprocessing step we retrieve all the values common to the three actions; in this case, we are retrieving the balance of the contract.
To this purpose we exploit a [custom library](./utils.ak) that simplifies accessing parts of the transaction: 
```ml
let own_input = utils.get_own_input(ctx)
let contract_address = own_input.output.address

let contract_outputs = utils.get_outputs_by_address(tx.outputs, contract_address)
let contract_inputs = utils.get_inputs_by_address(tx.inputs, contract_address) 

let contract_inputs_lovelace_balance = utils.get_ada_from_inputs(contract_inputs)
let contract_outputs_lovelace_balance = utils.get_ada_from_outputs(contract_outputs)

let contract_inputs_token_balance = utils.get_tokens_balance_from_inputs(contract_inputs)
let contract_outputs_token_balance = utils.get_tokens_balance_from_outputs(contract_outputs)
```

#### Join

In order to preserve the covenant, we require that there is only one output associated to the contract.
```ml
expect True = list.length(contract_outputs) == 1
expect Some(contract_output) = list.at(contract_outputs, 0)
```

We also retrieve the two signers identifying them as the two players:

```ml
expect Some(player_1) = list.at(tx.extra_signatories, 0)
expect Some(player_2) = list.at(tx.extra_signatories, 1)
```

Since we've got the two addresses, we can compute the token balances (w.r.t. the transaction's inputs and outputs) of the two actors:

```ml
let player_1_inputs_token_balance = utils.get_tokens_balance_from_inputs(utils.get_inputs_by_vkh(tx.inputs, player_1))
let player_1_outputs_token_balance = utils.get_tokens_balance_from_outputs(utils.get_outputs_by_vkh(tx.outputs, player_1))

let player_2_inputs_token_balance = utils.get_tokens_balance_from_inputs(utils.get_inputs_by_vkh(tx.inputs, player_2))
let player_2_outputs_token_balance = utils.get_tokens_balance_from_outputs(utils.get_outputs_by_vkh(tx.outputs, player_2))
```

The following boolean ```and``` block performs all the checks regarding the ```Join``` action: its value is also the value returned by the validator, because this block is the last instruction the function executes in this scope. 

We start by checking that, before this ```Join``` action, the contract had been created and initialized with an *empty datum* and, in the other check, that it does not contain any value related to the bet token:
<!-- C++ just to highlight syntax in Markdown... -->
```c++
and{
    datum == Datum {
        oracle: "",
        player_1: "", 
        player_2: "",
        deadline: 0
    },

    contract_inputs_token_balance == 0,

    // other checks
}
```
Then, we check that, in the transaction we're validating, the contract will receive **two token units** and both players are paying **one unit each**: 
```c++
and{
    // other checks

    // Players are depositing 2 tokens inside the contract 
    contract_outputs_token_balance ==  2,

    // Players are paying 1 token each:
    player_1_outputs_token_balance == player_1_inputs_token_balance - 1, 
    player_2_outputs_token_balance == player_2_inputs_token_balance - 1,

    // other checks
}
```
We then add a condition that checks if the two signers have updated the new datum (i.e. the new contract state, retrieved by the output associated to the contract) by assigning themselves as the two players. 
Finally we check that the two players are choosing a valid deadline:
```c++
and{
    // other checks

    // New datum must update the two players based on the tx's signers
    contract_output_datum.player_1 == player_1,
    contract_output_datum.player_2 == player_2,

    contract_output_datum.deadline > tx_earliest_time
}
```

#### Win

For this action, the oracle has to choose a winner between the two players. This is the reason why the oracle can add an additional parameter to the redeemer in the ```Win``` action.
When checking the redeemer, we are also retrieving the ```winner``` parameter that comes with the redeemer: 
```c++
Win(winner) -> {
    // Win logic
}
```
The only preprocessing we are doing here is retrieving this transaction signer: 
```ml
expect Some(tx_signer) = list.at(tx.extra_signatories, 0)
```
Similarly to the [Join action](#join), we put all the conditions in an ```and``` block.

First, we check that the signer is equal to the oracle specified in the datum, and that the input UTxO contains 2 tokens paid by the players:
```c++
and{
    // Only the oracle can perform this action
    tx_signer == datum.oracle,

    // The Contract must have been paid by players (i.e. players must have joined the contract)
    contract_inputs_token_balance == 2,

    // other checks
}
```
The validator also inspects the transaction timestamp and, in the inner ```or``` block, it requires a winner to be choosen between the two players appearing in the datum. 
```c++
and {
    // other checks

    // Oracle can choose the winner only before the deadline
    datum.deadline > tx_earliest_time,

    // oracle has to choose a winner among the two players 
    or { // more like a XOR
        winner == datum.player_1,
        winner == datum.player_2
    },

    // other checks
}
```
Finally, we require that the winner's address is the one receiving the two tokens in one of the transaction's outputs:

```c++
// other checks

and {
    // Winner must receive the tokens
    utils.get_tokens_balance_from_outputs(utils.get_outputs_by_vkh(tx.outputs, winner)) == 2
}
```    

#### Timeout

For the ```Timeout``` action, we retrieve the two signers and their token balances.
```ml
// Get the two transaction's signers
expect Some(player_1) = list.at(tx.extra_signatories, 0)
expect Some(player_2) = list.at(tx.extra_signatories, 1)

// Players' token balances:
let player_1_inputs_token_balance = utils.get_tokens_balance_from_inputs(utils.get_inputs_by_vkh(tx.inputs, player_1))
let player_1_outputs_token_balance = utils.get_tokens_balance_from_outputs(utils.get_outputs_by_vkh(tx.outputs, player_1))

let player_2_inputs_token_balance = utils.get_tokens_balance_from_inputs(utils.get_inputs_by_vkh(tx.inputs, player_2))
let player_2_outputs_token_balance = utils.get_tokens_balance_from_outputs(utils.get_outputs_by_vkh(tx.outputs, player_2))
``` 
In the ```and``` block, we check that the two signers coincide with the players specified in the datum:
```c++
and {
    // Transaction has the correct signers
    player_1 == datum.player_1,
    player_2 == datum.player_2,

    // other checks
}
``` 
We perform the usual timestamp check. Since the timeout can be performed **only if** the deadline has expired, the transaction timestamp must be greater than the deadline.
```c++
and {
    // other checks

     // Timeout action can be performed only after the deadline
    datum.deadline < tx_earliest_time,

    // other checks
}
```
To be a valid timeout, the players must have joined the contract **previously**. The establish this, we can check the balance of the input associated with the contract: if it has 2 tokens, we can say the two players had performed the Join action:
```c++
and {
    // other checks

    // Players must have joined contract previously (this means contract has 2 tokens)
    contract_inputs_token_balance == 2,

    // other checks
}
``` 
Finally, we transfer 1 token to each player. To do that, we check that the output balance of each players is equal to its input balance increased by 1 (we can safely perform this check because in Cardano, tokens **cannot be** used to pay transaction fees):
```c++
and {
    // other checks

    // Players are receiving 1 token each
    player_1_outputs_token_balance == player_1_inputs_token_balance + 1,
    player_2_outputs_token_balance == player_2_inputs_token_balance + 1
}
``` 

<!-- 
The offchain section has been removed. 
The original is still available here: https://github.com/strausste/aiken-contracts/tree/main/oracle-bet-v2 
-->

<!-- 
The offchain section has been removed. 
The original is still available here: https://github.com/strausste/aiken-contracts/tree/main/oracle-bet-v2 
-->