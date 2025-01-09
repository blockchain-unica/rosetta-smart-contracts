// Suggested compiler version: 1.6.0 

// ////////////////////////////////////////////////////////////////////////////////
// Imports:
// ////////////////////////////////////////////////////////////////////////////////

use aiken/list

use aiken/transaction.{ScriptContext, Spend, InlineDatum}
use aiken/transaction/value

use vault/utils.{VerificationKeyHash, POSIXTime}

use aiken/interval.{Finite}

// use aiken/cbor // diagnostic

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Types: 
// ////////////////////////////////////////////////////////////////////////////////

type Datum {
    owner: VerificationKeyHash,         // Can perform a withdraw request
    recovery: VerificationKeyHash,      // Can cancel a withdraw request
    wait_time: POSIXTime,
    withdraw_amount: Int, 
    receiver: VerificationKeyHash,
    request_time: POSIXTime,
    status: Status
}

type Redeemer {
    Deposit { amount: Int }
    Withdraw { amount: Int, receiver: VerificationKeyHash }
    Finalize
    Cancel
}

type Status {
    IDLE
    REQUEST
}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Validator:
// ////////////////////////////////////////////////////////////////////////////////

validator {
    fn vault(datum: Datum, redeemer: Redeemer, ctx:ScriptContext) {
        let tx = ctx.transaction
        
        let own_input = utils.get_own_input(ctx)
        let contract_address = own_input.output.address

        let contract_inputs = utils.get_inputs_by_address(tx.inputs, contract_address)
        let contract_outputs = utils.get_outputs_by_address(tx.outputs, contract_address)

        let contract_current_amount = utils.get_ada_from_inputs(contract_inputs)
        let contract_output_amount = utils.get_ada_from_outputs(contract_outputs)

        let tx_earliest_time = when tx.validity_range.lower_bound.bound_type is {
            Finite(x) -> x
            _ -> 0
        }

        // In every situation, contract must have only one output
        expect True = list.length(contract_outputs) == 1
        expect Some(contract_output) = list.at(contract_outputs, 0)

        // A datum we expect to receive when status has to change to IDLE
        let expected_idle_datum = Datum {
            owner: datum.owner,
            recovery: datum.recovery,
            wait_time: datum.wait_time,
            withdraw_amount: datum.withdraw_amount,
            receiver: datum.receiver,
            request_time: datum.request_time,
            status: IDLE
        }
        
        // Checking the new datum:
        expect InlineDatum(untyped_datum) = contract_output.datum
        expect contract_output_datum: Datum = untyped_datum

        when ctx.purpose is {
            Spend(_) -> {
                when redeemer is {
                    Deposit(deposit_amount) -> {
                        and {
                            // Anyone can do this at any moment (status)

                            // Contract must receive the correct amount
                            contract_output_amount == contract_current_amount + deposit_amount,

                            // Must preserve datum
                            contract_output_datum == datum
                        }
                    }

                    Withdraw(withdraw_amount, receiver) -> {
                        and {
                            utils.must_be_signed_by(tx, datum.owner),
                            
                            // Owner can withdraw only during IDLE status
                            datum.status == IDLE,
                            
                            // Contract must have enough ADA to accept the request
                            contract_current_amount >= withdraw_amount,
                            
                            // No ADA must be moved yet from contract
                            contract_output_amount == contract_current_amount,
                            
                            // New contract's datum must have an expected datum
                            contract_output_datum.owner == datum.owner,
                            contract_output_datum.recovery == datum.recovery,
                            contract_output_datum.wait_time == datum.wait_time,
                            contract_output_datum.withdraw_amount == withdraw_amount,
                            contract_output_datum.receiver == receiver,
                            contract_output_datum.request_time == tx_earliest_time,
                            contract_output_datum.status == REQUEST
                        }
                        
                    }

                    Finalize -> {
                        and {
                            utils.must_be_signed_by(tx, datum.owner),

                            // Owner can finalize the request only if they performed a withdraw action before
                            datum.status == REQUEST,

                            // The withdrawal request is finalized only if the amount of time is elapsed
                            tx_earliest_time > datum.request_time + datum.wait_time,

                            // Owner is withdrawing the correct declared amount
                            contract_output_amount == contract_current_amount - datum.withdraw_amount,

                            // Reicever in the datum is receiving the amount
                            if(datum.receiver == datum.owner) {
                                // If the reciver is the owner, we must take into account fees
                                utils.get_ada_from_outputs(utils.get_outputs_by_vkh(tx.outputs, datum.receiver)) == 
                                    utils.get_ada_from_inputs(utils.get_inputs_by_vkh(tx.inputs, datum.receiver)) + datum.withdraw_amount - value.lovelace_of(tx.fee)
                            }
                            else {
                                utils.get_ada_from_outputs(utils.get_outputs_by_vkh(tx.outputs, datum.receiver)) == 
                                    utils.get_ada_from_inputs(utils.get_inputs_by_vkh(tx.inputs, datum.receiver)) + datum.withdraw_amount
                            },
                            
                            // New contract output must have an expected datum
                            contract_output_datum == expected_idle_datum
                        }
                    }

                    Cancel -> {
                        and {
                            utils.must_be_signed_by(tx, datum.recovery),

                            // Recovery address can cancel the request only if a withdraw action has been performed before
                            datum.status == REQUEST,

                            // No ADA must be moved from contract
                            contract_output_amount == contract_current_amount,

                            // This action is possible during the waiting time only
                            tx_earliest_time <= datum.request_time + datum.wait_time,

                            // New contract output must have an expected datum
                            contract_output_datum == expected_idle_datum
                        }
                    }
                }
            }
            _ -> False
        }
    }
}

// ////////////////////////////////////////////////////////////////////////////////