// ////////////////////////////////////////////////////////////////////////////////
// Imports:
// ////////////////////////////////////////////////////////////////////////////////

use aiken/list

use aiken/transaction.{ScriptContext, Spend, InlineDatum}

// use aiken/cbor // diagnostic

use aiken/transaction/value

use simple_wallet/utils.{VerificationKeyHash, Lovelace}

// ////////////////////////////////////////////////////////////////////////////////

// ////////////////////////////////////////////////////////////////////////////////
// Types: 
// ////////////////////////////////////////////////////////////////////////////////

type Transaction {
    to: VerificationKeyHash,
    value: Lovelace,
    data: ByteArray,
    is_executed: Bool
}

type Datum {
    owner: VerificationKeyHash,
    transactions: List<Transaction>
}

type Redeemer {
    Deposit { amount: Lovelace }
    CreateTransaction { transaction: Transaction }
    SubmitTransaction{ id: Int }
    Withdraw { safety_change_amount: Lovelace } // in Cardano you cannot send 0 ADA to a contract (but we still want to produce an output to preserve covenant)
}

// ////////////////////////////////////////////////////////////////////////////////


// // //////////////////////////////////////////////////////////////////////////////
// Auxiliary functions:
// ////////////////////////////////////////////////////////////////////////////////

/// ***
/// @funct remove_at
/// @brief - Removes the element at position index from the given list. 
/// @brief - We cannot use list.delete method because there could be duplicated ambiguous items (https://aiken-lang.github.io/stdlib/aiken/list.html#delete)
/// @param self - List of elements
/// @param index - Index of the element we want to remove from the list
/// @return List<a> - The list without the element in that position. If n is the size of the given list, the new list has size n-1.
/// *** 
fn remove_at(self: List<a>, index: Int) -> List<a> {
    let spanned_list = list.span(self, index)

    let first_span = spanned_list.1st   // these items will maintain their index
    let second_span = spanned_list.2nd  // the element we want to remove is always in the first position here

    when second_span is { 
        [] -> first_span
        [_x] -> first_span
        // If there is more than 1 element:
        _ -> {
            expect Some(second_span_tail) = list.tail(second_span) // list.tail returns Option<List<a>> ...

            // Merge the first unchanged spanned list to the second spanned list without the first element
            list.concat(first_span, second_span_tail)
        }
    }
}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Validator:
// ////////////////////////////////////////////////////////////////////////////////

validator {
    fn simple_wallet(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) {
        let tx = ctx.transaction

        let own_input = utils.get_own_input(ctx)

        // Contract
        let contract_address = own_input.output.address
        
        let contract_outputs = utils.get_outputs_by_address(tx.outputs, contract_address)
        let contract_inputs = utils.get_inputs_by_address(tx.inputs, contract_address) 

        let contract_outputs_lovelace_balance = utils.get_ada_from_outputs(contract_outputs)
        let contract_inputs_lovelace_balance = utils.get_ada_from_inputs(contract_inputs)
        
        // Owner
        let owner_outputs = utils.get_outputs_by_vkh(tx.outputs, datum.owner)
        let owner_inputs = utils.get_inputs_by_vkh(tx.inputs, datum.owner)

        let owner_outputs_lovelace_balance = utils.get_ada_from_outputs(owner_outputs)
        let owner_inputs_lovelace_balance = utils.get_ada_from_inputs(owner_inputs)


        // Contract must have only one output everytime
        expect True = list.length(contract_outputs) == 1
        expect Some(contract_output) = list.at(contract_outputs, 0)

        // Getting the output's datum
        expect InlineDatum(untyped_datum) = contract_output.datum
        expect contract_output_datum: Datum = untyped_datum

        // Only the owner specified in the datum during the first initialization can interact with this contract
        expect Some(signer) = list.at(tx.extra_signatories, 0)
        expect True = signer == datum.owner

        // Owner cannot change during contract's lifespan
        expect True = contract_output_datum.owner == datum.owner

        when ctx.purpose is {
            Spend(_) -> {

                when redeemer is {
                    Deposit(amount) -> {
                        and {
                            // The whole datum must not change at all during the deposit
                            contract_output_datum == datum,

                            // Contract must receive the declared amount
                            contract_outputs_lovelace_balance == contract_inputs_lovelace_balance + amount
                        }
                    }

                    CreateTransaction(transaction) -> {
                        // The new transaction has to be appended to the transactions list in the new datum
                        expect Some(inserted_transaction) = list.last(contract_output_datum.transactions)

                        let other_transactions = list.take(contract_output_datum.transactions, (list.length(contract_output_datum.transactions)-1))
                        
                        and {
                            // Transaction value must be greater than 0
                            transaction.value > 0,

                            // The declared transaction has to be coherent with the one inserted in the datum
                            inserted_transaction == transaction,

                            // The new transaction must be marked as not executed yet
                            inserted_transaction.is_executed == False,

                            // All the previous transactions inside the updated list must not have been altered
                            other_transactions == datum.transactions,
                        }
                    }

                    SubmitTransaction(id) -> {
                        expect Some(old_datum_required_transaction) = list.at(datum.transactions, id)
                        expect Some(new_datum_required_transaction) = list.at(contract_output_datum.transactions, id)

                        let old_datum_other_transactions = remove_at(datum.transactions, id)
                        let new_datum_other_transactions = remove_at(contract_output_datum.transactions, id)

                        // Required transaction must not have been already executed 
                        expect True = old_datum_required_transaction.is_executed == False

                        let expected_transaction = Transaction {
                            to: old_datum_required_transaction.to,
                            value: old_datum_required_transaction.value,
                            data: old_datum_required_transaction.data,
                            is_executed: True
                        }

                        // Required transaction must be marked as executed
                        expect True = new_datum_required_transaction == expected_transaction

                        // The other transactions must have not been updated
                        expect True = new_datum_other_transactions == old_datum_other_transactions

                        let recipient_outputs = utils.get_outputs_by_vkh(tx.outputs, new_datum_required_transaction.to)
                        let recipient_outputs_lovelace_balance = utils.get_ada_from_outputs(recipient_outputs)

                        and {
                            // From this contract's UTxO, only the declared value has to be moved away
                            contract_outputs_lovelace_balance == contract_inputs_lovelace_balance - new_datum_required_transaction.value,

                            // Recipient is receiving the correct amount
                            recipient_outputs_lovelace_balance == new_datum_required_transaction.value // Note: if owner is also the recipient, this may fail
                        }
                    }

                    Withdraw(safety_change_amount) -> {
                        and {
                             // Datum must not change at all
                            contract_output_datum == datum,

                            // Owner is withdrawing the contract's full amount but is giving back the safety change amount in order to produce a contract's output
                            contract_outputs_lovelace_balance == safety_change_amount,
                    
                            safety_change_amount < contract_inputs_lovelace_balance, // we assume this amount to be lower than the contract's amount

                            owner_outputs_lovelace_balance == owner_inputs_lovelace_balance + contract_inputs_lovelace_balance - value.lovelace_of(tx.fee) - safety_change_amount
                        }
                    }
                }
            }

            _ -> False
        }
    }
}

// ////////////////////////////////////////////////////////////////////////////////