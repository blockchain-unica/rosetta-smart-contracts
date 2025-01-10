// Suggested stdlib version: 1.7.0 (https://github.com/aiken-lang/stdlib/releases/tag/1.7.0)

// ////////////////////////////////////////////////////////////////////////////////
// Imports:
// ////////////////////////////////////////////////////////////////////////////////

use aiken/list

use aiken/transaction.{ScriptContext, Spend, InlineDatum}

use aiken/interval.{Finite}

// use aiken/cbor // diagnostic

use bet/utils.{VerificationKeyHash, POSIXTime}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Types: 
// ////////////////////////////////////////////////////////////////////////////////

type Datum {
    oracle: VerificationKeyHash,
    player_1: VerificationKeyHash,
    player_2: VerificationKeyHash,
    deadline: POSIXTime
}

type Redeemer {
    Join                                     // player_1 and player_2 join the contract
    Win { winner: VerificationKeyHash }      // oracle chooses the winner
    Timeout                                  // oracle hasn't choose winner before timeout
}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Validator:
// ////////////////////////////////////////////////////////////////////////////////


validator {
    fn bet(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) {
        let tx = ctx.transaction

        let tx_earliest_time =
			when tx.validity_range.lower_bound.bound_type is {
				Finite(x) -> x
				_ -> 0
			}

        // Contract
        let own_input = utils.get_own_input(ctx)
        let contract_address = own_input.output.address
        
        let contract_outputs = utils.get_outputs_by_address(tx.outputs, contract_address)
        let contract_inputs = utils.get_inputs_by_address(tx.inputs, contract_address) 

        let contract_inputs_lovelace_balance = utils.get_ada_from_inputs(contract_inputs)
        let contract_outputs_lovelace_balance = utils.get_ada_from_outputs(contract_outputs)

        let contract_inputs_token_balance = utils.get_tokens_balance_from_inputs(contract_inputs)
        let contract_outputs_token_balance = utils.get_tokens_balance_from_outputs(contract_outputs)

        when ctx.purpose is {
            Spend(_) -> {
                // No ADA must be taken away from this contract: tokens only
                expect True = contract_outputs_lovelace_balance == contract_inputs_lovelace_balance

                when redeemer is {
                    Join -> {
                        // Contract must have only one output
                        expect True = list.length(contract_outputs) == 1
                        expect Some(contract_output) = list.at(contract_outputs, 0)

                        // Getting the output's datum
                        expect InlineDatum(untyped_datum) = contract_output.datum
                        expect contract_output_datum: Datum = untyped_datum

                        let empty_datum = Datum {
                            oracle: "",
                            player_1: "", 
                            player_2: "",
                            deadline: 0
                        }

                        // Get the two transaction's signers
                        expect Some(player_1) = list.at(tx.extra_signatories, 0)
                        expect Some(player_2) = list.at(tx.extra_signatories, 1)

                        // Players' token balances:
                        let player_1_inputs_token_balance = utils.get_tokens_balance_from_inputs(utils.get_inputs_by_vkh(tx.inputs, player_1))
                        let player_1_outputs_token_balance = utils.get_tokens_balance_from_outputs(utils.get_outputs_by_vkh(tx.outputs, player_1))

                        let player_2_inputs_token_balance = utils.get_tokens_balance_from_inputs(utils.get_inputs_by_vkh(tx.inputs, player_2))
                        let player_2_outputs_token_balance = utils.get_tokens_balance_from_outputs(utils.get_outputs_by_vkh(tx.outputs, player_2))


                        and {
                            // Contract has been created with an empty datum, hence players are correctly joining an empty contract
                            datum == empty_datum,

                            contract_inputs_token_balance == 0,

                            // Players are depositing 2 tokens inside the contract 
                            contract_outputs_token_balance ==  2,
                            
                            // Players are paying 1 token each:
                            player_1_outputs_token_balance == player_1_inputs_token_balance - 1, 
                            player_2_outputs_token_balance == player_2_inputs_token_balance - 1,

                            // New datum must update the two players based on the tx's signers
                            contract_output_datum.player_1 == player_1,
                            contract_output_datum.player_2 == player_2,

                            // Players are choosing a correct deadline
                            contract_output_datum.deadline > tx_earliest_time, 
                        }
                    }

                    Win(winner) -> {
                        expect Some(tx_signer) = list.at(tx.extra_signatories, 0)

                        and {
                            // Only oracle can perform this action
                            tx_signer == datum.oracle,

                            // Contract must have been payed by players (i.e. players must have joined the contract)
                            contract_inputs_token_balance == 2,

                            // Oracle can choose the winner only before the deadline
                            datum.deadline > tx_earliest_time,

                            // oracle has to choose a winner among the two players 
                            or { // more like a XOR
                                winner == datum.player_1,
                                winner == datum.player_2
                            },

                            // Winner must receive the tokens
                            utils.get_tokens_balance_from_outputs(utils.get_outputs_by_vkh(tx.outputs, winner)) == 2
                        }
                    }

                    Timeout -> {
                        // Get the two transaction's signers
                        expect Some(player_1) = list.at(tx.extra_signatories, 0)
                        expect Some(player_2) = list.at(tx.extra_signatories, 1)
                
                        // Players' token balances:
                        let player_1_inputs_token_balance = utils.get_tokens_balance_from_inputs(utils.get_inputs_by_vkh(tx.inputs, player_1))
                        let player_1_outputs_token_balance = utils.get_tokens_balance_from_outputs(utils.get_outputs_by_vkh(tx.outputs, player_1))

                        let player_2_inputs_token_balance = utils.get_tokens_balance_from_inputs(utils.get_inputs_by_vkh(tx.inputs, player_2))
                        let player_2_outputs_token_balance = utils.get_tokens_balance_from_outputs(utils.get_outputs_by_vkh(tx.outputs, player_2))

                        and {
                            // Transaction has the correct signers
                            player_1 == datum.player_1,
                            player_2 == datum.player_2,
                        
                            // Timeout action can be performed only after the deadline
                            datum.deadline < tx_earliest_time,

                            // Players must have joined contract previously (this means contract has 2 tokens)
                            contract_inputs_token_balance == 2,
                            
                            // Players are receiving 1 token each
                            player_1_outputs_token_balance == player_1_inputs_token_balance + 1,
                            player_2_outputs_token_balance == player_2_inputs_token_balance + 1
                        }
                    }
                }
            }
            _ -> False
        }
    }
}

// ////////////////////////////////////////////////////////////////////////////////