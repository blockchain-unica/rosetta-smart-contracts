// /////////////////////////////////////////////////////////////////////////////////////////////////////////
// Contract definition
// /////////////////////////////////////////////////////////////////////////////////////////////////////////

/// Partecipants:
/// - owner      (O)
/// - recipient  (R)

/// Description:
/// The owner deposits ADA in the contract and the specified recipient can withdraw any arbitrary fractions 
/// of the contract's balance. In addition to that, the contract checks if the current transaction (in its
/// outputs) preserves the contract when the correct ADA amount is returned to it.

// /////////////////////////////////////////////////////////////////////////////////////////////////////////


// /////////////////////////////////////////////////////////////////////////////////////////////////////////
// Imports
// /////////////////////////////////////////////////////////////////////////////////////////////////////////

use aiken/list
    
use aiken/transaction.{Transaction, ScriptContext, Spend, InlineDatum}

use simple_transfer/utils.{VerificationKeyHash}

// use aiken/cbor // diagnostic

// /////////////////////////////////////////////////////////////////////////////////////////////////////////


// /////////////////////////////////////////////////////////////////////////////////////////////////////////
// Types definition
// /////////////////////////////////////////////////////////////////////////////////////////////////////////

type Datum {
    /// The recipient's public key's hash
    recipient: VerificationKeyHash 
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
/// @funct has_exactly_two_outputs
/// @brief - Performs the checks of the simple_transfer contract
/// @param transaction
/// @return Bool - True if the transaction's outputs list contains exactly two elements, False otherwise
/// *** 
fn has_exactly_two_outputs(transaction: Transaction) {
    when transaction.outputs is {
        [_o1, _o2] -> True
        _other -> False
    }
}


validator {
    /// ***
    /// @valid simple_transfer
    /// @param datum
    /// @param redeemer
    /// @param ctx - The context 'object' in which the transaction is executed
    /// @return Bool
    /// *** 
    fn simple_transfer(datum: Datum, redeemer: Redeemer, ctx: ScriptContext)  {

        let tx = ctx.transaction
        let own_input = utils.get_own_input(ctx)
        let contract_address = own_input.output.address

        // Validator's main logic
        when ctx.purpose is {
            Spend(_) -> {
                let recipient_outputs = utils.get_outputs_by_vkh(tx.outputs, datum.recipient)

                let contract_outputs = utils.get_outputs_by_address(tx.outputs, contract_address)
                let contract_inputs = utils.get_inputs_by_address(tx.inputs, contract_address) 
                let contract_inputs_balance = utils.get_ada_from_inputs(contract_inputs)

                and {
                    utils.must_be_signed_by(tx, datum.recipient),

                    !list.is_empty(recipient_outputs), // has recipient as output
                    !list.is_empty(contract_outputs),  // has contract as output
                    
                    has_exactly_two_outputs(tx),

                    // The new UTXO kept by the contract must have the same datum as before
                    list.all(contract_outputs, fn(output) { output.datum == InlineDatum(datum) }),

                    // The contract's output value (i.e. its new balance) must be its previous balance minus the amount declared in the redeemer
                    utils.get_ada_from_outputs(contract_outputs) == contract_inputs_balance - redeemer.amount
                }
            }
            _ -> False
        }
    }
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////