import {
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
    getTransactionFees,
    printParticipants,
} from './utils';

import path from 'path';
import { Buffer } from 'buffer';
const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../contracts/dist/storage/storage-keypair.json');

enum Action {
    StoreBytes = 0,
    StoreString = 1,
}

const SEED_STORAGE_BYTES = "storage_bytes";
const SEED_STORAGE_STRING = "storage_string";

let feesToStoreBytes = 0;
let feesToStoreString = 0;

async function main() {

    const connection = getConnection();

    const programId = await getPublicKeyFromFile(PROGRAM_KEYPAIR_PATH);
    const kpSender = await generateKeyPair(connection, 1);

    await printParticipants(connection, programId, [["sender", kpSender.publicKey]]);

    // 1. Store bytes
    console.log("\n--- Store bytes ---");
    const sequences = generateByteSequences();
    for (let i = 0; i < sequences.length; i++) {
        const sequence = sequences[i];
        console.log("    Storing bytes:   ", sequence);
        await storeBytes(
            connection,
            programId,
            kpSender,
            sequence);
    }

    // 2. Store string
    console.log("\n--- Store string ---");
    const stringsToStore = generateStringSequences();
    for (let i = 0; i < stringsToStore.length; i++) {
        const s = stringsToStore[i];
        console.log("    Storing string:   ", s);
        await storeString(
            connection,
            programId,
            kpSender,
            s);
    }

    // Get the data from the account to confirm the result
    const [byte_sequence, text_string] = await getState(connection, programId);
    console.log("\nFinal bytes:   ", byte_sequence);
    console.log("Final string:  ", text_string);

    // Costs
    console.log("\n........");
    console.log("Fees to store bytes:      ", feesToStoreBytes / LAMPORTS_PER_SOL, "SOL");
    console.log("Fees to store string:     ", feesToStoreString / LAMPORTS_PER_SOL, "SOL");
    console.log("Total fees:               ", (feesToStoreBytes + feesToStoreString) / LAMPORTS_PER_SOL, "SOL");
}

main().then(
    () => process.exit(),
    err => {
        console.error(err);
        process.exit(-1);
    }
);

async function storeBytes(
    connection: Connection,
    programId: PublicKey,
    kpSender: Keypair,
    bytesToStore: Buffer
): Promise<void> {

    const storagePDAPubKey = await getStorageBytesPDA(programId);

    const transaction = new Transaction().add(
        new TransactionInstruction({
            programId: programId,
            keys: [
                { pubkey: kpSender.publicKey, isSigner: true, isWritable: false },
                { pubkey: storagePDAPubKey, isSigner: false, isWritable: true },
                { pubkey: SystemProgram.programId, isSigner: false, isWritable: false }
            ],
            data: Buffer.from(new Uint8Array([Action.StoreBytes, ...bytesToStore])),
        })
    );

    const signature = await sendAndConfirmTransaction(connection, transaction, [kpSender]);
    await connection.confirmTransaction(signature);
    
    const tFees = await getTransactionFees(transaction, connection);
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, "SOL\n");
    feesToStoreBytes += tFees;
}

async function storeString(
    connection: Connection,
    programId: PublicKey,
    kpSender: Keypair,
    stringToStore: string
): Promise<void> {
    const storagePDAPubKey = await getStorageStringPDA(programId);

    const transaction = new Transaction().add(
        new TransactionInstruction({
            programId: programId,
            keys: [
                { pubkey: kpSender.publicKey, isSigner: true, isWritable: false },
                { pubkey: storagePDAPubKey, isSigner: false, isWritable: true },
                { pubkey: SystemProgram.programId, isSigner: false, isWritable: false }
            ],
            data: Buffer.from(new Uint8Array([Action.StoreString, ...Buffer.from(stringToStore)])),
        })
    );

    const signature = await sendAndConfirmTransaction(connection, transaction, [kpSender]);
    await connection.confirmTransaction(signature);

    const tFees = await getTransactionFees(transaction, connection);
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL\n');
    feesToStoreString += tFees;
}

async function getStorageBytesPDA(programId: PublicKey): Promise<PublicKey> {
    const [walletPDA] = await PublicKey.findProgramAddress(
        [Buffer.from(SEED_STORAGE_BYTES)],
        programId
    );
    return walletPDA;
}

async function getStorageStringPDA(programId: PublicKey): Promise<PublicKey> {
    const [walletPDA] = await PublicKey.findProgramAddress(
        [Buffer.from(SEED_STORAGE_STRING)],
        programId
    );
    return walletPDA;
}

function generateByteSequences() {
    const sequences = [];
    sequences.push(Buffer.from([1]));
    sequences.push(Buffer.from([1, 2]));
    sequences.push(Buffer.from([1, 2, 3]));
    sequences.push(Buffer.from([1, 2, 3, 4]));
    sequences.push(Buffer.from([1, 2, 3, 4, 5]));
    return sequences;
}

function generateStringSequences() {
    const sequences = [];
    sequences.push("a");
    sequences.push("ab");
    sequences.push("abc");
    sequences.push("abcd");
    sequences.push("abcde");
    return sequences;
}

async function getState(connection: Connection, programId: PublicKey): Promise<[Buffer, string]> {
    const storageBytesPDAPubKey = await getStorageBytesPDA(programId);
    const storageStringPDAPubKey = await getStorageStringPDA(programId);

    const bytesAccount = await connection.getAccountInfo(storageBytesPDAPubKey);
    const stringAccount = await connection.getAccountInfo(storageStringPDAPubKey);

    if (bytesAccount === null) {
        throw 'Error: cannot find the bytes account';
    }
    if (stringAccount === null) {
        throw 'Error: cannot find the string account';
    }

    return [bytesAccount.data, Buffer.from(stringAccount.data).toString('utf8')];
}