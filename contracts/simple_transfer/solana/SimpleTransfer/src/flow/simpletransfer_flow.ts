import {
    Connection,
    Keypair,
    LAMPORTS_PER_SOL,
    PublicKey,
    SystemProgram,
    BpfLoader,
    Transaction,
    TransactionInstruction,
    clusterApiUrl,
    sendAndConfirmTransaction,
    BPF_LOADER_PROGRAM_ID,
} from '@solana/web3.js';

import {
    getSystemKeyPair,
    getTransactionFees,
    getKeyPairFromFile,
} from './utils';

import * as borsh from 'borsh';
import path from 'path';
import { Buffer } from 'buffer';

const RECEIVER_KEYPAIR_PATH = path.resolve(__dirname, 'keypair-recipient.json');
const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../../dist/program/simpletransfer-keypair.json');

class DonationDetails {
    sender: Buffer = Buffer.alloc(32);
    recipient: Buffer = Buffer.alloc(32);
    amount: number = 0;

    constructor(fields: {
        sender: Buffer,
        recipient: Buffer,
        amount: number,
    } | undefined = undefined) {
        if (fields) {
            this.sender = fields.sender;
            this.recipient = fields.recipient;
            this.amount = fields.amount;
        }
    }

    static schema = new Map([
        [DonationDetails, {
            kind: 'struct', fields: [
                ['sender', [32]],
                ['recipient', [32]],
                ['amount', 'u64'],
            ]
        }],
    ]);

}

class WithdrawRequest {
    amount: number = 0;

    constructor(fields: {
        amount: number,
    } | undefined = undefined) {
        if (fields) {
            this.amount = fields.amount;
        }
    }

    static schema = new Map([
        [WithdrawRequest, {
            kind: 'struct', fields: [
                ['amount', 'u64'],
            ]
        }],
    ]);

}

let feesForSender = 0;
let feesForRecipient = 0;
let feesFordeDloyer = 0;

async function main() {

    const connection = new Connection(clusterApiUrl("testnet"), "confirmed");
    //const connection = new Connection(clusterApiUrl("devnet"), "confirmed");
    //const connection = new Connection('http://localhost:8899', "confirmed");

    const kpPayer = await getSystemKeyPair();
    const kpRecipient = Keypair.generate();

    const recepientAccount = await connection.getAccountInfo(kpRecipient.publicKey);
    if (recepientAccount === null) {
        await connection.requestAirdrop(
            kpRecipient.publicKey,
            LAMPORTS_PER_SOL
          );
    }

    console.log("owner:     ", kpPayer.publicKey.toBase58());
    console.log("recipient: ", kpRecipient.publicKey.toBase58());
    console.log("\n");

    // 1. Set recipient and deploy
    console.log("--- Deploy. Actor: the owner ---");
    //const pathToBinary = path.resolve(__dirname, '../../dist/program/simpletransfer.so');
    //const programId: PublicKey = await deploy(connection, kpPayer, pathToBinary);

    const programKeypair = await getKeyPairFromFile(PROGRAM_KEYPAIR_PATH);
    const programId: PublicKey = programKeypair.publicKey;

    console.log('programId: ', programId.toBase58());

    // 2. Deposit money (the user deposits the amout equal to price)
    console.log("\n--- Deposit. Actor: the onwer ---");
    let amount = 0.1 * LAMPORTS_PER_SOL;

    const lamportsAddress = await deposit(
        connection,
        programId,
        kpPayer,
        kpRecipient.publicKey,
        amount);

    // 3. partial Whitdraw
    console.log("\n--- Partial Whitdraw. Actor: the recipient ---");
    await withdraw(
        connection,
        programId,
        kpRecipient,
        0.1 * amount,
        lamportsAddress);

    // 4. total Whitdraw
    console.log("\n--- Total Whitdraw. Actor: the recipient ---");
    await withdraw(
        connection,
        programId,
        kpRecipient,
        0.9 * amount,
        lamportsAddress);

    // total costs
    console.log("\n........");
    console.log("Total fees for deployment:              ", feesFordeDloyer / LAMPORTS_PER_SOL, " SOL");
    console.log("Total fees for sender (including rent): ", feesForSender / LAMPORTS_PER_SOL, " SOL");
    console.log("Total fees for recipient:               ", feesForRecipient / LAMPORTS_PER_SOL, " SOL");
    console.log("Total fees:                             ", (feesFordeDloyer + feesForSender + feesForRecipient) / LAMPORTS_PER_SOL, " SOL");

}

main().then(
    () => process.exit(),
    err => {
        console.error(err);
        process.exit(-1);
    },
);

export async function deploy(
    connection: Connection,
    kpPayer: Keypair,
    pathToBinary: string,
): Promise<PublicKey> {

    const prevBalance = await connection.getBalance(kpPayer.publicKey);

    const fs = require("fs");
    const programBinary = fs.readFileSync(pathToBinary);
    const programBase64 = Buffer.from(programBinary);

    const kpProgram = Keypair.generate();

    let success = await BpfLoader.load(
        connection,
        kpPayer,
        kpProgram,
        programBase64,
        BPF_LOADER_PROGRAM_ID
    );

    if (success) {
        console.log("Program deployed with account", kpProgram.publicKey.toBase58());
    } else {
        throw new Error("Program deployment failed");
    }

    const currentBaance = await connection.getBalance(kpPayer.publicKey);
    feesFordeDloyer = prevBalance - currentBaance;

    return kpProgram.publicKey;
}

export async function deposit(
    connection: Connection,
    programId: PublicKey,
    kpPayer: Keypair,
    kpRecipient: PublicKey,
    amount: number,
)
    : Promise<PublicKey> {
    let donation = new DonationDetails(
        {
            sender: kpPayer.publicKey.toBuffer(),
            recipient: kpRecipient.toBuffer(),
            amount: amount
        }
    );

    let data = borsh.serialize(DonationDetails.schema, donation);
    let data_to_send = Buffer.from(new Uint8Array([0, ...data]));

    const SEED = "abcdef" + Math.random().toString();
    const writingAccountPublicKey = await PublicKey.createWithSeed(
        kpPayer.publicKey,
        SEED,
        programId,
    );

    const rentExemptionAmount =
        (await connection.getMinimumBalanceForRentExemption(data.length));

    const transaction = new Transaction().add(
        SystemProgram.createAccountWithSeed({
            fromPubkey: kpPayer.publicKey,
            basePubkey: kpPayer.publicKey,
            seed: SEED,
            newAccountPubkey: writingAccountPublicKey,
            lamports: rentExemptionAmount,
            space: data.length,
            programId: programId,
        }));
    await sendAndConfirmTransaction(connection, transaction, [kpPayer]);
    let tFees = await getTransactionFees(transaction, connection);

    feesForSender += rentExemptionAmount;
    console.log('Rent fees:        ', rentExemptionAmount / LAMPORTS_PER_SOL, ' SOL');

    feesForSender += tFees;
    console.log('Transaction fees: ', tFees / LAMPORTS_PER_SOL, ' SOL');

    const SEED2 = "abcdef" + Math.random().toString();
    let lamportsHolderAccountPublicKey = await PublicKey.createWithSeed(
        kpPayer.publicKey,
        SEED2,
        programId
    );

    const transactionLamportsAccount = new Transaction().add(
        SystemProgram.createAccountWithSeed({
            fromPubkey: kpPayer.publicKey,
            basePubkey: kpPayer.publicKey,
            seed: SEED2,
            newAccountPubkey: lamportsHolderAccountPublicKey,
            lamports: amount,
            space: 1,
            programId: programId,
        }));
    await sendAndConfirmTransaction(connection, transactionLamportsAccount, [kpPayer]);
    tFees = await getTransactionFees(transactionLamportsAccount, connection);
    feesForSender += tFees;
    console.log('Transaction fees: ', tFees / LAMPORTS_PER_SOL, ' SOL');

    const transacrionDeposit = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: writingAccountPublicKey, isSigner: false, isWritable: true },
                { pubkey: lamportsHolderAccountPublicKey, isSigner: false, isWritable: true },
                { pubkey: kpPayer.publicKey, isSigner: true, isWritable: false },
            ],
            programId,
            data: data_to_send,
        }));
    await sendAndConfirmTransaction(
        connection,
        transacrionDeposit,
        [kpPayer],
    );
    tFees = await getTransactionFees(transacrionDeposit, connection);
    feesForSender += tFees;
    console.log('Transaction fees: ', tFees / LAMPORTS_PER_SOL, ' SOL');
    return writingAccountPublicKey;
}

export async function withdraw(
    connection: Connection,
    programId: PublicKey,
    kpRecipient: Keypair,
    amount: number,
    writingAccountPublicKey: PublicKey
): Promise<void> {

    let withdraw_request = new WithdrawRequest({ amount: amount });
    let data = borsh.serialize(WithdrawRequest.schema, withdraw_request);
    let data_to_send = Buffer.from(new Uint8Array([1, ...data]));

    const transaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: writingAccountPublicKey, isSigner: false, isWritable: true },
                { pubkey: kpRecipient.publicKey, isSigner: true, isWritable: false },
            ],
            programId,
            data: data_to_send,
        }));

    await sendAndConfirmTransaction(
        connection,
        transaction,
        [kpRecipient],
    );
    const tFees = await getTransactionFees(transaction, connection);
    feesForRecipient += tFees;
    console.log('Transaction fees: ', tFees / LAMPORTS_PER_SOL, ' SOL');
}