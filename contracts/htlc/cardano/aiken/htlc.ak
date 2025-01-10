// Suggested stdlib version: 1.6.0 (https://github.com/aiken-lang/stdlib/releases/tag/1.6.0)

// ////////////////////////////////////////////////////////////////////////////////
// Imports:
// ////////////////////////////////////////////////////////////////////////////////

use aiken/list
use aiken/hash.{Sha3_256, Hash, sha3_256}
use aiken/transaction.{Transaction, ScriptContext, Spend, ValidityRange, Input}
use aiken/interval.{Finite}

use aiken/transaction/value

use htlc/utils.{VerificationKeyHash, POSIXTime}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Types: 
// ////////////////////////////////////////////////////////////////////////////////

type SecretHash = Hash<Sha3_256, ByteArray>

type Datum {
    committer: VerificationKeyHash,
    receiver: VerificationKeyHash,
    secret_hash: SecretHash,
    timeout: POSIXTime // we cannot access blocks and epochs on chain
}

type Redeemer {
    Reveal { secret: ByteArray }
    Timeout
}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Validator:
// ////////////////////////////////////////////////////////////////////////////////

fn must_be_signed_by(transaction: Transaction, vk: VerificationKeyHash) {
    list.has(transaction.extra_signatories, vk)
} 

fn must_start_after(range: ValidityRange, timeout: POSIXTime) {
  when range.lower_bound.bound_type is {
    Finite(tx_earliest_time) -> timeout <= tx_earliest_time
    _ -> False
  }
}

validator {
    fn htlc(datum: Datum, redeemer: Redeemer, ctx: ScriptContext)  {
        let tx = ctx.transaction

        expect Some(tx_signer) = list.at(tx.extra_signatories, 0)
        
        let tx_signer_inputs = utils.get_inputs_by_vkh(tx.inputs, tx_signer)
        let tx_signer_outputs = utils.get_outputs_by_vkh(tx.outputs, tx_signer)

        let tx_signer_inputs_ada = utils.get_ada_from_inputs(tx_signer_inputs)
        let tx_signers_outputs_ada = utils.get_ada_from_outputs(tx_signer_outputs)

        let own_input = utils.get_own_input(ctx)
        let tx_value = value.lovelace_of(own_input.output.value)

        when ctx.purpose is {
            Spend(_) -> {
                expect True = tx_signers_outputs_ada == tx_signer_inputs_ada + tx_value - value.lovelace_of(tx.fee)

                when redeemer is {
                    Reveal(secret) -> {
                        and {
                            must_be_signed_by(tx, datum.committer),
                            sha3_256(secret) == datum.secret_hash,
                            !must_start_after(tx.validity_range, datum.timeout)
                        }
                        
                    }
                    Timeout -> {
                        and {
                            must_be_signed_by(tx, datum.receiver),
                            must_start_after(tx.validity_range, datum.timeout)
                        }
                    }
                }       
            }                
            _ -> False
        }
    }
}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Tests:
// ////////////////////////////////////////////////////////////////////////////////

test sha3_256_is_equal_1(){
    let preimage: ByteArray = "test"
    let precomputed_hash: SecretHash = #"36f028580bb02cc8272a9a020f4200e346e276ae664e45ee80745574e2f5ab80" // https://aiken-lang.org/language-tour/primitive-types#3---as-a-hex-encoded-byte-string

    sha3_256(preimage) == precomputed_hash
}

// ////////////////////////////////////////////////////////////////////////////////