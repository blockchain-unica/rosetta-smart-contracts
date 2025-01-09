// Suggested compiler version: 1.6.0 

// ////////////////////////////////////////////////////////////////////////////////
// Imports:
// ////////////////////////////////////////////////////////////////////////////////

use aiken/dict.{Dict}
use aiken/list

use aiken/transaction.{ScriptContext, Spend, InlineDatum}

use crowdfund/utils.{VerificationKeyHash, POSIXTime}

// use aiken/cbor // diagnostic

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Types: 
// ////////////////////////////////////////////////////////////////////////////////

type Datum {
    recipient: VerificationKeyHash,
    goal: Int,
    deadline: POSIXTime,
    wallets: Dict<VerificationKeyHash, Int>
}

/// We need redundant latest_donor and latest_donation fields inside datum to do additional checks when validating new donations:
/// we're not checking input.output.address and input.output.value since input's address may be different from donor's one. 

type Redeemer {
    Donate { amount: Int, donor: VerificationKeyHash }
    Withdraw
    Reclaim
}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Validator:
// ////////////////////////////////////////////////////////////////////////////////
validator {
    fn crowdfund(datum: Datum, redeemer: Redeemer, ctx:ScriptContext) {
        let tx = ctx.transaction
        
        let own_input = utils.get_own_input(ctx)
        let contract_address = own_input.output.address

        let contract_inputs = utils.get_inputs_by_address(tx.inputs, contract_address)
        let contract_outputs = utils.get_outputs_by_address(tx.outputs, contract_address)
        
        let contract_amount = dict.foldl(datum.wallets, 0, fn(_k, v, r) { v + r }) // summing up all the values in the wallets
        expect True = contract_amount == utils.get_ada_from_inputs(contract_inputs)

        when ctx.purpose is {
            Spend(_) -> {
                when redeemer is {
                    Donate(amount, donor) -> {
                        // We expect there's only one output addressed to the contract
                        expect True = list.length(contract_outputs) == 1
                        expect Some(contract_output) = list.at(contract_outputs, 0)
        
                        // Checking the datum
                        expect InlineDatum(untyped_datum) = contract_output.datum
                        expect contract_output_datum: Datum = untyped_datum

                        expect True = and {
                            // Accept new donations only if the transaction starts before the deadline
                            utils.must_start_before_timeout(tx.validity_range, datum.deadline),
                            
                            // They must be signed by donor
                            utils.must_be_signed_by(tx, donor),

                            // Contract must receive back its own wallets' amount + the one declared in the new datum 
                            utils.get_ada_from_outputs(contract_outputs) == contract_amount + amount,

                            // Static parts of datum must not change in the new output:
                            contract_output_datum.recipient == datum.recipient,
                            contract_output_datum.goal == datum.goal,
                            contract_output_datum.deadline == datum.deadline
                        }

                        let output_wallets = contract_output_datum.wallets

                        ////////////////////////////////////////////////////////////////////////////////

                        // TODO: better handling of this dict.insert_with() // https://aiken-lang.github.io/stdlib/aiken/dict.html#insert_with
                        
                        // Current donor is not altering the other donors' wallets
                        expect True = dict.filter(datum.wallets,fn(k, _v) { k != donor }) == dict.filter(output_wallets, fn(k, _v) { k != donor })

                        expect Some(output_wallet_amount) = dict.get(output_wallets, donor)

                        if(!dict.has_key(datum.wallets, donor)) {
                            // In case of new donations, donors have to insert themselves into the new wallet with the correct amount
                            amount == output_wallet_amount
                        } 
                        else { 
                            expect Some(previous_wallet_amount) = dict.get(datum.wallets, donor)

                            // In case of subsequent donations, donors have to correctly update the wallet: value associated to donor must be the previous one plus the new donated amount
                            output_wallet_amount == previous_wallet_amount + amount
                        }

                        ////////////////////////////////////////////////////////////////////////////////
                    }

                    Withdraw -> {
                        and {
                            // Only the recipient can withdraw
                            utils.must_be_signed_by(tx, datum.recipient),

                            // This action can be performed only after the deadline
                            !utils.must_start_before_timeout(tx.validity_range, datum.deadline),

                            // Crowdfunding must have reached the ADA goal
                            contract_amount >= datum.goal
                        }
                    }

                    Reclaim -> {
                        expect Some(current_signer) = list.at(tx.extra_signatories, 0)

                        // Signer must appear in the wallets
                        expect Some(withdraw_amount) = dict.get(datum.wallets, current_signer)

                        // This action can be performed only after the deadline
                        expect True = !utils.must_start_before_timeout(tx.validity_range, datum.deadline)

                        if(dict.size(datum.wallets) > 1) {
                            // We expect there's only one output addressed to the contract
                            expect True = list.length(contract_outputs) == 1
                            expect Some(contract_output) = list.at(contract_outputs, 0)

                            // Must take away from contract the correct amount in the wallet
                            expect True = utils.get_ada_from_outputs(contract_outputs) == utils.get_ada_from_inputs(contract_inputs) - withdraw_amount

                            // Checking the datum
                            expect InlineDatum(untyped_datum) = contract_output.datum
                            expect contract_output_datum: Datum = untyped_datum

                            and {    
                                // New datum must be the same but without the current_signer field in the wallets dict
                                contract_output_datum.recipient == datum.recipient,
                                contract_output_datum.goal == datum.goal,
                                contract_output_datum.deadline == datum.deadline,
                                contract_output_datum.wallets == dict.filter(datum.wallets, fn(k, _v) { k!= current_signer })
                            }
                        }
                        else {
                            // Last reclaim: there's not need (and, most importantly, way) to send back 0 ADA to the contract, so we simply do not expect a contract's output in this case
                            list.length(contract_outputs) == 0
                        }
                    }
                }
            }
            _ -> False
        }
    }
}

// ////////////////////////////////////////////////////////////////////////////////
