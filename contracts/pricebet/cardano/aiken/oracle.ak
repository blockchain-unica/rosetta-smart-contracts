// ////////////////////////////////////////////////////////////////////////////////
// Imports:
// ////////////////////////////////////////////////////////////////////////////////

use aiken/list

use aiken/transaction.{ScriptContext, Spend, InlineDatum}

// use aiken/cbor // diagnostic

use pricebet/utils.{OracleDatum}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Types
// ////////////////////////////////////////////////////////////////////////////////

type Redeemer {
    
}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Validator:
// ////////////////////////////////////////////////////////////////////////////////

validator {
    fn oracle(datum: OracleDatum, _redeemer: Redeemer, ctx: ScriptContext) {
        let tx = ctx.transaction

        let own_input = utils.get_own_input(ctx)
        let contract_address = own_input.output.address

        let contract_outputs = utils.get_outputs_by_address(tx.outputs, contract_address)
        let contract_inputs = utils.get_inputs_by_address(tx.inputs, contract_address) 

        let contract_inputs_lovelace_balance = utils.get_ada_from_inputs(contract_inputs)
        let contract_outputs_lovelace_balance = utils.get_ada_from_outputs(contract_outputs)

        when ctx.purpose is {
            // To spend from this UTXO...
            Spend(_) -> {
                // ...contract must have only one output...
                expect True = list.length(contract_outputs) == 1
                expect Some(contract_output) = list.at(contract_outputs, 0)

                // (getting the output's datum)
                expect InlineDatum(untyped_datum) = contract_output.datum
                expect contract_output_datum: OracleDatum = untyped_datum

                and {
                    // ...no ADA must be taken away...
                    contract_outputs_lovelace_balance == contract_inputs_lovelace_balance,

                    // ... and datum must not change
                    contract_output_datum == datum
                }
            }
            _ -> False
        }
    }
}

// ////////////////////////////////////////////////////////////////////////////////
