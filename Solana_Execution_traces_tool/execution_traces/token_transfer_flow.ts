import {
    Connection,
    Keypair,
    clusterApiUrl,
    Transaction,
    TransactionInstruction,
    SystemProgram,
    PublicKey,
    sendAndConfirmTransaction,
    LAMPORTS_PER_SOL,
} from '@solana/web3.js';

import {
    TOKEN_PROGRAM_ID,
    createInitializeAccountInstruction,
    createMint,
    getMinimumBalanceForRentExemptAccount,
    getOrCreateAssociatedTokenAccount,
    ACCOUNT_SIZE,
    mintTo,
    createTransferInstruction,
    getMint,
} from "@solana/spl-token";

import {
    getPublicKeyFromFile,
    getSystemKeyPair,
    getTransactionFees,
} from './utils';

import path from 'path';
import * as borsh from 'borsh';

const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../solana/dist/token_transfer/token_transfer-keypair.json');

enum Action { Deposit = 0, Withdraw = 1 }

let feesForSender = 0;
let feesForRecipient = 0;

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

async function main() {
    const connection = new Connection(clusterApiUrl("testnet"), "confirmed");

    const programId = await getPublicKeyFromFile(PROGRAM_KEYPAIR_PATH);
    const senderKeypair = await getSystemKeyPair();
    const recipientKeypair = Keypair.generate();

    console.log("programId:      " + programId.toBase58());
    console.log("Sender:        ", senderKeypair.publicKey.toBase58());
    console.log("Recipient:     ", recipientKeypair.publicKey.toBase58());

    // Setup
    const initialBalance = 100;
    const [mintPubkey, senderTokenAccountPubkey, recipientTokenAccountPubkey] = await setup(
        connection,
        senderKeypair,
        recipientKeypair,
        initialBalance
    );

    // 1. Deposit money (the user deposits the amout equal to price)
    console.log("\n--- Deposit. Actor: the onwer ---");
    const amountToSend = initialBalance / 2;
    const tempSenderTokenAccountPubKey = await deposit(
        connection,
        programId,
        mintPubkey,
        senderKeypair,
        senderTokenAccountPubkey,
        amountToSend
    );

    // 2. Partial Whitdraw
    let amountToWithdraw = amountToSend/10;
    console.log("\n--- Partial Whitdraw. Actor: the recipient ---");
    await withdraw(
        connection,
        programId,
        recipientKeypair,
        tempSenderTokenAccountPubKey,
        recipientTokenAccountPubkey,
        amountToWithdraw
    );

    // 3. Total Whitdraw
    amountToWithdraw = amountToSend - amountToWithdraw;
    console.log("\n--- Partial Whitdraw. Actor: the recipient ---");
    await withdraw(
        connection,
        programId,
        recipientKeypair,
        tempSenderTokenAccountPubKey,
        recipientTokenAccountPubkey,
        amountToWithdraw
    );

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

async function setup(
    connection: Connection,
    senderKeypair: Keypair,
    recipientKeypair: Keypair,
    initialBalance: number
): Promise<[PublicKey, PublicKey, PublicKey]> {
    // Create a feePayer and airdop SOL to it
    const feePayer = Keypair.generate();
    let airdropSignature = await connection.requestAirdrop(feePayer.publicKey, LAMPORTS_PER_SOL);
    await connection.confirmTransaction(airdropSignature);

    // Create Mint with the sender as the mint authority
    const decimals = 8;
    let mintPubkey = await createMint(
        connection, // conneciton
        feePayer, // fee payer
        senderKeypair.publicKey, // mint authority
        senderKeypair.publicKey, // freeze authority (you can use `null` to disable it. when you disable it, you can't turn it on again)
        decimals
    );
    console.log("Mint:           " + mintPubkey.toBase58());

    // Create the token associated account for the sender
    const senderTokenAccount = await getOrCreateAssociatedTokenAccount(
        connection,
        feePayer,
        mintPubkey,
        senderKeypair.publicKey
    );

    // Mint tokens to the associated token account
    await mintTo(
        connection,
        feePayer,
        mintPubkey,
        senderTokenAccount.address,
        senderKeypair,
        initialBalance * Math.pow(10, decimals), // amount. if your decimals is 8, you mint 10^8 for 1 token.
    );

    // Airdrop some SOL to the recipient
    airdropSignature = await connection.requestAirdrop(recipientKeypair.publicKey, LAMPORTS_PER_SOL);
    await connection.confirmTransaction(airdropSignature);

    // Create the token associated account for the recipient
    const recipientTokenAccount = await getOrCreateAssociatedTokenAccount(
        connection,
        feePayer,
        mintPubkey,
        recipientKeypair.publicKey
    );

    return [mintPubkey, senderTokenAccount.address, recipientTokenAccount.address];
}

async function deposit(
    connection: Connection,
    programId: PublicKey,
    mintPubkey: PublicKey,
    senderKeypair: Keypair,
    senderTokenAccount: PublicKey,
    amountToSend: number
): Promise<PublicKey> {

    const mint = await getMint(connection, mintPubkey);

    // Instruction to create temp token account
    const tempSenderTokenAccountKeypair = Keypair.generate();
    const createTempTokenAccountInstruction = SystemProgram.createAccount({
        fromPubkey: senderKeypair.publicKey,
        newAccountPubkey: tempSenderTokenAccountKeypair.publicKey,
        space: ACCOUNT_SIZE,
        lamports: await getMinimumBalanceForRentExemptAccount(connection),
        programId: TOKEN_PROGRAM_ID,
    });

    // Instruction to init token account
    const initTempAccountInstruction = createInitializeAccountInstruction(
        tempSenderTokenAccountKeypair.publicKey,
        mintPubkey,
        senderKeypair.publicKey
    );

    // Instruction to transfer tokens to the second associated token account
    const transferTokensToTempAccInstruction = createTransferInstruction(
        senderTokenAccount,
        tempSenderTokenAccountKeypair.publicKey,
        senderKeypair.publicKey,
        amountToSend * Math.pow(10, mint.decimals) // amount. if your decimals is 8, you mint 10^8 for 1 token.
    );

    // Instruction to our program
    const depositInstruction = new TransactionInstruction({
        programId: programId,
        keys: [
            { pubkey: senderKeypair.publicKey, isSigner: true, isWritable: false },
            { pubkey: tempSenderTokenAccountKeypair.publicKey, isSigner: false, isWritable: true },
            { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
        ],
        data: Buffer.from(new Uint8Array([Action.Deposit])),
    });

    const depositTransaction = new Transaction().add(
        createTempTokenAccountInstruction,
        initTempAccountInstruction,
        transferTokensToTempAccInstruction,
        depositInstruction
    );

    await sendAndConfirmTransaction(
        connection,
        depositTransaction,
        [senderKeypair, tempSenderTokenAccountKeypair]
    );

    const tFees = await getTransactionFees(depositTransaction, connection);
    feesForSender += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, ' SOL');

    return tempSenderTokenAccountKeypair.publicKey;
}

async function withdraw(
    connection: Connection,
    programId: PublicKey,
    recipientKeypair: Keypair,
    tempSenderTokenAccountPubKey: PublicKey,
    recipientTokenAccountPubkey: PublicKey,
    amountToWithdraw: number
): Promise<void> {

    const PDA = await PublicKey.findProgramAddress([Buffer.from("SimpleTransfer")], programId);
    const PDApubKey = PDA[0];

    let withdraw_request = new WithdrawRequest({ amount: amountToWithdraw });
    let data = borsh.serialize(WithdrawRequest.schema, withdraw_request);
    let data_to_send = Buffer.from(new Uint8Array([Action.Withdraw, ...data]));

    const withdrawInstruction = new TransactionInstruction({
        programId: programId,
        data: data_to_send,
        keys: [
            { pubkey: recipientKeypair.publicKey, isSigner: true, isWritable: false },
            { pubkey: recipientTokenAccountPubkey, isSigner: false, isWritable: true },
            { pubkey: tempSenderTokenAccountPubKey, isSigner: false, isWritable: true },
            { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
            { pubkey: PDApubKey, isSigner: false, isWritable: false },
        ],
    });

    const withdrawTransaction = new Transaction().add(withdrawInstruction);

    await sendAndConfirmTransaction(
        connection,
        withdrawTransaction,
        [recipientKeypair]
    );

    const tFees = await getTransactionFees(withdrawTransaction, connection);
    feesForRecipient += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, ' SOL');
}