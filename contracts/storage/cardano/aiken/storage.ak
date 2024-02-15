// ////////////////////////////////////////////////////////////////////////////////
// Imports:
// ////////////////////////////////////////////////////////////////////////////////

use aiken/list

use aiken/transaction.{ScriptContext, Spend, InlineDatum}

use storage/utils.{VerificationKeyHash}

// use aiken/cbor // diagnostic

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Types: 
// ////////////////////////////////////////////////////////////////////////////////

type Datum {
    owner: VerificationKeyHash,
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

        // In every situation, contract must have only one output
        expect True = list.length(contract_outputs) == 1
        expect Some(contract_output) = list.at(contract_outputs, 0)

        // For each action after initialization, we expect the tx's signer to be always the owner in the datum (after the first initialization) 
        expect Some(tx_signer) = list.at(tx.extra_signatories, 0)
        expect True = tx_signer == datum.owner

        // Inspecting the new datum:
        expect InlineDatum(untyped_datum) = contract_output.datum
        expect contract_output_datum: Datum = untyped_datum

        // Owner must not change during contract's life (i.e. new owner in the new output's datum must be the same as the current one)
        expect True = contract_output_datum.owner == datum.owner 

        when ctx.purpose is {
            Spend(_) -> {
                when redeemer is {
                    StoreBytes {sequence} -> {
                        // New datum must update sequence and sequence only 
                        and {
                            sequence != datum.bytes_sequence,
                            contract_output_datum.bytes_sequence == sequence,
                            contract_output_datum.text_string == datum.text_string,
                        }
                        
                    }

                    StoreString {string} -> {
                        // New datum must update string and string only 
                        and {
                            string != datum.text_string,
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