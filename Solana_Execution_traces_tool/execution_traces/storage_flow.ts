import {
    Connection,
    Keypair,
    LAMPORTS_PER_SOL,
    PublicKey,
    SystemProgram,
    Transaction,
    TransactionInstruction,
    clusterApiUrl,
    sendAndConfirmTransaction,
} from '@solana/web3.js';

import {
    generateKeyPair,
    getPublicKeyFromFile,
    getSystemKeyPair,
    getTransactionFees,
} from './utils';

import * as borsh from 'borsh';
import path from 'path';
import { Buffer } from 'buffer';

const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../solana/dist/storage/storage-keypair.json');

enum Action {
    Initialize = 0,
    StoreBytes = 1,
    StoreString = 2,
}

class StorageInfo {
    byte_sequence: Buffer;
    text_string: string;

    constructor(fields: {
        byte_sequence: Buffer,
        text_string: string,
    } | undefined = undefined) {
        if (fields) {
            this.byte_sequence = fields.byte_sequence;
            this.text_string = fields.text_string;
        }
    }

    static schema = new Map([
        [StorageInfo, {
            kind: 'struct', fields: [
                ['byte_sequence', [5]],
                ['text_string', 'string'],
            ]
        }],
    ]);
}

let feesForInitializer = 0;
let feestoStoreBytes = 0;
let feestoStoreString = 0;

async function main() {
    const connection = new Connection(clusterApiUrl("testnet"), "confirmed");

    const programId = await getPublicKeyFromFile(PROGRAM_KEYPAIR_PATH);
    const kpSender = await getSystemKeyPair();

    console.log("programId:  " + programId.toBase58());
    console.log("sender:    ", kpSender.publicKey.toBase58());

    // 0. Initialize
    console.log("\n--- Initialize ---");
    const initialBytes = Buffer.from([0, 0, 0, 0, 0]);
    const initialString = "initial";
    const stateAccountPubkey = await initialize(
        connection,
        programId,
        initialBytes,
        initialString);

    console.log("   State Account:  " + stateAccountPubkey.toBase58());
    console.log("   Initial bytes:   ", initialBytes);
    console.log("   Initial string:  ", initialString);

    // 1. Store bytes
    console.log("\n--- Store bytes ---");
    const bytesToStore = Buffer.from([1, 2, 3, 4, 5]);
    console.log("   Storing bytes:   ", bytesToStore);
    await storeBytes(
        connection,
        programId,
        kpSender,
        stateAccountPubkey,
        bytesToStore);

    // 2. Store string
    console.log("\n--- Store string ---");
    const stringToStore = "finalll";
    console.log("   Storing string:   ", stringToStore);
    await storeString(
        connection,
        programId,
        kpSender,
        stateAccountPubkey,
        stringToStore);

    // Get the data from the account to confirm the result
    const stateAccount = await connection.getAccountInfo(stateAccountPubkey);
    if (stateAccount === null) {
        throw 'Error: cannot find the state account';
    }
    const dserializeDdata = borsh.deserialize(
        StorageInfo.schema,
        StorageInfo,
        stateAccount.data,
    );

    console.log("\nFinal bytes:   ", dserializeDdata.byte_sequence);
    console.log("Final string:  ", dserializeDdata.text_string);

    // Costs
    console.log("\n........");
    console.log("Fees for initialization:  ", feesForInitializer / LAMPORTS_PER_SOL, " SOL");
    console.log("Fees to store bytes:      ", feestoStoreBytes / LAMPORTS_PER_SOL, " SOL");
    console.log("Fees to store string:     ", feestoStoreString / LAMPORTS_PER_SOL, " SOL");
    console.log("Total fees:               ", (feesForInitializer + feestoStoreBytes + feestoStoreString) / LAMPORTS_PER_SOL, " SOL");
}

main().then(
    () => process.exit(),
    err => {
        console.error(err);
        process.exit(-1);
    }
);

async function initialize(
    connection: Connection,
    programId: PublicKey,
    initialBytes: Buffer,
    initialString: string
): Promise<PublicKey> {

    const feePayer = await generateKeyPair(connection, 1);

    let storageInfo = new StorageInfo({
        byte_sequence: initialBytes,
        text_string: initialString,
    });
    let data = borsh.serialize(StorageInfo.schema, storageInfo);

    // Instruction to create the state account
    const SEED = "abcdef" + Math.random().toString();
    const stateAccountPubkey = await PublicKey.createWithSeed(feePayer.publicKey, SEED, programId);
    const size = data.length;
    const createStateAccountInstruction = SystemProgram.createAccountWithSeed({
        fromPubkey: feePayer.publicKey,
        basePubkey: feePayer.publicKey,
        seed: SEED,
        newAccountPubkey: stateAccountPubkey,
        lamports: await connection.getMinimumBalanceForRentExemption(size),
        space: size,
        programId: programId,
    });

    // Instruction to the program
    const data_to_send = Buffer.from(new Uint8Array([Action.Initialize, ...data]));
    const depositInstruction = new TransactionInstruction({
        programId: programId,
        keys: [{ pubkey: stateAccountPubkey, isSigner: false, isWritable: true }],
        data: data_to_send,
    });

    const initializeTransaction = new Transaction().add(
        createStateAccountInstruction,
        depositInstruction
    );

    await sendAndConfirmTransaction(
        connection,
        initializeTransaction,
        [feePayer]
    );

    feesForInitializer = await getTransactionFees(initializeTransaction, connection);

    return stateAccountPubkey;
}

async function storeBytes(
    connection: Connection,
    programId: PublicKey,
    kpSender: Keypair,
    stateAccountPubkey: PublicKey,
    bytesToStore: Buffer
): Promise<void> {

    const storeStringInstruction = new TransactionInstruction({
        programId: programId,
        data: Buffer.from(new Uint8Array([Action.StoreBytes, ...bytesToStore])),
        keys: [{ pubkey: stateAccountPubkey, isSigner: false, isWritable: true }]
    });

    const transaction = new Transaction().add(storeStringInstruction);

    await sendAndConfirmTransaction(
        connection,
        transaction,
        [kpSender]
    );

    feestoStoreBytes += await getTransactionFees(transaction, connection);

}

async function storeString(
    connection: Connection,
    programId: PublicKey,
    kpSender: Keypair,
    stateAccountPubkey: PublicKey,
    stringToStore: string
): Promise<void> {

    const storeStringInstruction = new TransactionInstruction({
        programId: programId,
        data: Buffer.from(new Uint8Array([Action.StoreString, ...Buffer.from(stringToStore)])),
        keys: [{ pubkey: stateAccountPubkey, isSigner: false, isWritable: true }]
    });

    const transaction = new Transaction().add(storeStringInstruction);

    await sendAndConfirmTransaction(
        connection,
        transaction,
        [kpSender]
    );

    feestoStoreString += await getTransactionFees(transaction, connection);

}