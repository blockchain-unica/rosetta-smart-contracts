import {
    Connection,
    Keypair,
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
    mintToChecked,
} from "@solana/spl-token";

import {
    buildBufferFromActionAndNumber,
    generateKeyPair,
    getConnection,
    getPublicKeyFromFile,
    getSystemKeyPair,
    getTransactionFees,
    printParticipants,
} from './utils';

import * as BufferLayout from '@solana/buffer-layout';
import path from 'path';
import * as borsh from 'borsh';

const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../contracts/dist/tiny_amm/tiny_amm-keypair.json');

enum Action {
    Initialize = 0,
    Deposit = 1,
    Redeem = 2,
    Swap = 3,
}

const SEED_FOR_AMM = "amm";
const SEED_FOR_MINTED = "minted";

const MINT_DECIMALS = 9;

let mint0Pubkey: PublicKey;
let mint1Pubkey: PublicKey;
const programTokenAccount0KeyPair = Keypair.generate();
const programTokenAccount1KeyPair = Keypair.generate();

let totalFees = 0;

async function main() {

    const connection = getConnection();

    const programId = await getPublicKeyFromFile(PROGRAM_KEYPAIR_PATH);
    const initializerKeypair = await getSystemKeyPair();
    const MKeypair = await generateKeyPair(connection, 1);

    await printParticipants(connection, programId, [
        ["initializer", initializerKeypair.publicKey],
        ["M", MKeypair.publicKey],
    ]);

    // 0. Setup
    console.log("\n--- Setup Mint and Token Accounts. ---");
    await setup(
        connection,
        [MKeypair.publicKey],
    );

    // 1. Initialize
    console.log("\n--- Initialize. ---");
    await initialize(
        connection,
        programId,
        initializerKeypair);

    // 2. Deposit tokens (user 1)
    console.log("\n--- Deposit.--- (user: M)");
    const amount0 = 6;
    const amount1 = 6;
    await deposit(
        connection,
        programId,
        MKeypair,
        amount0,
        amount1,
    );

    // Chose if to redeem or to swap
    const choice: Action = Action.Redeem;

    switch (choice.valueOf()) {
        case Action.Redeem:     // 3. Withdraw
            console.log("\n--- Redeem.--- (user: M)");
            const amountToRedeem = 6;
            await redeem(
                connection,
                programId,
                MKeypair,
                amountToRedeem,
            );
            break;

        case Action.Swap:        // 3. Swap
            console.log("\n--- Swap. --- (user: M)");
            const sendedMint = 0;
            const amountIn = 3;
            const minOutAmount = 2;
            await swap(
                connection,
                programId,
                MKeypair,
                sendedMint,
                amountIn,
                minOutAmount,
            );
            break;
    }

    // Costs
    console.log("\n........");
    console.log("Total fees:            ", totalFees / LAMPORTS_PER_SOL, "SOL");
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
    users: PublicKey[],
): Promise<void> {

    // Create a feePayer and airdop SOL to it
    const feePayer = await getSystemKeyPair();

    mint0Pubkey = await createMint(
        connection,
        feePayer,
        feePayer.publicKey,
        feePayer.publicKey,
        MINT_DECIMALS
    );
    console.log("    Mint 0:\t" + mint0Pubkey.toBase58());

    mint1Pubkey = await createMint(
        connection,
        feePayer,
        feePayer.publicKey,
        feePayer.publicKey,
        MINT_DECIMALS
    );
    console.log("    Mint 1:\t" + mint1Pubkey.toBase58());

    for (let i = 0; i < users.length; i++) {
        const userKeypair = users[i];

        // Create the token associated account for the user (Mint 0)
        const userTokenAccountForMint0 = await getOrCreateAssociatedTokenAccount(
            connection,
            feePayer,
            mint0Pubkey,
            userKeypair
        );

        // Create the token associated account for the user (Mint 1)
        const userTokenAccountForMint1 = await getOrCreateAssociatedTokenAccount(
            connection,
            feePayer,
            mint1Pubkey,
            userKeypair
        );

        // Mint tokens to the associated token accounts
        await mintToChecked(
            connection,
            feePayer,
            mint0Pubkey,
            userTokenAccountForMint0.address,
            feePayer,
            100 * Math.pow(10, MINT_DECIMALS),
            MINT_DECIMALS
        );
        let t0Balance = Number((await connection.getTokenAccountBalance(userTokenAccountForMint0.address)).value.amount);

        await mintToChecked(
            connection,
            feePayer,
            mint1Pubkey,
            userTokenAccountForMint1.address,
            feePayer,
            100 * Math.pow(10, MINT_DECIMALS),
            MINT_DECIMALS
        );
        let t1Balance = Number((await connection.getTokenAccountBalance(userTokenAccountForMint1.address)).value.amount);

        console.log("    User's", i, "token account for mint 0:\t" + userTokenAccountForMint0.address.toBase58() + " balance: ", t0Balance / Math.pow(10, MINT_DECIMALS));
        console.log("    User's", i, "token account for mint 1:\t" + userTokenAccountForMint1.address.toBase58() + " balance: ", t1Balance / Math.pow(10, MINT_DECIMALS));

    }
}

async function initialize(
    connection: Connection,
    programId: PublicKey,
    initializerKeypair: Keypair,
): Promise<void> {

    const ammPDAPubKey = await getAmmPDA(programId, mint0Pubkey, mint1Pubkey);
    console.log("    PDA:\t" + ammPDAPubKey.toBase58());

    console.log("    PDA's token account for mint 0:\t" + programTokenAccount0KeyPair.publicKey.toBase58());

    const createTokenAccount0Instruction = SystemProgram.createAccount({
        fromPubkey: initializerKeypair.publicKey,
        newAccountPubkey: programTokenAccount0KeyPair.publicKey,
        space: ACCOUNT_SIZE,
        lamports: await getMinimumBalanceForRentExemptAccount(connection),
        programId: TOKEN_PROGRAM_ID,
    });

    const initTokenAccount0Instruction = createInitializeAccountInstruction(
        programTokenAccount0KeyPair.publicKey,
        mint0Pubkey,
        initializerKeypair.publicKey
    );

    console.log("    PDA's token account for mint 1:\t" + programTokenAccount1KeyPair.publicKey.toBase58());

    const createTokenAccount1Instruction = SystemProgram.createAccount({
        fromPubkey: initializerKeypair.publicKey,
        newAccountPubkey: programTokenAccount1KeyPair.publicKey,
        space: ACCOUNT_SIZE,
        lamports: await getMinimumBalanceForRentExemptAccount(connection),
        programId: TOKEN_PROGRAM_ID,
    });

    const initTokenAccount1Instruction = createInitializeAccountInstruction(
        programTokenAccount1KeyPair.publicKey,
        mint1Pubkey,
        initializerKeypair.publicKey
    );

    const initInstruction = new TransactionInstruction({
        programId: programId,
        keys: [
            { pubkey: initializerKeypair.publicKey, isSigner: true, isWritable: false },
            { pubkey: ammPDAPubKey, isSigner: false, isWritable: true },
            { pubkey: mint0Pubkey, isSigner: false, isWritable: false },
            { pubkey: mint1Pubkey, isSigner: false, isWritable: false },
            { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
            { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
            { pubkey: programTokenAccount0KeyPair.publicKey, isSigner: false, isWritable: true },
            { pubkey: programTokenAccount1KeyPair.publicKey, isSigner: false, isWritable: true },
        ],
        data: Buffer.from(new Uint8Array([Action.Initialize]))
    });

    const transaction = new Transaction().add(
        createTokenAccount0Instruction,
        initTokenAccount0Instruction,
        createTokenAccount1Instruction,
        initTokenAccount1Instruction,
        initInstruction,
    );

    await sendAndConfirmTransaction(
        connection,
        transaction,
        [initializerKeypair, programTokenAccount0KeyPair, programTokenAccount1KeyPair]
    );

    const tFees = await getTransactionFees(transaction, connection);
    totalFees += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

async function deposit(
    connection: Connection,
    programId: PublicKey,
    depositorKeypair: Keypair,
    amount0: number,
    amount1: number,
): Promise<void> {

    console.log("    amount0:", amount0);
    console.log("    amount1:", amount1);

    const ammPDAPubKey = await getAmmPDA(programId, mint0Pubkey, mint1Pubkey);
    const mintedPDAPubKey = await getMintedPDA(programId, depositorKeypair.publicKey);

    const sendersTokenAccountForMint0 = await getOrCreateAssociatedTokenAccount(
        connection,
        depositorKeypair,
        mint0Pubkey,
        depositorKeypair.publicKey
    );

    const sendersTokenAccountForMint1 = await getOrCreateAssociatedTokenAccount(
        connection,
        depositorKeypair,
        mint1Pubkey,
        depositorKeypair.publicKey
    );

    // Encode the data to send
    interface Settings { action: number, amount0: number, amount1: number }
    const layout = BufferLayout.struct<Settings>([BufferLayout.u8("action"), BufferLayout.nu64("amount0"), BufferLayout.nu64("amount1")]);
    const dataToSend = Buffer.alloc(layout.span);
    layout.encode({ action: Action.Deposit, amount0, amount1 }, dataToSend);

    const transaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: depositorKeypair.publicKey, isSigner: true, isWritable: false },
                { pubkey: ammPDAPubKey, isSigner: false, isWritable: true },
                { pubkey: programTokenAccount0KeyPair.publicKey, isSigner: false, isWritable: true },
                { pubkey: programTokenAccount1KeyPair.publicKey, isSigner: false, isWritable: true },
                { pubkey: sendersTokenAccountForMint0.address, isSigner: false, isWritable: true },
                { pubkey: sendersTokenAccountForMint1.address, isSigner: false, isWritable: true },
                { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
                { pubkey: mintedPDAPubKey, isSigner: false, isWritable: true },
                { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
            ],
            programId,
            data: dataToSend,
        })
    );

    await sendAndConfirmTransaction(connection, transaction, [depositorKeypair]);

    const tFees = await getTransactionFees(transaction, connection);
    totalFees += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

async function redeem(
    connection: Connection,
    programId: PublicKey,
    redeemerKeypair: Keypair,
    amountToRedeem: number,
): Promise<void> {

    console.log("    amount:", amountToRedeem);

    const ammPDAPubKey = await getAmmPDA(programId, mint0Pubkey, mint1Pubkey);
    const mintedPDAPubKey = await getMintedPDA(programId, redeemerKeypair.publicKey);

    const sendersTokenAccountForMint0 = await getOrCreateAssociatedTokenAccount(
        connection,
        redeemerKeypair,
        mint0Pubkey,
        redeemerKeypair.publicKey
    );

    const sendersTokenAccountForMint1 = await getOrCreateAssociatedTokenAccount(
        connection,
        redeemerKeypair,
        mint1Pubkey,
        redeemerKeypair.publicKey
    );

    const transaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: redeemerKeypair.publicKey, isSigner: true, isWritable: false },
                { pubkey: ammPDAPubKey, isSigner: false, isWritable: true },
                { pubkey: programTokenAccount0KeyPair.publicKey, isSigner: false, isWritable: true },
                { pubkey: programTokenAccount1KeyPair.publicKey, isSigner: false, isWritable: true },
                { pubkey: sendersTokenAccountForMint0.address, isSigner: false, isWritable: true },
                { pubkey: sendersTokenAccountForMint1.address, isSigner: false, isWritable: true },
                { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
                { pubkey: mintedPDAPubKey, isSigner: false, isWritable: true },
            ],
            programId,
            data: buildBufferFromActionAndNumber(Action.Redeem, amountToRedeem),
        })
    );

    await sendAndConfirmTransaction(connection, transaction, [redeemerKeypair]);

    const tFees = await getTransactionFees(transaction, connection);
    totalFees += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');

}

async function swap(
    connection: Connection,
    programId: PublicKey,
    userKeyPair: Keypair,
    sendedMint: number,
    amountIn: number,
    minOutAmount: number,
): Promise<void> {

    console.log("    sendedMint:", sendedMint);
    console.log("    amountIn:    ", amountIn);
    console.log("    minOutAmount:", minOutAmount);

    const ammPDAPubKey = await getAmmPDA(programId, mint0Pubkey, mint1Pubkey);

    const sendersTokenAccountForMint0 = await getOrCreateAssociatedTokenAccount(
        connection,
        userKeyPair,
        mint0Pubkey,
        userKeyPair.publicKey
    );

    const sendersTokenAccountForMint1 = await getOrCreateAssociatedTokenAccount(
        connection,
        userKeyPair,
        mint1Pubkey,
        userKeyPair.publicKey
    );

    // Encode the data to send
    interface Settings { action: number, deserved_mint: number, amountIn: number, minOutAmount: number }
    const layout = BufferLayout.struct<Settings>([BufferLayout.u8("action"), BufferLayout.nu64("deserved_mint"), BufferLayout.nu64("amountIn"), BufferLayout.nu64("minOutAmount")]);
    const dataToSend = Buffer.alloc(layout.span);
    layout.encode({ action: Action.Swap, deserved_mint: sendedMint, amountIn: amountIn, minOutAmount }, dataToSend);

    const transaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: userKeyPair.publicKey, isSigner: true, isWritable: false },
                { pubkey: ammPDAPubKey, isSigner: false, isWritable: true },
                { pubkey: programTokenAccount0KeyPair.publicKey, isSigner: false, isWritable: true },
                { pubkey: programTokenAccount1KeyPair.publicKey, isSigner: false, isWritable: true },
                { pubkey: sendersTokenAccountForMint0.address, isSigner: false, isWritable: true },
                { pubkey: sendersTokenAccountForMint1.address, isSigner: false, isWritable: true },
                { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
            ],
            programId,
            data: dataToSend,
        })
    );

    await sendAndConfirmTransaction(connection, transaction, [userKeyPair]);

    const tFees = await getTransactionFees(transaction, connection);
    totalFees += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

async function getAmmPDA(programId: PublicKey, mint0Pubkey: PublicKey, mint1Pubkey: PublicKey): Promise<PublicKey> {
    const [ammPDA] = await PublicKey.findProgramAddress(
        [Buffer.from(SEED_FOR_AMM), mint0Pubkey.toBuffer(), mint1Pubkey.toBuffer()],
        programId
    );
    return ammPDA;
}

async function getMintedPDA(programId: PublicKey, depositor: PublicKey): Promise<PublicKey> {
    const [ammPDA] = await PublicKey.findProgramAddress(
        [Buffer.from(SEED_FOR_MINTED), depositor.toBuffer()],
        programId
    );
    return ammPDA;
}