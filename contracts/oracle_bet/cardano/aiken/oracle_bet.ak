// ////////////////////////////////////////////////////////////////////////////////
// Imports:
// ////////////////////////////////////////////////////////////////////////////////

use aiken/list

use aiken/transaction.{ScriptContext, Spend, InlineDatum}

use aiken/interval.{Finite}

// use aiken/cbor // diagnostic

use oracle_bet/utils.{VerificationKeyHash, POSIXTime}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Types: 
// ////////////////////////////////////////////////////////////////////////////////

type Datum {
    oracle: VerificationKeyHash,
    player_1: VerificationKeyHash,
    player_2: VerificationKeyHash,
    deadline: POSIXTime,
    winner: VerificationKeyHash,
    status: Status,
    has_player_1_reclaimed: Bool,
    has_player_2_reclaimed: Bool
}

type Redeemer {
    Stipulate // player_1 stipulates the contract after the creation
    Join      // player_2 joins the contract
    Choose    // oracle chooses winner
    Redeem    // winner redeems the tokens
    Reclaim   // players reclaim their tokens back
}

type Status {
    WAITING_FOR_PLAYER_1
    WAITING_FOR_PLAYER_2
    WAITING_FOR_ORACLE
    DONE
}

// Creation suggestions:
// Player 1 creates the contract
// -- expected datum:
//      oracle:                 null
//      player_1:               player_1
//      player_2:               null
//      winner:                 null
//      deadline:               0 
//      status:                 WAITING_FOR_PLAYER_1
//      has_player_1_reclaimed: False,
//      has_player_2_reclaimed: False

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Helping functions and validator:
// ////////////////////////////////////////////////////////////////////////////////


validator {
    fn oracle_bet(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) {

        let tx = ctx.transaction

        let tx_earliest_time =
			when tx.validity_range.lower_bound.bound_type is {
				Finite(x) -> x
				_ -> 0
			}

        // Contract
        let own_input = utils.get_own_input(ctx)
        let contract_address = own_input.output.address
        
        let contract_outputs = utils.get_outputs_by_address(tx.outputs, contract_address)
        let contract_inputs = utils.get_inputs_by_address(tx.inputs, contract_address) 

        let contract_inputs_lovelace_balance = utils.get_ada_from_inputs(contract_inputs)
        let contract_outputs_lovelace_balance = utils.get_ada_from_outputs(contract_outputs)

        let contract_inputs_token_balance = utils.get_tokens_balance_from_inputs(contract_inputs)
        let contract_outputs_token_balance = utils.get_tokens_balance_from_outputs(contract_outputs)
        //

        expect Some(tx_signer) = list.at(tx.extra_signatories, 0)

        // Contract must have only one output everytime
        expect True = list.length(contract_outputs) == 1
        expect Some(contract_output) = list.at(contract_outputs, 0)

        // Checking the datum:
        expect InlineDatum(untyped_datum) = contract_output.datum
        expect contract_output_datum: Datum = untyped_datum

        // After stipulation, datum's static parts must not change
        expect True =
            when redeemer is {
                Stipulate -> True // we don't care what happens here because we check for a good datum value in the Stipulate action validator
                _ -> {
                     and {
                        contract_output_datum.oracle == datum.oracle,
                        contract_output_datum.player_1 == datum.player_1,
                        contract_output_datum.player_2 == datum.player_2,
                        contract_output_datum.deadline == datum.deadline
                    }   
                }
            }

        // Winner must change only during Choose action
        expect True =
            when redeemer is {
                Choose -> True
                _ -> contract_output_datum.winner == datum.winner
            }

        // This datum's part must change only during Reclaim action
        expect True =
            when redeemer is {
                Reclaim -> True
                _ -> {
                     and {
                        contract_output_datum.has_player_1_reclaimed == datum.has_player_1_reclaimed,
                        contract_output_datum.has_player_2_reclaimed == datum.has_player_2_reclaimed
                    }   
                }
            }


        when ctx.purpose is {
            Spend(_) -> {
                // No ADA must be taken away from this contract: tokens only
                expect True = contract_outputs_lovelace_balance >= contract_inputs_lovelace_balance

                when redeemer is {
                    Stipulate -> {
                        let expected_datum_after_creation = Datum {
                            oracle: "",
                            player_1: tx_signer, // only player_1 can perform this action
                            player_2: "",
                            winner: "",
                            deadline: 0,
                            status: WAITING_FOR_PLAYER_1,
                            has_player_1_reclaimed: False,
                            has_player_2_reclaimed: False,
                        }

                        and {
                            // Contract has been created with a correct datum
                            datum == expected_datum_after_creation,

                            // player_1 is depositing 1 token inside the contract
                            contract_outputs_token_balance == contract_inputs_token_balance + 1,

                            // New datum must have correct values
                            contract_output_datum.oracle != contract_output_datum.player_1,
                            contract_output_datum.oracle != contract_output_datum.player_2,
                            contract_output_datum.player_1 != contract_output_datum.player_2,

                            contract_output_datum.deadline > tx_earliest_time, 

                            // New datum must update status 
                            contract_output_datum.status == WAITING_FOR_PLAYER_2
                        }
                    }

                    Join -> {
                        and {
                            // Only player_2 can perform this action
                            tx_signer == datum.player_2,

                            contract_output_datum.deadline > tx_earliest_time,

                            // player_2 is depositing one token
                            contract_outputs_token_balance == contract_inputs_token_balance + 1,

                            // player_2 is correctly changing the status
                            contract_output_datum.status == WAITING_FOR_ORACLE
                        }
                    }

                    Choose -> {
                        and {
                            // Only oracle can perform this action
                            tx_signer == datum.oracle,

                            datum.status == WAITING_FOR_ORACLE,

                            contract_output_datum.deadline > tx_earliest_time,

                            // oracle is not altering the token balance
                            contract_outputs_token_balance == contract_inputs_token_balance,

                            // oracle has to choose a winner among the two players
                            or {
                                contract_output_datum.winner == datum.player_1,
                                contract_output_datum.winner == datum.player_2
                            },

                            // oracle must change to correct status
                            contract_output_datum.status == DONE
                        }
                    }

                    Redeem -> {
                        and {
                            // Only winner can perform this action
                            tx_signer == datum.winner,

                            datum.status == DONE,

                            // winner is redeeming the correct amount
                            contract_outputs_token_balance == contract_inputs_token_balance - 2,
                        }
                    }

                    Reclaim -> {
                        when datum.status is {
                            WAITING_FOR_PLAYER_2 -> {
                                and {
                                    tx_signer == datum.player_1,
                                    contract_output_datum.deadline < tx_earliest_time

                                    // There's not need to check datum.has_player_1_reclaimed, because Cardano protocol does this (double spending)
                                }
                            }

                            WAITING_FOR_ORACLE -> {
                                let player_1 = datum.player_1
                                let player_2 = datum.player_2

                                // players are reclaiming only 1 token
                                expect True = contract_outputs_token_balance == contract_inputs_token_balance - 1

                                when tx_signer is {
                                    p1 if p1 == player_1 -> {
                                        and {
                                            datum.has_player_1_reclaimed == False,

                                            // Must update datum in this way
                                            contract_output_datum.has_player_1_reclaimed == True,

                                            // Must not ruin other player's reclaiming chance
                                            contract_output_datum.has_player_2_reclaimed == datum.has_player_2_reclaimed
                                        }
                                    }

                                    p2 if p2 == player_2 -> {
                                        and {
                                            datum.has_player_2_reclaimed == False,

                                            // Must update datum in this way
                                            contract_output_datum.has_player_2_reclaimed == True,

                                            // Must not ruin other player's reclaiming chance
                                            contract_output_datum.has_player_1_reclaimed == datum.has_player_1_reclaimed
                                        }
                                    }
                                    
                                    _ -> False
                                }
                                
                            }

                            _ -> False
                        }
                    }
                }
            }

            _ -> False
        }
    }
}

// ////////////////////////////////////////////////////////////////////////////////