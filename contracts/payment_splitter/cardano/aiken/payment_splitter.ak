// ////////////////////////////////////////////////////////////////////////////////
// Imports:
// ////////////////////////////////////////////////////////////////////////////////

use aiken/list
use aiken/dict.{Dict}

use aiken/transaction.{ScriptContext, Spend, InlineDatum}
use aiken/transaction/value

// use aiken/cbor // diagnostic

use payment_splitter/utils.{VerificationKeyHash, Lovelace}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Types: 
// ////////////////////////////////////////////////////////////////////////////////

type Datum {
    shares: Dict<VerificationKeyHash, Int>,
    released: Dict<VerificationKeyHash, Lovelace>,
    payees: List<VerificationKeyHash>,
    effective_balance: Lovelace // without the initialization amount
}

type Redeemer {
    Receive { amount: Lovelace }
    Release
}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Validator:
// ////////////////////////////////////////////////////////////////////////////////

validator {
    fn payment_splitter(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) {
        let tx = ctx.transaction

        // Contract
        let own_input = utils.get_own_input(ctx)
        let contract_address = own_input.output.address
        
        let contract_outputs = utils.get_outputs_by_address(tx.outputs, contract_address)
        let contract_inputs = utils.get_inputs_by_address(tx.inputs, contract_address) 

        let contract_inputs_balance = utils.get_ada_from_inputs(contract_inputs)
        let contract_outputs_balance = utils.get_ada_from_outputs(contract_outputs)

        // Contract must have only one output
        expect True = list.length(contract_outputs) == 1
        expect Some(contract_output) = list.at(contract_outputs, 0)

        // Getting the output's datum
        expect InlineDatum(untyped_datum) = contract_output.datum
        expect contract_output_datum: Datum = untyped_datum

        // total_released is the sum of all the values in the released dictionary
        let total_released = datum.released |> dict.foldl(0, fn(_k, v, r) { v + r })

        // total_received is the current balance + the total_released amount
        let total_received = datum.effective_balance + total_released

        // total_shares is the sum of all the values in the shares dictionary
        let total_shares = datum.shares |> dict.foldl(0, fn(_k, v, r) { v + r })

        when ctx.purpose is {
            Spend(_) -> {
                when redeemer is {
                    Receive(amount) -> {
                        and {
                            // Contract is receiving the declared amount
                            contract_outputs_balance == contract_inputs_balance + amount,
                            contract_output_datum.effective_balance == datum.effective_balance + amount,

                            // Sender is not altering the rest of the datum
                            contract_output_datum.shares == datum.shares,
                            contract_output_datum.released == datum.released,
                            contract_output_datum.payees == datum.payees
                        }
                    }

                    Release -> {
                        // Transaction signer must be a shareholder
                        expect Some(tx_signer) = list.at(tx.extra_signatories, 0)
                        expect Some(shareholder) = list.find(datum.payees, fn(payee) { payee == tx_signer },)

                        // Shareholder's shares must be greater than 0 
                        expect Some(share) = datum.shares |> dict.get(key: shareholder)
                        expect True = share > 0

                        let shareholder_inputs = utils.get_inputs_by_vkh(tx.inputs, shareholder)
                        let shareholder_outputs = utils.get_outputs_by_vkh(tx.outputs, shareholder)

                        // Retrieve the already released value for this shareholder
                        expect Some(already_released_to_shareholder) = datum.released |> dict.get(key: shareholder)

                        // Compute the release amount
                        let payment = (total_received * share) / total_shares - already_released_to_shareholder

                        // Shareholder is not altering the other released dictionaries
                        expect True = dict.filter(datum.released,fn(k, _v) { k != shareholder }) == dict.filter(contract_output_datum.released, fn(k, _v) { k != shareholder })
                        expect Some(output_released_amount) = dict.get(contract_output_datum.released, shareholder)

                        and {
                            // Shareholder is withdrawing the correct amount from the contract
                            contract_outputs_balance == contract_inputs_balance - payment, 

                            // Shareholder is receiving the correct amount (taking fees into account)
                            utils.get_ada_from_outputs(shareholder_outputs) == utils.get_ada_from_inputs(shareholder_inputs) + payment - value.lovelace_of(tx.fee),

                            // Must update their own already released amount
                            output_released_amount == already_released_to_shareholder + payment,

                            // Must update the effective balance in the datum
                            contract_output_datum.effective_balance == datum.effective_balance - payment,

                            // Must not alter other datum's fields
                            contract_output_datum.shares == datum.shares && contract_output_datum.payees == datum.payees                
                        }
                    }
                }
            }
            _ -> False
        }
    }
}

// ////////////////////////////////////////////////////////////////////////////////
