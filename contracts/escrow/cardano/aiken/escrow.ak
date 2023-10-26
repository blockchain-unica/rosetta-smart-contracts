// ////////////////////////////////////////////////////////////////////////////////

/// Partecipants
/// - seller (S)
/// - buyer  (B)

/// Transactions
/// - create-contract 
///     input:  (minimum ADA amount for creating the tx)
///     output: UTXO_1 + datum=(seller, buyer, amount, status=empty)
/// - deposit
///     input:  UTXO_1
///     input:  amount // from buyer's UTXOs
///     output: UTXO_2 + datum=(seller, buyer, amount, status=deposited) // datum's static parts must be the same
/// - pay
///     input:  UTXO_2
///     output: UTXO_3 // this one fully belongs to (S)
/// - refund
///     input:  UTXO_2
///     output: UTXO_3 // this one fully belongs to (B)

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Imports:
// ////////////////////////////////////////////////////////////////////////////////

use aiken/list

use aiken/transaction.{Transaction, ScriptContext, Spend, InlineDatum}

// use aiken/cbor // diagnostic

use escrow/utils.{VerificationKeyHash}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Types: 
// ////////////////////////////////////////////////////////////////////////////////

type Datum {
    seller: VerificationKeyHash, // static
    buyer: VerificationKeyHash,  // static
    amount: Int,                 // static
    status: Status               // dynamic
}

type Action { // this one is the actual redeemer
    Deposit
    Pay
    Refund
}

type Status {
    Empty
    Deposited
}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Helping functions and validator:
// ////////////////////////////////////////////////////////////////////////////////

/// ***
/// @funct has_transaction_n_output_addresses
/// @brief - Checks if there are exactly n addresses in the transaction's outputs list
/// @param transaction
/// @param n - The number of addresses the transaction should have in its outputs
/// @return Bool - True if the transaction's outputs' addresses list contains exactly n unique elements, False otherwise
/// *** 
fn has_transaction_n_output_addresses(transaction: Transaction, n: Int) -> Bool {
    let number_of_output_addresses = 
    list.foldl(transaction.outputs , [], fn(x, xs) { list.push(xs, x.address) }) // list of addresses
    |> list.unique(_)
    |> list.length(_)

    number_of_output_addresses == n
}


validator {
    fn escrow(datum: Datum, redeemer: Action, ctx: ScriptContext) {
        let tx = ctx.transaction

        let own_input = utils.get_own_input(ctx)
        let contract_address = own_input.output.address

        // A correct datum we expect to be when the status is Empty
        let empty_status_datum = Datum {
            seller: datum.seller,
            buyer: datum.buyer,
            amount: datum.amount,
            status: Empty 
        }

        // A correct datum we expect to be when the status is Deposited
        let deposit_status_datum = Datum {
            seller: datum.seller,
            buyer: datum.buyer,
            amount: datum.amount,
            status: Deposited
        }

        let contract_outputs = utils.get_outputs_by_address(tx.outputs, contract_address)
        
        // Spending conditions
        when ctx.purpose is {
            Spend(_) -> 
                when redeemer is  {
                    Deposit -> { 
                        expect True = utils.must_be_signed_by(tx, datum.buyer)

                        let buyer_outputs = utils.get_outputs_by_vkh(tx.outputs, datum.buyer)

                        // There must be exactly two addresses in the tx's outputs
                        expect True = has_transaction_n_output_addresses(tx, 2)

                        // One address is the contract
                        expect Some(contract_output) = list.at(contract_outputs, 0)
                        
                        // The other one is the buyer
                        expect Some(_buyer_output) = list.at(buyer_outputs, 0)

                        and {
                            // Deposit can be done iff status is Empty
                            own_input.output.datum == InlineDatum(empty_status_datum), 
                            
                            // Buyer must pay the specified amount
                            utils.get_ada_from_outputs(contract_outputs) == datum.amount,

                            // The new contract's datum must be the same as the previous one but with the Deposited status this time
                            contract_output.datum == InlineDatum(deposit_status_datum)
                        }
                    }
                    _ -> {
                        // Pay and Refund can only be done if the current status is Deposited
                        expect True = own_input.output.datum == InlineDatum(deposit_status_datum)

                        let buyer_outputs = utils.get_outputs_by_vkh(tx.outputs, datum.buyer)
                        let seller_outputs = utils.get_outputs_by_vkh(tx.outputs, datum.seller)

                        // The output of these transactions should be seller and buyer only
                        expect True = and {
                            has_transaction_n_output_addresses(tx, 2),
                            !list.is_empty(seller_outputs),
                            !list.is_empty(buyer_outputs)
                        }

                        when redeemer is {
                            Pay -> and {
                                utils.must_be_signed_by(tx, datum.buyer), // there's not need to be signed by the seller too
                                
                                // Seller must receive the amount declared in the datum
                                utils.get_ada_from_outputs(seller_outputs) == datum.amount
                            }
                            
                            Refund -> and {
                                utils.must_be_signed_by(tx, datum.seller),   

                                // Buyer must receive the amount declared in the datum
                                utils.get_ada_from_outputs(buyer_outputs) == datum.amount
                            }

                            _ -> False // this actually should never occur at this point
                        }
                    }
                }
            _ -> False
        }
    }
}

// ////////////////////////////////////////////////////////////////////////////////