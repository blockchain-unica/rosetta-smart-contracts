// /////////////////////////////////////////////////////////////////////////////////////////////////////////
// Contract definition
// /////////////////////////////////////////////////////////////////////////////////////////////////////////

/// Partecipants:
/// - owner      (O)
/// - recipient  (R)

/// Description:
/// The owner deposits tokens in the contract and the specified recipient can withdraw any arbitrary fractions 
/// of the contract's token balance. 
/// In addition to that, the contract checks if the current transaction (in its outputs) preserves the contract 
/// when the correct token amount is returned to it and, it also checks that the contract's and 
/// recipient's ADA balance hasn't changed during the transaction.

// /////////////////////////////////////////////////////////////////////////////////////////////////////////


// /////////////////////////////////////////////////////////////////////////////////////////////////////////
// Imports
// /////////////////////////////////////////////////////////////////////////////////////////////////////////

use aiken/dict
use aiken/list

use aiken/transaction.{ScriptContext, Transaction, Spend, InlineDatum}
use aiken/transaction/value

use token_transfer/utils.{VerificationKeyHash}

// use aiken/cbor // diagnostic

// /////////////////////////////////////////////////////////////////////////////////////////////////////////


// /////////////////////////////////////////////////////////////////////////////////////////////////////////
// Types definition
// /////////////////////////////////////////////////////////////////////////////////////////////////////////

type Datum {
    /// The recipient's public key's hash
    recipient: VerificationKeyHash, 
}

type Redeemer {
    /// The withdrawal amount specified by the recipient
    amount: Int 
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////


// /////////////////////////////////////////////////////////////////////////////////////////////////////////
// Auxiliary functions and validator
// /////////////////////////////////////////////////////////////////////////////////////////////////////////

/// ***
/// @funct must_manage_exactly_one_token
/// @brief - Checks if there's only one native token (excluding ADA) in the transaction
/// @dev - There's not need to check the outputs list since we're already checking the inputs' one
/// @param transaction
/// @return Bool - True iff there's only one token (excluding ADA) in the transaction
/// *** 
fn must_manage_exactly_one_token(transaction: Transaction) {
    // The list of inputs having a native token
    let inputs_with_token = utils.get_inputs_with_token(transaction.inputs)

    // For each input managing token (please keep in mind those inputs have ADA as well)
    list.all(inputs_with_token, fn(input) { 
        let current_value = input.output.value

        // All the policies in the current input (exluding ADA)
        let policies_list = list.filter(value.policies(current_value), fn(policy) {
            policy != value.ada_policy_id
        })
    
        // There's only one policy_id inside the list
        expect True = list.length(policies_list) == 1

        // Take the first (and only) policy_id from the list
        expect Some(policy) = list.at(policies_list, 0) 
    
        // All the tokens with the specified PolicyId
        let tokens_dict = value.tokens(current_value, policy)

        // The input must have exactly one token
        dict.size(tokens_dict) == 1
    })
}


validator {
    /// ***
    /// @valid token_transfer
    /// @param datum
    /// @param redeemer
    /// @param ctx - The context 'object' in which the transaction is executed
    /// @return Bool
    /// *** 
    fn token_transfer(datum: Datum, redeemer: Redeemer, ctx: ScriptContext)  {

        let tx = ctx.transaction
        let own_input = utils.get_own_input(ctx)
        let contract_address = own_input.output.address

        // Validator's main logic
        when ctx.purpose is {
            Spend(_) -> {
                let recipient_outputs = utils.get_outputs_by_vkh(tx.outputs, datum.recipient)
                let recipient_inputs = utils.get_inputs_by_vkh(tx.inputs, datum.recipient)
                let recipient_inputs_lovelace_balance = utils.get_ada_from_inputs(recipient_inputs)

                let contract_outputs = utils.get_outputs_by_address(tx.outputs, contract_address)
                let contract_inputs = utils.get_inputs_by_address(tx.inputs, contract_address) 
                let contract_inputs_lovelace_balance = utils.get_ada_from_inputs(contract_inputs)

                and {
                    utils.must_be_signed_by(tx, datum.recipient),

                    !list.is_empty(recipient_outputs), // has recipient as output

                    !list.is_empty(contract_outputs),  // has contract as output

                    // The new UTXOs kept by the contract must have the same datum as before
                    list.all(contract_outputs, fn(output) { output.datum == InlineDatum(datum) }),

                    // Since we are not spending ADA from the contract: its new output value must be the same as before
                    utils.get_ada_from_outputs(contract_outputs) == contract_inputs_lovelace_balance,

                    // This is true for the recipient as well, but he's paying the tx's ADA fees
                    utils.get_ada_from_outputs(recipient_outputs) == recipient_inputs_lovelace_balance - value.lovelace_of(tx.fee),

                    // There must be only one token in the transaction
                    must_manage_exactly_one_token(tx),
                    
                    // The contract's output token value must be its previous balance minus the amount declared in the redeemer
                    utils.get_tokens_balance_from_outputs(contract_outputs) == utils.get_tokens_balance_from_inputs(contract_inputs) - redeemer.amount,

                    // The recipient's output instead has to contain the withdraw amount (doing so we also assure the recipient is the one directly withdrawing the tokens)
                    utils.get_tokens_balance_from_outputs(recipient_outputs) == utils.get_tokens_balance_from_inputs(recipient_inputs) + redeemer.amount
                }
            }
            _ -> False
        }
    }
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////