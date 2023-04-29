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
    createTransferInstruction,
    getMint,
    mintToChecked,
} from "@solana/spl-token";

import {
    getPublicKeyFromFile,
    getSystemKeyPair,
    getTransactionFees,
} from './utils';

import path from 'path';
import * as borsh from 'borsh';

class DepositInfo {
    sender: Buffer = Buffer.alloc(32);
    temp_token_account: Buffer = Buffer.alloc(32);
    reciever_token_account: Buffer = Buffer.alloc(32);
    amount: number = 0;

    constructor(fields: {
        sender: Buffer,
        temp_token_account: Buffer,
        reciever_token_account: Buffer,
        amount: number,
    } | undefined = undefined) {
        if (fields) {
            this.sender = fields.sender;
            this.temp_token_account = fields.temp_token_account;
            this.reciever_token_account = fields.reciever_token_account;
            this.amount = fields.amount;
        }
    }

    static schema = new Map([
        [DepositInfo, {
            kind: 'struct', fields: [
                ['sender', [32]],
                ['temp_token_account', [32]],
                ['reciever_token_account', [32]],
                ['amount', 'u64'],
            ]
        }],
    ]);

    static size = borsh.serialize(
        DepositInfo.schema,
        new DepositInfo(),
    ).length
}

class PassedAmount {
    amount: number = 0;

    constructor(fields: {
        amount: number,
    } | undefined = undefined) {
        if (fields) {
            this.amount = fields.amount;
        }
    }

    static schema = new Map([
        [PassedAmount, {
            kind: 'struct', fields: [
                ['amount', 'u64'],
            ]
        }],
    ]);
}

const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../solana/dist/token_transfer/token_transfer-keypair.json');

enum Action { Deposit = 0, Withdraw = 1 }

let feesForSender = 0;
let feesForRecipient = 0;

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

    // 1. Deposit tokens
    console.log("\n--- Deposit. Actor: the onwer ---");
    const amountToSend = initialBalance / 2;
    const stateAccountPubkey = await deposit(
        connection,
        programId,
        mintPubkey,
        senderKeypair,
        senderTokenAccountPubkey,
        recipientTokenAccountPubkey,
        amountToSend
    );

    // 2. Partial Whitdraw
    let amountToWithdraw = amountToSend / 10;
    console.log("\n--- Partial Whitdraw. Actor: the recipient ---");
    await withdraw(
        connection,
        programId,
        recipientKeypair,
        stateAccountPubkey,
        amountToWithdraw
    );

    // 3. Total Whitdraw
    amountToWithdraw = amountToSend - amountToWithdraw;
    console.log("\n--- Partial Whitdraw. Actor: the recipient ---");
    await withdraw(
        connection,
        programId,
        recipientKeypair,
        stateAccountPubkey,
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
    const decimals = 9;
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
    await mintToChecked(
        connection,
        feePayer,
        mintPubkey,
        senderTokenAccount.address, // destination
        senderKeypair, // mint authority
        initialBalance * Math.pow(10, decimals), // amount. if your decimals is 8, you mint 10^8 for 1 token
        decimals
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
    recipientTokenAccountPubkey: PublicKey,
    amountToSend: number
): Promise<PublicKey> {

    const mint = await getMint(connection, mintPubkey);

    // Instruction to create temp token account
    const tempSenderTokenAccountKeypair = Keypair.generate();
    const createTempTokenAccountInstruction = SystemProgram.createAccount({
        fromPubkey: senderKeypair.publicKey, // fee payer
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
        senderTokenAccount, // from
        tempSenderTokenAccountKeypair.publicKey, // to
        senderKeypair.publicKey, //owner
        amountToSend * Math.pow(10, mint.decimals) // amount. if your decimals is 8, you mint 10^8 for 1 token.
    );

    // Instruction to create the State Account account
    const SEED = "abcdef" + Math.random().toString();
    const stateAccountPubkey = await PublicKey.createWithSeed(senderKeypair.publicKey, SEED, programId);
    const createDepositInfoAccountInstruction = SystemProgram.createAccountWithSeed({
        fromPubkey: senderKeypair.publicKey,
        basePubkey: senderKeypair.publicKey,
        seed: SEED,
        newAccountPubkey: stateAccountPubkey,
        lamports: await connection.getMinimumBalanceForRentExemption(DepositInfo.size),
        space: DepositInfo.size,
        programId: programId,
    });

    // Instruction to the program
    let passed_amount = new PassedAmount({ amount: amountToSend });
    let data = borsh.serialize(PassedAmount.schema, passed_amount);
    let data_to_send = Buffer.from(new Uint8Array([Action.Deposit, ...data]));
    const depositInstruction = new TransactionInstruction({
        programId: programId,
        keys: [
            { pubkey: senderKeypair.publicKey, isSigner: true, isWritable: false },
            { pubkey: tempSenderTokenAccountKeypair.publicKey, isSigner: false, isWritable: true },
            { pubkey: stateAccountPubkey, isSigner: false, isWritable: true },
            { pubkey: recipientTokenAccountPubkey, isSigner: false, isWritable: false },
            { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
        ],
        data:data_to_send,
    });

    const depositTransaction = new Transaction().add(
        createTempTokenAccountInstruction,
        initTempAccountInstruction,
        transferTokensToTempAccInstruction,
        createDepositInfoAccountInstruction,
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

    return stateAccountPubkey;
}

async function withdraw(
    connection: Connection,
    programId: PublicKey,
    recipientKeypair: Keypair,
    stateAccountPubkey: PublicKey,
    amountToWithdraw: number
): Promise<void> {

    const PDA = await PublicKey.findProgramAddress([Buffer.from("TokenTransfer")], programId);
    const PDApubKey = PDA[0];

    const stateAccountInfo = await connection.getAccountInfo(stateAccountPubkey);
    if (stateAccountInfo === null) {
      throw 'Error: cannot find the state account';
    }
    const stateInfo = borsh.deserialize(DepositInfo.schema, DepositInfo, stateAccountInfo.data,);

    let passed_amount = new PassedAmount({ amount: amountToWithdraw });
    let data = borsh.serialize(PassedAmount.schema, passed_amount);
    let data_to_send = Buffer.from(new Uint8Array([Action.Withdraw, ...data]));

    const withdrawInstruction = new TransactionInstruction({
        programId: programId,
        data: data_to_send,
        keys: [
            { pubkey: recipientKeypair.publicKey, isSigner: true, isWritable: false },
            { pubkey: new PublicKey(stateInfo.sender), isSigner: false, isWritable: true },
            { pubkey: new PublicKey(stateInfo.reciever_token_account), isSigner: false, isWritable: true },
            { pubkey: new PublicKey(stateInfo.temp_token_account), isSigner: false, isWritable: true },
            { pubkey: stateAccountPubkey, isSigner: false, isWritable: true },
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