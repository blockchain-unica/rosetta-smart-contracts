use aiken/hash.{Blake2b_224, Hash}
use aiken/int
use aiken/list
use aiken/option
use aiken/transaction.{ScriptContext}
use aiken/transaction/value
use aiken/transaction/credential

type Datum {
}

type Redeemer {
  amount: Int,
}

validator {
  fn simple_transfer(
    datum: Datum,
    redeemer: Redeemer,
    context: ScriptContext,
  ) -> Bool {
    expect Spend(ctxo) = context.purpose

    let Transaction {
      inputs,
      reference_inputs,
      outputs,
      extra_signatories,
      ..
    } = context.transaction

    expect Some(out0) = at(outputs,0) // out0 preserves the covenant
    expect Some(out1) = at(outputs,1) // out1 transfers ADAs to anyone

    expect Some(own_input) =
      list.find(inputs, fn(input) { input.output_reference == ctxo })

    let Output { address: in_address, value: ctxo_val, .. } =
      own_input.output

    // todo: better handling of value
    let must_split =
      redeemer.msg == out1.value && out0.value + out1.value + context.transaction.fee == ctxo_val

    // recursive covenant in out0
    let must_preserve_script =
      out0.address == in_address
    
    expect [signer] = context.transaction.extra_signatories 
    
    expect Address {
      payment_credential: VerificationKeyCredential(pkhash),
      ..
    } = out1.address

    let must_be_signed = 
      pkhash == signer

    must_split && must_preserve_script && must_be_signed

  }
}

test foo() {
  1 + 1 == 2
}
