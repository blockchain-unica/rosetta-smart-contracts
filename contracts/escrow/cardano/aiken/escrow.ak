// ////////////////////////////////////////////////////////////////////////////////
// Imports:
// ////////////////////////////////////////////////////////////////////////////////

use aiken/list

use aiken/transaction.{Transaction, ScriptContext, Spend, InlineDatum}

// use aiken/cbor // diagnostic

use escrow/utils.{VerificationKeyHash, Lovelace}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Types: 
// ////////////////////////////////////////////////////////////////////////////////

type Datum {
    seller: VerificationKeyHash,
    buyer: VerificationKeyHash,
    escrow_amount: Lovelace,
    initialization_amount: Lovelace
}

type Redeemer {
    Deposit
    Pay
    Refund
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
    fn escrow(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) {
        let tx = ctx.transaction

        let own_input = utils.get_own_input(ctx)
        let contract_address = own_input.output.address

        let contract_outputs = utils.get_outputs_by_address(tx.outputs, contract_address)
        let contract_balance = utils.get_ada_from_inputs(utils.get_inputs_by_address(tx.inputs, contract_address))
        
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
                            // Deposit can be performed iff contract has not already been funded
                            contract_balance != datum.escrow_amount,
                            
                            // Buyer must deposit the specified amount and this value must coexist with the ADA paid by the seller to create the contract
                            utils.get_ada_from_outputs(contract_outputs) == datum.escrow_amount + datum.initialization_amount,

                            // New datum must not change
                            contract_output.datum == InlineDatum(datum)
                        }
                    }
                    _ -> {
                        // Pay and Refund can only be done if the contract has been funded
                        expect True = contract_balance == datum.escrow_amount + datum.initialization_amount

                        let buyer_outputs = utils.get_outputs_by_vkh(tx.outputs, datum.buyer)
                        let seller_outputs = utils.get_outputs_by_vkh(tx.outputs, datum.seller)

                        // The output of these transactions should be the seller and buyer only, meaning contract ceases its activity after this
                        expect True = and {
                            has_transaction_n_output_addresses(tx, 2),
                            !list.is_empty(seller_outputs),
                            !list.is_empty(buyer_outputs)
                        }

                        when redeemer is {
                            Pay -> and {
                                utils.must_be_signed_by(tx, datum.buyer),
                                
                                // Seller must receive the amount declared in the datum plus the initialization amount the seller has paid to create the contract
                                utils.get_ada_from_outputs(seller_outputs) == datum.escrow_amount + datum.initialization_amount
                            }
                            
                            Refund -> and {
                                utils.must_be_signed_by(tx, datum.seller),   

                                // Buyer must receive only the amount declared in the datum, doing so, seller should receive the initialization amount back
                                utils.get_ada_from_outputs(buyer_outputs) == datum.escrow_amount
                            }

                            _ -> False // invalid redeemer
                        }
                    }
                }
            _ -> False
        }
    }
}

// ////////////////////////////////////////////////////////////////////////////////