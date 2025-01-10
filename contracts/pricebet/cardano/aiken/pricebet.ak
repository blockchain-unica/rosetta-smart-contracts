// Suggested stdlib version: 1.7.0 (https://github.com/aiken-lang/stdlib/releases/tag/1.7.0)

// ////////////////////////////////////////////////////////////////////////////////
// Imports:
// ////////////////////////////////////////////////////////////////////////////////

use aiken/list

use aiken/transaction.{ScriptContext, Spend, InlineDatum}
use aiken/transaction/credential.{Address}


use aiken/interval.{Finite}

//use aiken/cbor // diagnostic

use pricebet/utils.{VerificationKeyHash, POSIXTime, OracleDatum}


// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Types: 
// ////////////////////////////////////////////////////////////////////////////////

type Datum {
    owner: VerificationKeyHash,
    oracle: Address,
    player: VerificationKeyHash,
    deadline: POSIXTime,
    exchange_rate: Int
}

type Redeemer {
    Join
    Win
    Timeout
}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Validator:
// ////////////////////////////////////////////////////////////////////////////////

validator {
    fn pricebet(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) {
        let tx = ctx.transaction

        let tx_earliest_time =
			when tx.validity_range.lower_bound.bound_type is {
				Finite(x) -> x
				_ -> 0
			}

        let own_input = utils.get_own_input(ctx)
        let contract_address = own_input.output.address

        let contract_outputs = utils.get_outputs_by_address(tx.outputs, contract_address)
        let contract_inputs = utils.get_inputs_by_address(tx.inputs, contract_address) 

        let contract_inputs_lovelace_balance = utils.get_ada_from_inputs(contract_inputs)
        let contract_outputs_lovelace_balance = utils.get_ada_from_outputs(contract_outputs)

        // Get the transaction signer
        expect Some(tx_signer) = list.at(tx.extra_signatories, 0)

        when ctx.purpose is {
            Spend(_) -> {
                when redeemer is {
                    Join -> {
                        // Contract must have only one output
                        expect True = list.length(contract_outputs) == 1
                        expect Some(contract_output) = list.at(contract_outputs, 0)

                        // Getting the output's datum
                        expect InlineDatum(untyped_datum) = contract_output.datum
                        expect contract_output_datum: Datum = untyped_datum

                        and {
                            // To join the contract, player field in datum must be equal to an empty string.
                            // Doing so, owner must initialize the contract like this...
                            // ... and if this is not the empty string, the join has been already performed
                            datum.player == "",

                            // Contract is receiving the same amount the owner initially deposited
                            contract_outputs_lovelace_balance == contract_inputs_lovelace_balance * 2,

                            // Player is creating a valid datum
                            contract_output_datum == Datum {
                                owner: datum.owner,
                                oracle: datum.oracle, 
                                player: tx_signer, // this has to change [!!!]
                                deadline: datum.deadline,
                                exchange_rate: datum.exchange_rate
                            }
                        }
                    }
                    
                    Win -> {
                        // Search for an input containing the address of the oracle (this input must be the only one)
                        let oracle_inputs = utils.get_inputs_by_address(tx.inputs, datum.oracle)
                        expect True = list.length(oracle_inputs) == 1
                        expect Some(oracle_input) = list.at(oracle_inputs, 0)

                        // Getting the oracle's datum
                        expect InlineDatum(untyped_datum) = oracle_input.output.datum
                        expect oracle_datum: OracleDatum = untyped_datum

                        and {
                            // Oracle's exchange rate must be greater than or equal to the one specified in this contract's datum 
                            oracle_datum.exchange_rate >= datum.exchange_rate,

                            // Only the player can perform this action
                            tx_signer == datum.player,

                            // Before the timeline
                            datum.deadline > tx_earliest_time
                        }
                    }

                    Timeout -> {
                        // After the timeline and signed by the owner
                        tx_earliest_time > datum.deadline && tx_signer == datum.owner
                    }
                }
            }
            _ -> False
        }
    }
}

// ////////////////////////////////////////////////////////////////////////////////
