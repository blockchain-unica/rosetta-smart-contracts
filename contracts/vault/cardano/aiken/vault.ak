// ////////////////////////////////////////////////////////////////////////////////
// Imports:
// ////////////////////////////////////////////////////////////////////////////////

use aiken/list

use aiken/transaction.{ScriptContext, Spend, InlineDatum}

use vault/utils.{VerificationKeyHash, POSIXTime}

use aiken/interval.{Finite}

// use aiken/cbor // diagnostic

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Types: 
// ////////////////////////////////////////////////////////////////////////////////

type Datum {
    owner: VerificationKeyHash,
    recovery: VerificationKeyHash,
    wait_time: POSIXTime,    // The amount of time the owner has to wait after the withdrawal request to finalize it
    withdraw_amount: Int, 
    request_time: POSIXTime, // The time when the withdraw request has been performed
    status: Status
}

type Redeemer {
    Deposit { amount: Int }
    Withdraw { amount: Int }
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

        let contract_amount = utils.get_ada_from_inputs(contract_inputs)

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
            request_time: datum.request_time, // this doesn't have to change neither
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
                            utils.get_ada_from_outputs(contract_outputs) == contract_amount + deposit_amount,

                            // Must preserve datum
                            contract_output_datum == datum
                        }
                    }

                    Withdraw(withdraw_amount) -> {
                        let tolerance_treshold = 1000 // one second (in milliseconds)

                        and {
                            utils.must_be_signed_by(tx, datum.owner),
                            
                            // Owner can withdraw only during IDLE status
                            datum.status == IDLE,
                            
                            // Contract must have enough ADA to accept the request
                            utils.get_ada_from_inputs(contract_inputs) >= withdraw_amount,
                            
                            // No ADA must be moved yet from contract
                            utils.get_ada_from_outputs(contract_outputs) == utils.get_ada_from_inputs(contract_inputs),
                            
                            // New contract's datum must have an expected datum
                            contract_output_datum.owner == datum.owner,
                            contract_output_datum.recovery == datum.recovery,
                            contract_output_datum.wait_time == datum.wait_time,
                            contract_output_datum.withdraw_amount == withdraw_amount,
                            contract_output_datum.status == REQUEST,

                            // Declared request time must be coherent with the transaction's time (there're not other ways to let this correspond to the one we send through Lucid)
                            and {
                                contract_output_datum.request_time >= tx_earliest_time - tolerance_treshold,
                                contract_output_datum.request_time <= tx_earliest_time + tolerance_treshold
                            }
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
                            utils.get_ada_from_outputs(contract_outputs) == contract_amount - datum.withdraw_amount,

                            // New contract must have an expected datum
                            contract_output_datum == expected_idle_datum
                        }
                    }

                    Cancel -> {
                        and {
                            utils.must_be_signed_by(tx, datum.recovery),

                            // Recovery address can cancel the request only if a withdraw action has been performed before
                            datum.status == REQUEST,

                            // No ADA must be taken from contract (to perform a transaction, we've to pay a minimum amount of ADA in Cardano...)
                            utils.get_ada_from_outputs(contract_outputs) >= utils.get_ada_from_inputs(contract_inputs),

                            // This action is possible during the waiting time only
                            tx_earliest_time <= datum.request_time + datum.wait_time,

                            // New contract must have an expected datum
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