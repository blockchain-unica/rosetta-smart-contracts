use aiken/interval.{Finite}
// ////////////////////////////////////////////////////////////////////////////////
// Imports:
// ////////////////////////////////////////////////////////////////////////////////

use aiken/list
use aiken/transaction.{InlineDatum, ScriptContext, Spend}
use aiken/transaction/value

use vesting/utils.{POSIXTime, VerificationKeyHash, Lovelace}

// use aiken/cbor // diagnostic

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Types: 
// ////////////////////////////////////////////////////////////////////////////////

type Datum {
	beneficiary: VerificationKeyHash,
	start_timestamp: POSIXTime,
	duration: POSIXTime,
	amount: Lovelace,
}

// ////////////////////////////////////////////////////////////////////////////////

type Redeemer {
	Release { amount: Lovelace }
}


// ////////////////////////////////////////////////////////////////////////////////
// Validator:
// ////////////////////////////////////////////////////////////////////////////////

validator {
	fn vesting(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) {
		let tx = ctx.transaction
		let own_input = utils.get_own_input(ctx)
		let contract_address = own_input.output.address

		let contract_outputs =
			utils.get_outputs_by_address(tx.outputs, contract_address)

		let contract_amount = value.lovelace_of(own_input.output.value)

		let beneficiary_inputs = 
			utils.get_inputs_by_vkh(tx.inputs, datum.beneficiary)

		let beneficiary_outputs = 
			utils.get_outputs_by_vkh(tx.outputs, datum.beneficiary)

		let tx_earliest_time =
			when tx.validity_range.lower_bound.bound_type is {
				Finite(x) -> x
				_ -> 0
			}

		// We compute the already relased amount by subtracting the own input's balance to the total amount
		let released = datum.amount - contract_amount

		let linear_vesting = fn (total_allocation: Lovelace, timestamp: POSIXTime) {
			// Aiken's compiler is extremely limited inside clause guards and cannot perform external scope accesses or arithmetics
			let min_vesting_time = datum.start_timestamp
			let max_vesting_time = datum.start_timestamp + datum.duration

			when timestamp is {
				t if t < min_vesting_time -> 0
				t if t > max_vesting_time -> total_allocation
				_ -> total_allocation * (timestamp - datum.start_timestamp) / datum.duration 
			}
		}
		
		when ctx.purpose is {
			Spend(_) -> {
				let Release(declared_amount) = redeemer // https://aiken-lang.org/language-tour/custom-types#destructuring
				let release_amount = linear_vesting(datum.amount, tx_earliest_time) - released // This is the amount beneficiary should take

				expect True = and {
					utils.must_be_signed_by(tx, datum.beneficiary)?,
	
					(declared_amount == release_amount)?, 
					
					// Beneficiary is receiving the correct amount (this is comprehensive of tx's fee):
					(utils.get_ada_from_outputs(beneficiary_outputs) == declared_amount + utils.get_ada_from_inputs(beneficiary_inputs) - value.lovelace_of(tx.fee))?,
				}

				if(declared_amount == contract_amount) {
					// If the beneficiary is reclaiming the full amount, there's not need to return something back to the contract and check its new datum
					True
				}
				else {
					// We expect a contract output (to receive the correct amount difference back when collecting from this contract)
					expect (list.length(contract_outputs) == 1)?
					expect Some(contract_output) = list.at(contract_outputs, 0)

					// Checking the new datum:
					expect InlineDatum(untyped_datum) = contract_output.datum
					expect contract_output_datum: Datum = untyped_datum

					// New output must not change datum
					(contract_output_datum == datum)?
				}
			}
			
			_ -> False
		}
  	}
}

// ////////////////////////////////////////////////////////////////////////////////
