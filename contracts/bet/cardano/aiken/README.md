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

When spending an output locked by a script, the transaction includes an **additional payload** called *redeemer*.
These data can be used by the validator to verify and fulfill the output's spending conditions.
For example, if the spending condition of an output is: "the redeeming address is allowed to spend this output only if they provide a preimage to a given hash", a well written contract will allow the user to pass the preimage through the redeemer field and it will check it.  
In the Cardano [extended UTxO](https://docs.cardano.org/learn/eutxo-explainer/) model, redeemers contain *arbitrary data* (as long as it is supported by the underlying Plutus Core layer). 

In our Bet contract, the ```Redeemer``` is a sum between three different types corresponding to the three different **actions** allowed by the contract.

```ml 
type Redeemer {
    Join
    Win { winner: VerificationKeyHash }
    Timeout
}
```

### Main logic 

The validator's main **structure** is the following: 

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

The ```bet``` function is declared under a ```validator``` block. This means, the function must return a **boolean value** representing wether the transaction is valid or not. \
Inside this function, we perform a *pattern matching* on the ```ctx.purpose``` value representing the kind of script being executed. We accept as valid only spending transaction (ignoring then minting transactions and similar): in fact, if the purpose is not ```Spend```, the validator returns ```False```. \
As mentioned [before](#redeemer), to discriminate between the three different "actions", another pattern matching construct is applied to the ```redeemer``` value.   

#### Preprocessing

A *preprocessing* step is required to retrieve all the values common to the three actions; in this case, we're retrieving the balance of the contract. \
All the functions in the following code snippet, are not part of the Aiken language or its standard library, they come instead from a [custom library](./utils.ak) written by us. 

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

In order to **preserve covenant**, we require that there is only one output associated to the contract.

```ml
expect True = list.length(contract_outputs) == 1
expect Some(contract_output) = list.at(contract_outputs, 0)
```

We also retrieve the two signers identifying them as the two players, making sure they have two different addresses:

```ml
expect Some(player_1) = list.at(tx.extra_signatories, 0)
expect Some(player_2) = list.at(tx.extra_signatories, 1)

expect True = player_1 != player_2
```

Since we've got the two addresses, we can compute the token balances (w.r.t. the transaction's inputs and outputs) of the two actors:

```ml
let player_1_inputs_token_balance = utils.get_tokens_balance_from_inputs(utils.get_inputs_by_vkh(tx.inputs, player_1))
let player_1_outputs_token_balance = utils.get_tokens_balance_from_outputs(utils.get_outputs_by_vkh(tx.outputs, player_1))

let player_2_inputs_token_balance = utils.get_tokens_balance_from_inputs(utils.get_inputs_by_vkh(tx.inputs, player_2))
let player_2_outputs_token_balance = utils.get_tokens_balance_from_outputs(utils.get_outputs_by_vkh(tx.outputs, player_2))
```

A boolean ```and``` block is declared to perform all the checks regarding the ```Join``` action: its value is also the value returned by the validator, because this block is the **last instruction** the function executes in this scope. 

We check that, before this ```Join``` action, the contract had been created and initialized with an *empty datum* and, in the other reported check, it does not contain any value related to the bet token:

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

then, we check the *"economics" conditions* related to the bet: we've to check that, in this transaction we're validating, the contract will receive **two token units** and both players are paying **one unit each**: 

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

we add a condition that checks if the two signers have updated the new datum (i.e. the new contract state, retrieved by the output associated to the contract) by assigning themselves as the two players:

```c++
and{
    // other checks

    // New datum must update the two players based on the tx's signers
    contract_output_datum.player_1 == player_1,
    contract_output_datum.player_2 == player_2,

    // other checks
}
```

finally, and similarly, we check that the two players are choosing a valid oracle and a valid deadline: 

```c++
and{
    // other checks

    // Players must design an oracle but oracle cannot be player_1 or player_2
    contract_output_datum.oracle != contract_output_datum.player_1,
    contract_output_datum.oracle != contract_output_datum.player_2,

    // Players are choosing a correct deadline
    contract_output_datum.deadline > tx_earliest_time
}
```


#### Win

When the redeemer is ```Win```, the oracle has to choose a winner between the two players, this is the reason why the oracle can add an **additional parameter** to the redeemer in the ```Win``` action. \
When checking the redeemer, we are also retrieving the ```winner``` parameter that comes with the redeemer: 

```c++
Win(winner) -> {
    // Win logic
}
```

the only preprocessing we're doing here is retrieving this transaction's signer: 

```ml
expect Some(tx_signer) = list.at(tx.extra_signatories, 0)
```

as we've done for the [```Join```](#join), we put all the conditions in an ```and``` block. \
Firstly, the validator requires the signer to be equal to the oracle specified in the datum and it checks that the input UTxO contains 2 tokens paid by the players:

```c++
and{
    // Only oracle can perform this action
    tx_signer == datum.oracle,

    // Contract must have been payed by players (i.e. players must've joined the contract)
    contract_inputs_token_balance == 2,

    // other checks
}
```

the validator also inspects the transaction's timestamp and, in the inner ```or``` block, it requires a winner to be choosen between the two players appearing in the datum. 

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
and {
    // Winner must receive the tokens
    utils.get_tokens_balance_from_outputs(utils.get_outputs_by_vkh(tx.outputs, winner)) == 2
}
```    

#### Timeout

Regarding the ```Timeout``` action, we retrieve the two signers and their token balances.

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

In the ```and``` block, we have to check that those two signers are the actual players specified in the datum:

```c++
and {
    // Transaction has the correct signers
    player_1 == datum.player_1,
    player_2 == datum.player_2,

    // other checks
}
``` 

we perform the usual timestamp check. Since the timeout can be performed **only if** the deadline has expired, the transaction's timestamp must be greater than the deadline.

```c++
and {
    // other checks

     // Timeout action can be performed only after the deadline
    datum.deadline < tx_earliest_time,

    // other checks
}
``` 

To be a valid timeout, the players must have joined the contract **previously**. The establish this, we can check the balance of the input associated with the contract: if it has 2 tokens, we can say the two players had performed the ```Join``` action:

```c++
and {
    // other checks

    // Players must have joined contract previously (this means contract has 2 tokens)
    contract_inputs_token_balance == 2,

    // other checks
}
``` 

finally, a valid timeout has to return 1 token **to each player**. So, we check that the respective output balance of the two players has increased by 1 than their inputs (we can safely perform this check because in Cardano, tokens **cannot be** used to pay transaction fees):

```c++
and {
    // other checks

    // Players are receiving 1 token each
    player_1_outputs_token_balance == player_1_inputs_token_balance + 1,
    player_2_outputs_token_balance == player_2_inputs_token_balance + 1

    // other checks
}
``` 

<!-- 
The offchain section has been removed. 
The original is still aviable here: https://github.com/strausste/aiken-contracts/tree/main/oracle-bet-v2 
-->
