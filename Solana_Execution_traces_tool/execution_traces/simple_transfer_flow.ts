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
    buildBufferFromActionAndNumber,
    generateKeyPair,
    getPublicKeyFromFile,
    getTransactionFees,
} from './utils';

import * as borsh from 'borsh';
import path from 'path';
import { Buffer } from 'buffer';

const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../solana/dist/simple_transfer/simple_transfer-keypair.json');

enum Action {
    Deposit = 0,
    Withdraw = 1
}

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

let feesForSender = 0;
let feesForRecipient = 0;

async function main() {
    
    const connection = new Connection(clusterApiUrl("testnet"), "confirmed");

    const programId = await getPublicKeyFromFile(PROGRAM_KEYPAIR_PATH);
    const kpSender = await generateKeyPair(connection, 1);
    const kpRecipient = await generateKeyPair(connection, 1);

    console.log("programId: ", programId.toBase58());
    console.log("sender:    ", kpSender.publicKey.toBase58());
    console.log("recipient: ", kpRecipient.publicKey.toBase58());

    // 1. Deposit money (the user deposits the amout equal to price)
    console.log("\n--- Deposit. Actor: the onwer ---");
    let amount = 0.2 * LAMPORTS_PER_SOL;
    const lamportsAddress = await deposit(
        connection,
        programId,
        kpSender,
        kpRecipient.publicKey,
        amount);

    // 2. Partial Whitdraw
    console.log("\n--- Partial Whitdraw. Actor: the recipient ---");
    await withdraw(
        connection,
        programId,
        kpRecipient,
        0.1 * amount,
        lamportsAddress);

    // 3. Total Whitdraw
    console.log("\n--- Total Whitdraw. Actor: the recipient ---");
    await withdraw(
        connection,
        programId,
        kpRecipient,
        0.9 * amount,
        lamportsAddress);

    // Costs
    console.log("\n........");
    console.log("Fees for sender:    ", feesForSender / LAMPORTS_PER_SOL, " SOL");
    console.log("Fees for recipient: ", feesForRecipient / LAMPORTS_PER_SOL, " SOL");
    console.log("Total fees:         ", (feesForSender + feesForRecipient) / LAMPORTS_PER_SOL, " SOL");
}

main().then(
    () => process.exit(),
    err => {
        console.error(err);
        process.exit(-1);
    }
);

async function deposit(
    connection: Connection,
    programId: PublicKey,
    kpSender: Keypair,
    kpRecipient: PublicKey,
    amount: number,
): Promise<PublicKey> {
    let donation = new DonationDetails({
        sender: kpSender.publicKey.toBuffer(),
        recipient: kpRecipient.toBuffer(),
        amount: amount
    });

    let data = borsh.serialize(DonationDetails.schema, donation);
    let data_to_send = Buffer.from(new Uint8Array([Action.Deposit, ...data]));

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
        lamports: rentExemptionAmount + amount,
        space: data.length,
        programId: programId,
    });

    // Instruction to the program
    let depositInstruction = new TransactionInstruction({
        keys: [
            { pubkey: writingAccountPublicKey, isSigner: false, isWritable: true },
            { pubkey: kpSender.publicKey, isSigner: true, isWritable: false },
        ],
        programId,
        data: data_to_send,
    })

    const transactionDeposit = new Transaction().add(
        createWritingAccountInstruction,
        depositInstruction
    );

    await sendAndConfirmTransaction(connection, transactionDeposit, [kpSender]);

    let tFees = await getTransactionFees(transactionDeposit, connection);
    feesForSender += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, ' SOL');

    return writingAccountPublicKey;
}

async function withdraw(
    connection: Connection,
    programId: PublicKey,
    kpRecipient: Keypair,
    amount: number,
    writingAccountPublicKey: PublicKey
): Promise<void> {

    // Retrieve the state of the writing account to get the sender (in case the program will return the rent fees to the sender)
    const writingAccountInfo = await connection.getAccountInfo(writingAccountPublicKey);
    if (writingAccountInfo === null) {
        throw 'Error: cannot find the writing account';
    }
    const stateInfo = borsh.deserialize(DonationDetails.schema, DonationDetails, writingAccountInfo.data,);

    const transaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: new PublicKey(stateInfo.sender), isSigner: false, isWritable: true },
                { pubkey: kpRecipient.publicKey, isSigner: true, isWritable: false },
                { pubkey: writingAccountPublicKey, isSigner: false, isWritable: true },
            ],
            programId,
            data: buildBufferFromActionAndNumber(Action.Withdraw, amount)
        }));

    await sendAndConfirmTransaction(connection, transaction, [kpRecipient]);

    const tFees = await getTransactionFees(transaction, connection);
    feesForRecipient += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, ' SOL');
}