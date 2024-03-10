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

const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../contracts/dist/htlc/htlc-keypair.json');

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
        reveal_timeout: number,
    } | undefined = undefined) {
        if (fields) {
            this.owner = fields.owner;
            this.verifier = fields.verifier;
            this.hashed_secret = fields.hashed_secret;
            this.reveal_timeout = fields.reveal_timeout;
        }
    }

    static schema = new Map([
        [HTLCInfo, {
            kind: 'struct', fields: [
                ['owner', [32]],
                ['verifier', [32]],
                ['hashed_secret', [32]],
                ['reveal_timeout', 'u64'],
            ]
        }],
    ]);
}

let feesForOwner = 0;
let feesForVerifier = 0;

// The amount of lamports that represent the minimum cost of the service of the contract
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
    console.log("The owner submits the secret, setting a deadline of 100 rounds");

    let secret = "password123";
    let hashed_secret = await keccak256FromString(secret);
    let delaySlots = 100;

    await initialize(
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
        kpVerifier.publicKey,
        secret);

    let feesForOwnerTrace1 = feesForOwner;
    let feesForVerifierTrace1 = feesForVerifier;

    // Reset fees
    feesForOwner = 0;
    feesForVerifier = 0;

    /******************* Trace 2 *********************/
    console.log("\n---       Trace 2       ---");
    console.log("The owner submits the secret, setting a deadline of 100 rounds");
    await initialize(
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
        kpOwner,
        kpVerifier.publicKey);

    let feesForOwnerTrace2 = feesForOwner;
    let feesForVerifierTrace2 = feesForVerifier;

    // Reset fees
    feesForOwner = 0;
    feesForVerifier = 0;

    console.log("\n........");
    console.log("\nTrace 1");
    console.log("Fees for owner:          ", feesForOwnerTrace1 / LAMPORTS_PER_SOL, "SOL");
    console.log("Fees for verifier:      ", feesForVerifierTrace1 / LAMPORTS_PER_SOL, "SOL");
    console.log("Total fees for Trace 1:  ", (feesForOwnerTrace1 + feesForVerifierTrace1) / LAMPORTS_PER_SOL, "SOL");
    console.log("\nTrace 2");
    console.log("Fees for owner:          ", feesForOwnerTrace2 / LAMPORTS_PER_SOL, "SOL");
    console.log("Fees for verifier:      ", feesForVerifierTrace2 / LAMPORTS_PER_SOL, "SOL");
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
    kpOwner: Keypair,
    verifierPublickey: PublicKey,
    hashedBuffer: Buffer,
    delay: number,
): Promise<void> {
    const currentSlot = await connection.getSlot();

    let htlcInfo = new HTLCInfo({
        owner: kpOwner.publicKey.toBuffer(),
        verifier: verifierPublickey.toBuffer(),
        hashed_secret: Buffer.from(new Uint8Array(hashedBuffer)),
        reveal_timeout: delay + currentSlot
    });

    let data = borsh.serialize(HTLCInfo.schema, htlcInfo);
    let dataToSend = Buffer.from(new Uint8Array([Action.Initialize, ...data]));

    const htlcInfoPublickey = getHTLCInfoPDA(programId, kpOwner.publicKey, verifierPublickey);

    const initTransaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: kpOwner.publicKey, isSigner: true, isWritable: false },
                { pubkey: verifierPublickey, isSigner: false, isWritable: false},
                { pubkey: htlcInfoPublickey, isSigner: false, isWritable: true },
                { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
            ],
            programId,
            data: dataToSend,
        }));

    await sendAndConfirmTransaction(connection, initTransaction, [kpOwner]);

    let tFees = await getTransactionFees(initTransaction, connection);
    feesForOwner += tFees;
    console.log('   Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

async function reveal(
    connection: Connection,
    programId: PublicKey,
    kpOwner: Keypair,
    verifierPublickey: PublicKey,
    secret: string) {

    const htlcInfoPublickey = getHTLCInfoPDA(programId, kpOwner.publicKey, verifierPublickey);

    const revealTransaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: kpOwner.publicKey, isSigner: true, isWritable: false },
                { pubkey: htlcInfoPublickey, isSigner: false, isWritable: true },
                { pubkey: verifierPublickey, isSigner: false, isWritable: false },
            ],
            programId,
            data: Buffer.from(new Uint8Array([Action.Reveal, ...Buffer.from(secret)]))
        }));
    await sendAndConfirmTransaction(connection, revealTransaction, [kpOwner]);

    let tFees = await getTransactionFees(revealTransaction, connection);
    feesForOwner += tFees;
    console.log('   Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

async function timeout(
    connection: Connection,
    programId: PublicKey,
    kpOwner: Keypair,
    verifierPublicKey: PublicKey,) {

    let dataToSend = Buffer.from(new Uint8Array([Action.Timeout]));

    const htlcInfoPublickey = getHTLCInfoPDA(programId, kpOwner.publicKey, verifierPublicKey);

    const revealTransaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: htlcInfoPublickey, isSigner: false, isWritable: true },
                { pubkey: kpOwner.publicKey, isSigner: true, isWritable: false },
                { pubkey: verifierPublicKey, isSigner: false, isWritable: true },
            ],
            programId,
            data: dataToSend,
        }));
    await sendAndConfirmTransaction(connection, revealTransaction, [kpOwner]);

    let tFees = await getTransactionFees(revealTransaction, connection);
    feesForVerifier += tFees;
    console.log('   Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

function getHTLCInfoPDA(programId: PublicKey, ownerPubKey: PublicKey, verifierPubKey: PublicKey): PublicKey {
    const [pda] = PublicKey.findProgramAddressSync(
        [ownerPubKey.toBuffer(), verifierPubKey.toBuffer()],
        programId
    );
    return pda;
}