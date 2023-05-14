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
    keccak256FromString,
    printParticipants,
} from './utils';

import * as borsh from 'borsh';
import path from 'path';
import { Buffer } from 'buffer';

const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../solana/dist/htlc/htlc-keypair.json');

enum Action {
    Initialize = 0,
    Reveal = 1,
    Timeout = 2
}

class HTLCInfo {
    owner: Buffer = Buffer.alloc(32);
    verifier: Buffer = Buffer.alloc(32);
    hashed_secret: Buffer = Buffer.alloc(32);
    delay: number = 0;
    reveal_timeout: number = 0;

    constructor(fields: {
        owner: Buffer,
        verifier: Buffer,
        hashed_secret: Buffer,
        delay: number,
        reveal_timeout: number,
    } | undefined = undefined) {
        if (fields) {
            this.owner = fields.owner;
            this.verifier = fields.verifier;
            this.hashed_secret = fields.hashed_secret;
            this.delay = fields.delay;
            this.reveal_timeout = fields.reveal_timeout;
        }
    }

    static schema = new Map([
        [HTLCInfo, {
            kind: 'struct', fields: [
                ['owner', [32]],
                ['verifier', [32]],
                ['hashed_secret', [32]],
                ['delay', 'u64'],
                ['reveal_timeout', 'u64'],
            ]
        }],
    ]);
}

let feesForOwner = 0;
let feesForVerifier = 0;

// The amount of lamports that reppresent the minimum cost of the service of the contract
const minimumAmount = 0.1 * LAMPORTS_PER_SOL;

async function main() {

    const connection = getConnection();

    const programId = await getPublicKeyFromFile(PROGRAM_KEYPAIR_PATH);
    const kpOwner = await generateKeyPair(connection, 1);
    const kpVerifier = await generateKeyPair(connection, 1);

    await printParticipants(connection, programId, [
        ["owner", kpOwner.publicKey], 
        ["verifier", kpVerifier.publicKey],
    ]);

    /******************* Trace 1 *********************/
    console.log("\n---       Trace 1       ---");
    console.log("The committer creates the contract, setting a deadline of 100 rounds");

    let secret = "password123";
    let hashed_secret = await keccak256FromString(secret);
    let delaySlots = 100;

    let writingAccountPublicKey = await initialize(
        connection,
        programId,
        kpOwner,
        kpVerifier.publicKey,
        hashed_secret,
        delaySlots);

    console.log("\nAfter 50 rounds, the owner performs the reveal action.");

    let nSlotsToWait = 50;
    console.log("   Waiting", nSlotsToWait, "slots...");
    let currentSlot = await connection.getSlot();
    while (await connection.getSlot() < currentSlot + nSlotsToWait) {
        await new Promise(f => setTimeout(f, 1000));//sleep 1 second
    }

    await reveal(
        connection,
        programId,
        kpOwner,
        writingAccountPublicKey,
        secret);

    let feesForOwnerTrace1 = feesForOwner;
    let feesForVerifierTrace1 = feesForVerifier;

    // Reset fees
    feesForOwner = 0;
    feesForVerifier = 0;

    /******************* Trace 2 *********************/
    console.log("\n---       Trace 2       ---");
    console.log("The committer creates the contract, setting a deadline of 100 rounds");
    writingAccountPublicKey = await initialize(
        connection,
        programId,
        kpOwner,
        kpVerifier.publicKey,
        hashed_secret,
        delaySlots);

    console.log("\nAfter 100 rounds, the receiver performs the timeout action.");

    nSlotsToWait = 100;
    console.log("   Waiting", nSlotsToWait, "slots...");
    currentSlot = await connection.getSlot();
    while (await connection.getSlot() < currentSlot + nSlotsToWait) {
        await new Promise(f => setTimeout(f, 1000));//sleep 1 second
    }

    await timeout(
        connection,
        programId,
        kpVerifier,
        writingAccountPublicKey);

    let feesForOwnerTrace2 = feesForOwner;
    let feesForVerifierTrace2 = feesForVerifier;

    // Reset fees
    feesForOwner = 0;
    feesForVerifier = 0;

    console.log("\n........");
    console.log("\nTrace 1");
    console.log("Fees for owner:          ", feesForOwnerTrace1 / LAMPORTS_PER_SOL, "SOL");
    console.log("Fees for recipient:      ", feesForVerifierTrace1 / LAMPORTS_PER_SOL, "SOL");
    console.log("Total fees for Trace 1:  ", (feesForOwnerTrace1 + feesForVerifierTrace1) / LAMPORTS_PER_SOL, "SOL");
    console.log("\nTrace 2");
    console.log("Fees for owner:          ", feesForOwnerTrace2 / LAMPORTS_PER_SOL, "SOL");
    console.log("Fees for recipient:      ", feesForVerifierTrace2 / LAMPORTS_PER_SOL, "SOL");
    console.log("Total fees for Trace 2:  ", (feesForOwnerTrace2 + feesForVerifierTrace2) / LAMPORTS_PER_SOL, "SOL");

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
    kpSender: Keypair,
    kpRecipient: PublicKey,
    hashedBuffer: Buffer,
    delay: number,
): Promise<PublicKey> {
    let htlcInfo = new HTLCInfo({
        owner: kpSender.publicKey.toBuffer(),
        verifier: kpRecipient.toBuffer(),
        hashed_secret: Buffer.from(new Uint8Array(hashedBuffer)),
        delay,
        reveal_timeout: 0,
    });

    let data = borsh.serialize(HTLCInfo.schema, htlcInfo);
    let data_to_send = Buffer.from(new Uint8Array([Action.Initialize, ...data]));

    const SEED = "abcdef" + Math.random().toString();
    const writingAccountPublicKey = await PublicKey.createWithSeed(
        kpSender.publicKey,
        SEED,
        programId,
    );

    // Instruction to create the Writing Account account
    const rentExemptionAmount = await connection.getMinimumBalanceForRentExemption(data.length);
    const createWritingAccountInstruction = SystemProgram.createAccountWithSeed({
        fromPubkey: kpSender.publicKey,
        basePubkey: kpSender.publicKey,
        seed: SEED,
        newAccountPubkey: writingAccountPublicKey,
        lamports: rentExemptionAmount + minimumAmount,
        space: data.length,
        programId: programId,
    });

    let initInstruction = new TransactionInstruction({
        keys: [
            { pubkey: kpSender.publicKey, isSigner: true, isWritable: false },
            { pubkey: writingAccountPublicKey, isSigner: false, isWritable: true },
        ],
        programId,
        data: data_to_send,
    })

    // Instruction to the program
    const initTransaction = new Transaction().add(createWritingAccountInstruction).add(initInstruction);
    await sendAndConfirmTransaction(connection, initTransaction, [kpSender]);

    let tFees = await getTransactionFees(initTransaction, connection);
    feesForOwner += tFees;
    console.log('   Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');

    return writingAccountPublicKey;
}

async function reveal(
    connection: Connection,
    programId: PublicKey,
    kpSender: Keypair,
    writingAccountPublicKey: PublicKey,
    secret: string) {

    const revealTransaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: kpSender.publicKey, isSigner: true, isWritable: false },
                { pubkey: writingAccountPublicKey, isSigner: false, isWritable: true },
            ],
            programId,
            data: Buffer.from(new Uint8Array([Action.Reveal, ...Buffer.from(secret)]))
        }));
    await sendAndConfirmTransaction(connection, revealTransaction, [kpSender]);

    let tFees = await getTransactionFees(revealTransaction, connection);
    feesForOwner += tFees;
    console.log('   Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

async function timeout(
    connection: Connection,
    programId: PublicKey,
    kpVerifier: Keypair,
    writingAccountPublicKey: PublicKey) {

    let data_to_send = Buffer.from(new Uint8Array([Action.Timeout]));

    const revealTransaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: writingAccountPublicKey, isSigner: false, isWritable: true },
                { pubkey: kpVerifier.publicKey, isSigner: true, isWritable: false },
                { pubkey: kpVerifier.publicKey, isSigner: false, isWritable: true },
            ],
            programId,
            data: data_to_send,
        }));
    await sendAndConfirmTransaction(connection, revealTransaction, [kpVerifier]);

    let tFees = await getTransactionFees(revealTransaction, connection);
    feesForVerifier += tFees;
    console.log('   Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}