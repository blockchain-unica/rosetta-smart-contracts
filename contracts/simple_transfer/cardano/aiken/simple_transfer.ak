// Suggested compiler version: 1.6.0 

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
    
use aiken/transaction.{ScriptContext, Spend, InlineDatum}
use aiken/transaction/value

use simple_transfer/utils.{VerificationKeyHash, Lovelace}

// use aiken/cbor // diagnostic

// /////////////////////////////////////////////////////////////////////////////////////////////////////////


// /////////////////////////////////////////////////////////////////////////////////////////////////////////
// Types definition
// /////////////////////////////////////////////////////////////////////////////////////////////////////////

type Datum {
    owner: VerificationKeyHash,
    recipient: VerificationKeyHash, 
    initialization_amount: Lovelace // (offset) this amount can never be moved from the contract
}

type Redeemer {
    Deposit { amount: Lovelace }
    Withdraw { amount: Lovelace }
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////


// /////////////////////////////////////////////////////////////////////////////////////////////////////////
// Auxiliary functions and validator
// /////////////////////////////////////////////////////////////////////////////////////////////////////////

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

        let offset = datum.initialization_amount

        // Validator's main logic
        when ctx.purpose is {
            Spend(_) -> {
                let recipient_inputs = utils.get_inputs_by_vkh(tx.inputs, datum.recipient)
                let recipient_outputs = utils.get_outputs_by_vkh(tx.outputs, datum.recipient)

                let owner_outputs = utils.get_outputs_by_vkh(tx.outputs, datum.owner)

                let contract_inputs = utils.get_inputs_by_address(tx.inputs, contract_address) 
                let contract_outputs = utils.get_outputs_by_address(tx.outputs, contract_address)
 
                let contract_balance = value.lovelace_of(own_input.output.value)

                expect True = and {
                    contract_balance == utils.get_ada_from_inputs(contract_inputs),

                    !list.is_empty(contract_outputs),  // has contract as output

                    // The new UTXO kept by the contract must have the same datum as before
                    list.all(contract_outputs, fn(output) { output.datum == InlineDatum(datum) })
                }

                when redeemer is {
                    Deposit(amount) -> {
                        and {
                            // Only owner can deposit
                            utils.must_be_signed_by(tx, datum.owner),

                            !list.is_empty(owner_outputs), // has owner as output

                            // Contract is receiving the correct amount
                            utils.get_ada_from_outputs(contract_outputs) == contract_balance + amount
                        }
                    }

                    Withdraw (amount) -> {
                        and {
                            // Only recipient can withdraw
                            utils.must_be_signed_by(tx, datum.recipient),

                            // Contract has the amount to safely (i.e. to preserve covenant) accept the withdraw
                            contract_balance - offset >= amount, 

                            !list.is_empty(recipient_outputs), // has recipient as output

                            // The contract's output value (i.e. its new balance) must be its previous balance minus the amount declared in the redeemer
                            utils.get_ada_from_outputs(contract_outputs) == contract_balance - amount,

                            // Recipient is receiving the correct amount
                            utils.get_ada_from_outputs(recipient_outputs) == utils.get_ada_from_inputs(recipient_inputs) + amount - value.lovelace_of(tx.fee)
                        }
                    }

                }
            }

            _ -> False
        }
    }
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////