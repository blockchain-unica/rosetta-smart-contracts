// Suggested stdlib version: 1.7.0 (https://github.com/aiken-lang/stdlib/releases/tag/1.7.0)

// ////////////////////////////////////////////////////////////////////////////////
// Imports:
// ////////////////////////////////////////////////////////////////////////////////

use aiken/list

use aiken/transaction.{ScriptContext, Spend, InlineDatum}

// use aiken/cbor // diagnostic

use storage/utils

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Types: 
// ////////////////////////////////////////////////////////////////////////////////

type Datum {
    bytes_sequence: ByteArray,
    text_string: ByteArray,
}

type Redeemer {
    StoreBytes { sequence: ByteArray }
    StoreString { string: ByteArray } // 'string' is safe to use in Aiken since it's not a reserved keyword 
}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Validator:
// ////////////////////////////////////////////////////////////////////////////////

validator {
    fn storage(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) {
        let tx = ctx.transaction

        let own_input = utils.get_own_input(ctx)
        let contract_address = own_input.output.address

        let contract_outputs = utils.get_outputs_by_address(tx.outputs, contract_address)
        let contract_inputs = utils.get_inputs_by_address(tx.inputs, contract_address)

        // In every situation, contract must have only one output
        expect True = list.length(contract_outputs) == 1
        expect Some(contract_output) = list.at(contract_outputs, 0)

        // No ADA must be moved from this contract
        expect True = utils.get_ada_from_outputs(contract_outputs) == utils.get_ada_from_inputs(contract_inputs)

        // Inspecting the new datum:
        expect InlineDatum(untyped_datum) = contract_output.datum
        expect contract_output_datum: Datum = untyped_datum

        when ctx.purpose is {
            Spend(_) -> {
                when redeemer is {
                    StoreBytes {sequence} -> {
                        // New datum must update sequence and sequence only 
                        and {
                            contract_output_datum.bytes_sequence == sequence,
                            contract_output_datum.text_string == datum.text_string,
                        }
                    }

                    StoreString {string} -> {
                        // New datum must update string and string only 
                        and {
                            contract_output_datum.text_string == string,
                            contract_output_datum.bytes_sequence == datum.bytes_sequence,
                        }
                    }
                }
            }
            _ -> False
        }
    }
}

// ////////////////////////////////////////////////////////////////////////////////