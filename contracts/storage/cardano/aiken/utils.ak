// /////////////////////////////////////////////////////////////////////////////////////////////////////////
// Imports
// /////////////////////////////////////////////////////////////////////////////////////////////////////////

use aiken/list

use aiken/transaction.{ScriptContext, Transaction, Input, Output, Spend}
use aiken/transaction/credential.{Address}
use aiken/transaction/value

// use aiken/cbor // diagnostic

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

// /////////////////////////////////////////////////////////////////////////////////////////////////////////