// /////////////////////////////////////////////////////////////////////////////////////////////////////////
// Imports
// /////////////////////////////////////////////////////////////////////////////////////////////////////////

use aiken/list

use aiken/hash.{Blake2b_224, Hash}

use aiken/transaction.{ScriptContext, Transaction, Input, Output, Spend}
use aiken/transaction/credential.{VerificationKey, VerificationKeyCredential, Address}

use aiken/transaction/value

// /////////////////////////////////////////////////////////////////////////////////////////////////////////


// /////////////////////////////////////////////////////////////////////////////////////////////////////////
// Types definition
// /////////////////////////////////////////////////////////////////////////////////////////////////////////

pub type VerificationKeyHash = Hash<Blake2b_224, VerificationKey>

// /////////////////////////////////////////////////////////////////////////////////////////////////////////


// /////////////////////////////////////////////////////////////////////////////////////////////////////////
// Public functions
// /////////////////////////////////////////////////////////////////////////////////////////////////////////

/// ***
/// @funct get_own_input
/// @brief - Returns the specific input being processed by the current contract's execution instance
/// @param ctx
/// @return input - The UTXO associated with the contract's execution
/// *** 
pub fn get_own_input(ctx: ScriptContext) -> Input {
  expect Spend(output_reference) = ctx.purpose

  expect Some(input) =
    list.find(
      ctx.transaction.inputs,
      fn(input) { input.output_reference == output_reference },
    )

  input
}


/// ***
/// @funct must_be_signed_by
/// @brief Checks if the provided Transaction is signed by the provided VerificationKeyHash
/// @param transaction
/// @param vk
/// @return Bool - True if the transaction contains vk in the signatories, False otherwise 
/// *** 
pub fn must_be_signed_by(transaction: Transaction, vk: VerificationKeyHash) {
    list.has(transaction.extra_signatories, vk)
} 


/// ***
/// @funct get_ada_from_outputs
/// @brief - Sums up all the lovelace values in the outputs list 
/// @param outputs
/// @return balance - The outputs' balance in lovelace
/// *** 
pub fn get_ada_from_outputs(outputs: List<Output>) -> Int {
    list.reduce(outputs, 0, fn(acc, output) { acc + value.lovelace_of(output.value) })
}


/// ***
/// @funct get_ada_from_inputs
/// @brief - Sums up all the lovelace values in the inputs list 
/// @param inputs
/// @return balance - The inputs' balance in lovelace
/// *** 
pub fn get_ada_from_inputs(inputs: List<Input>) -> Int {
    list.reduce(inputs, 0, fn(acc, input) { acc + value.lovelace_of(input.output.value) })
}


/// ***
/// @funct get_outputs_by_vkh
/// @brief - Keeps in the outputs list only the ones having vkh as their address
/// @param outputs
/// @param vkh
/// @return outputs - The Output list containing UTXOs own by vkh  
/// ***
pub fn get_outputs_by_vkh(outputs: List<Output>, vkc: VerificationKeyHash) -> List<Output> {
    list.filter(
        outputs,
        fn(output) { // filter function
            when output.address.payment_credential is {
                VerificationKeyCredential(_) -> {
                    // Performs the unsafe cast only if payment_credential has the type VerificationKeyCredential
                    expect VerificationKeyCredential(tx_output_address) = output.address.payment_credential

                    tx_output_address == vkc
                }
                _ -> False
            }
        }
    )
}


/// ***
/// @funct get_outputs_by_address
/// @brief - Keeps in the outputs list only the ones having addr as their address
/// @param outputs
/// @param addr
/// @return outputs - The Output list containing outputs own by addr
/// *** 
pub fn get_outputs_by_address(outputs: List<Output>, addr: Address) -> List<Output> {
    list.filter(
        outputs,
        fn(output) { output.address == addr }
    )
}


/// ***
/// @funct get_inputs_by_address
/// @brief - Keeps in the inputs list only the ones having addr as their address
/// @param inputs
/// @return List<Input> - The Input list containing inputs own by addr
/// *** 
pub fn get_inputs_by_address(inputs: List<Input>, addr: Address) {
    list.filter(
        inputs,
        fn (input) { input.output.address == addr }
    )
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////
