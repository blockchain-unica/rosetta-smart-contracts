// ////////////////////////////////////////////////////////////////////////////////

/// Partecipants
/// - committer (C)
/// - receiver  (R)

/// Transactions
/// - create-contract
/// - reveal
/// - timeout

/// Validators
/// - reveal
/// - timeout

/// Trace 1
/// (C): create-contract(datum)    -> UTXO_1 (* this one is "contended" between (C) and (R) *)
/// (C): reveal(redeemer, UTXO_1)  -> UTXO_2 (* this one fully belongs to (C) *) 

/// Trace 2
/// (C): create-contract(datum)    -> UTXO_1 (* this one is "contended" between (C) and (R) *)
/// (C): timeout(redeemer, UTXO_1) -> UTXO_3 (* this one fully belongs to (R) *) 


// ////////////////////////////////////////////////////////////////////////////////
// Imports:
// ////////////////////////////////////////////////////////////////////////////////

use aiken/list
use aiken/hash.{Blake2b_224, Sha3_256, Hash, sha3_256}
use aiken/transaction/credential.{VerificationKey}
use aiken/transaction.{Transaction, ScriptContext, Spend, ValidityRange}
use aiken/interval.{Finite}

// ////////////////////////////////////////////////////////////////////////////////


// ////////////////////////////////////////////////////////////////////////////////
// Types: 
// ////////////////////////////////////////////////////////////////////////////////

type VerificationKeyHash = Hash<Blake2b_224, VerificationKey>
type SecretHash = Hash<Sha3_256, ByteArray>
type POSIXTime = Int

type Datum {
    committer: VerificationKeyHash,
    receiver: VerificationKeyHash,
    secret_hash: SecretHash,
    timeout: POSIXTime // we cannot access blocks and epochs on chain (source: Aiken's Discord)
}

type Redeemer {
    secret: ByteArray,
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
        when ctx.purpose is {
            Spend(_) -> 
            // (more like a XOR because they cannot happen simultaneously) 
            or { 
                // reveal:
                and { 
                    must_be_signed_by(ctx.transaction, datum.committer),
                    sha3_256(redeemer.secret) == datum.secret_hash,
                    !must_start_after(ctx.transaction.validity_range, datum.timeout)
                },
                // timeout:
                and { 
                    must_be_signed_by(ctx.transaction, datum.receiver),
                    must_start_after(ctx.transaction.validity_range, datum.timeout)
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