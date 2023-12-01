#!/bin/sh

# Check if the name parameter is provided
if [ $# -eq 0 ]; then
  echo "Please provide a name as a parameter."
  exit 1
fi

name=$1

# On chain
cargo init contracts/$1 --lib 

content="[package]
name = \"$name\"
version = \"0.1.0\"
edition = \"2021\"

[features]
no-entrypoint = []

[dependencies]
borsh = \"0.9.3\"
borsh-derive = \"0.10.0\"
solana-program = \"~1.10.35\"

[dev-dependencies]
solana-program-test = \"~1.10.35\"
solana-sdk = \"~1.10.35\"

[lib]
name = \"$name\"
crate-type = [\"cdylib\", \"lib\"]"

echo "$content" > contracts/$name/Cargo.toml

content="use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint,
    entrypoint::ProgramResult,
    msg,
    program_error::ProgramError,
    pubkey::Pubkey,
};

entrypoint!(process_instruction);

pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    if instruction_data.len() == 0 {
        return Err(ProgramError::InvalidInstructionData);
    }
    Ok(())
}"

echo "$content" > contracts/$name/src/lib.rs


# Off chain
touch execution_traces/$1_flow.ts

content="import {
    Connection,
    Keypair,
    LAMPORTS_PER_SOL,
    PublicKey,
    SystemProgram,
    Transaction,
    TransactionInstruction,
    sendAndConfirmTransaction,
} from '@solana/web3.js';

import {
    generateKeyPair,
    getConnection,
    getPublicKeyFromFile,
    printParticipants,
} from './utils';

import path from 'path';

const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../contracts/dist/$1/$1-keypair.json');

async function main() {
    
    const connection = getConnection();

    const programId = await getPublicKeyFromFile(PROGRAM_KEYPAIR_PATH);
    const kpActor = await generateKeyPair(connection, 1);

    await printParticipants(connection, programId, [
        [\"actor\", kpActor.publicKey], 
    ]);
}

main().then(
    () => process.exit(),
    err => {
        console.error(err);
        process.exit(-1);
    }
);"

echo "$content" >  execution_traces/$1_flow.ts

echo "The new use cases was added successfully."


