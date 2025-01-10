// Suggested stdlib version: 1.7.0 (https://github.com/aiken-lang/stdlib/releases/tag/1.7.0)

// ////////////////////////////////////////////////////////////////////////////////
// Imports:
// ////////////////////////////////////////////////////////////////////////////////

use aiken/list

use aiken/transaction.{ScriptContext, Spend, InlineDatum}
use aiken/transaction/value

use aiken/interval.{Finite}

// use aiken/cbor // diagnostic

use bet/utils.{VerificationKeyHash, POSIXTime, Lovelace}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Types: 
// ////////////////////////////////////////////////////////////////////////////////

type Datum {
    oracle: VerificationKeyHash,
    wager: Lovelace,
    player_1: VerificationKeyHash,
    player_2: VerificationKeyHash,
    deadline: POSIXTime,
    is_joined: Bool
}

type Redeemer {
    Join { wager: Lovelace }
    Win { winner: VerificationKeyHash }
    Timeout
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

        let contract_inputs_balance = utils.get_ada_from_inputs(contract_inputs)
        let contract_outputs_balance = utils.get_ada_from_outputs(contract_outputs)

        when ctx.purpose is {
            Spend(_) -> {
                when redeemer is {
                    Join(wager) -> {
                        // Contract must have only one output
                        expect True = list.length(contract_outputs) == 1
                        expect Some(contract_output) = list.at(contract_outputs, 0)

                        // Getting the output's datum
                        expect InlineDatum(untyped_datum) = contract_output.datum
                        expect contract_output_datum: Datum = untyped_datum

                        // Get the two transaction's signers
                        expect Some(player_1) = list.at(tx.extra_signatories, 0)
                        expect Some(player_2) = list.at(tx.extra_signatories, 1)

                        // Players balances
                        let player_1_inputs_balance = utils.get_ada_from_inputs(utils.get_inputs_by_vkh(tx.inputs, player_1))
                        let player_1_outputs_balance = utils.get_ada_from_outputs(utils.get_outputs_by_vkh(tx.outputs, player_1))

                        let player_2_inputs_balance = utils.get_ada_from_inputs(utils.get_inputs_by_vkh(tx.inputs, player_2))
                        let player_2_outputs_balance = utils.get_ada_from_outputs(utils.get_outputs_by_vkh(tx.outputs, player_2))

                        and {
                            // Players are joining the contract before the deadline
                            datum.deadline > tx_earliest_time,

                            // Players are declaring and paying the correct wager (i.e. amount players are sending to the contract minus the initialization amount)
                            contract_outputs_balance - contract_inputs_balance == wager * 2,

                            // The wager value must be inserted in the datum
                            contract_output_datum.wager == wager,

                            // Players are joining an empty contract and they are updating the next state accordingly
                            !datum.is_joined && contract_output_datum.is_joined,

                            // A player cannot be the oracle (as the Win checks based on the winner's outputs won't work any longer)
                            datum.oracle != player_1 && datum.oracle != player_2,

                            // Players are paying an equal amount of ADA
                            player_1_outputs_balance == player_1_inputs_balance - wager - value.lovelace_of(tx.fee), // player_1 is also paying the transaction fees
                            player_2_outputs_balance == player_2_inputs_balance - wager,

                            // New datum must update the two players based on the tx's signers
                            contract_output_datum.player_1 == player_1,
                            contract_output_datum.player_2 == player_2,

                            // Players are not altering the deadline and the oracle as they join the contract
                            contract_output_datum.deadline == datum.deadline,
                            contract_output_datum.oracle == datum.oracle
                        }
                    }

                    Win(winner) -> {
                        expect Some(tx_signer) = list.at(tx.extra_signatories, 0)
                        
                        and {
                            // Only the oracle can perform this action
                            tx_signer == datum.oracle,

                            // Players must have joined the contract previously
                            !datum.is_joined,
                            
                            // Oracle can choose the winner only before the deadline
                            datum.deadline > tx_earliest_time,

                            // oracle must choose a winner among the two players 
                            or { // more like a XOR
                                winner == datum.player_1,
                                winner == datum.player_2
                            },

                            // Winner must receive the whole pot
                            utils.get_ada_from_outputs(utils.get_outputs_by_vkh(tx.outputs, winner)) == datum.wager*2
                        }
                    }

                    Timeout -> {
                        // Get the two transaction's signers
                        expect Some(player_1) = list.at(tx.extra_signatories, 0)
                        expect Some(player_2) = list.at(tx.extra_signatories, 1)
                
                        // Players balances
                        let player_1_inputs_balance = utils.get_ada_from_inputs(utils.get_inputs_by_vkh(tx.inputs, player_1))
                        let player_1_outputs_balance = utils.get_ada_from_outputs(utils.get_outputs_by_vkh(tx.outputs, player_1))

                        let player_2_inputs_balance = utils.get_ada_from_inputs(utils.get_inputs_by_vkh(tx.inputs, player_2))
                        let player_2_outputs_balance = utils.get_ada_from_outputs(utils.get_outputs_by_vkh(tx.outputs, player_2))

                        and {
                            // Players must have joined contract previously
                            datum.is_joined,

                            // Transaction has the correct signers
                            player_1 == datum.player_1,
                            player_2 == datum.player_2,
                        
                            // Timeout action can be performed only after the deadline
                            datum.deadline < tx_earliest_time,

                            // Players are receiving the wager amount
                            player_1_outputs_balance == player_1_inputs_balance + datum.wager - value.lovelace_of(tx.fee), // player_1 is also paying the transaction fees
                            player_2_outputs_balance == player_2_inputs_balance + datum.wager,
                        }
                    }
                }
            }
            _ -> False
        }
    }
}

// ////////////////////////////////////////////////////////////////////////////////