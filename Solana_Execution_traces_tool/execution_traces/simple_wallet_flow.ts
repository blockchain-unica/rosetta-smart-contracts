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
    NumberHolder,
    buildBufferFromActionAndNumber,
    generateKeyPair,
    getConnection,
    getPublicKeyFromFile,
    getTransactionFees,
    printParticipants,
} from './utils';

import * as borsh from 'borsh';
import path from 'path';
import { Buffer } from 'buffer';

const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../contracts/dist/simple_wallet/simple_wallet-keypair.json');

enum Action {
    Deposit = 0,
    CreateTransaction = 1,
    ExecuteTransaction = 2,
    Withdraw = 3,
}

class UserTransaction {
    to: Buffer = Buffer.alloc(32);
    value: number = 0;
    executed: boolean = false;

    constructor(fields: {
        to: Buffer,
        value: number,
        executed: boolean,
    } | undefined = undefined) {
        if (fields) {
            this.to = fields.to;
            this.value = fields.value;
            this.executed = fields.executed;
        }
    }

    static schema = new Map([
        [UserTransaction, {
            kind: 'struct', fields: [
                ['to', [32]],
                ['value', 'u64'],
                ['executed', 'u8'],
            ]
        }],
    ]);
}

let feesForOwner = 0;

const SEED_FOR_TRANSACTION = "tx";
const SEED_FOR_WALLET = "wallet";

async function main() {

    const connection = getConnection();
    
    const programId = await getPublicKeyFromFile(PROGRAM_KEYPAIR_PATH);
    const kpOwner = await generateKeyPair(connection, 1);
    const kpReceiver = await generateKeyPair(connection, 1);

    await printParticipants(connection, programId, [
        ["owner", kpOwner.publicKey], 
        ["receiver", kpReceiver.publicKey],
    ]);

    // 1. Deposit money
    const amountToDeposit = 0.2 * LAMPORTS_PER_SOL;
    console.log("\n--- Deposit", amountToDeposit / LAMPORTS_PER_SOL, " SOL. Actor: the onwer ---");
    await deposit(
        connection,
        programId,
        kpOwner,
        amountToDeposit);

    // 2. Create transaction
    const amountToSend = amountToDeposit / 2;
    console.log("\n--- Creation TX to send.", amountToSend / LAMPORTS_PER_SOL, "SOL to the receiver. Actor: the owner ---");
    await createTransaction(
        connection,
        programId,
        kpOwner,
        kpReceiver.publicKey,
        amountToSend);

    // 3. Execute transaction
    const lastTransactionId = await getNextTransactionId(connection, programId, kpOwner.publicKey) - 1;
    console.log("\n--- Execution transaction with id:", lastTransactionId + ". Actor: the owner ---");
    await executeTransaction(
        connection,
        programId,
        kpOwner,
        lastTransactionId);

    // 4. Withdraw
    console.log("\n--- Withdraw. Actor: the owner ---");
    await withdraw(
        connection,
        programId,
        kpOwner);

    // Costs
    const ownerBalance = await connection.getBalance(kpOwner.publicKey);
    const receiverBalance = await connection.getBalance(kpReceiver.publicKey);
    console.log("\n........");
    console.log("Fees for owner:         ", feesForOwner / LAMPORTS_PER_SOL, "SOL");
    console.log("Owner's balance:        ", ownerBalance / LAMPORTS_PER_SOL, "SOL");
    console.log("Receiver's balance:     ", receiverBalance / LAMPORTS_PER_SOL, "SOL");
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
    kpOwner: Keypair,
    amountToDeposit: number,
): Promise<void> {

    const walletPDA = await getOwnersWalletPDA(programId, kpOwner.publicKey);

    const transaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: kpOwner.publicKey, isSigner: true, isWritable: false },
                { pubkey: walletPDA, isSigner: false, isWritable: true },
                { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
            ],
            programId,
            data: buildBufferFromActionAndNumber(Action.Deposit, amountToDeposit),
        })
    );

    await sendAndConfirmTransaction(connection, transaction, [kpOwner]);

    const balancePDA = await connection.getBalance(walletPDA);
    console.log('    Current balance of the owner\'s PDA: ', balancePDA / LAMPORTS_PER_SOL, 'SOL');

    const tFees = await getTransactionFees(transaction, connection);
    feesForOwner += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');

}

async function createTransaction(
    connection: Connection,
    programId: PublicKey,
    kpOwner: Keypair,
    receiverPubKey: PublicKey,
    amountToSend: number
): Promise<void> {

    const newTransaction = new UserTransaction({
        to: receiverPubKey.toBuffer(),
        value: amountToSend,
        executed: false,
    });

    const serializedTransaction = borsh.serialize(UserTransaction.schema, newTransaction);

    const idTransaction = await getNextTransactionId(connection, programId, kpOwner.publicKey);
    console.log("    New transaction id: ", idTransaction);

    const walletPDA = await getOwnersWalletPDA(programId, kpOwner.publicKey);
    const transactionPDA = await getTransactionPDA(programId, kpOwner.publicKey, idTransaction);

    const transaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: kpOwner.publicKey, isSigner: true, isWritable: false },
                { pubkey: walletPDA, isSigner: false, isWritable: true },
                { pubkey: transactionPDA, isSigner: false, isWritable: true },
                { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
            ],
            programId,
            data: Buffer.from(new Uint8Array([Action.CreateTransaction, ...serializedTransaction]))
        })
    );

    await sendAndConfirmTransaction(connection, transaction, [kpOwner]);

    const tFees = await getTransactionFees(transaction, connection);
    feesForOwner += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');

}

async function executeTransaction(
    connection: Connection,
    programId: PublicKey,
    kpOwner: Keypair,
    idTransaction: number
): Promise<void> {

    const walletPDA = await getOwnersWalletPDA(programId, kpOwner.publicKey);
    const transactionPDA = await getTransactionPDA(programId, kpOwner.publicKey, idTransaction);

    // Get the receiver's public key from the transaction account
    const accountInfo = await connection.getAccountInfo(transactionPDA);
    if (accountInfo === null) {
        throw new Error('Account not found');
    }
    const userTx = borsh.deserialize(UserTransaction.schema, UserTransaction, accountInfo.data);
    const receiverPubKey = new PublicKey(userTx.to);

    const transaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: kpOwner.publicKey, isSigner: true, isWritable: false },
                { pubkey: walletPDA, isSigner: false, isWritable: true },
                { pubkey: transactionPDA, isSigner: false, isWritable: true },
                { pubkey: receiverPubKey, isSigner: false, isWritable: true },
            ],
            programId,
            data: buildBufferFromActionAndNumber(Action.ExecuteTransaction, idTransaction)
        })
    );

    await sendAndConfirmTransaction(connection, transaction, [kpOwner]);

    const tFees = await getTransactionFees(transaction, connection);
    feesForOwner += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');

}

async function withdraw(
    connection: Connection,
    programId: PublicKey,
    kpOwner: Keypair
): Promise<void> {

    const walletPDA = await getOwnersWalletPDA(programId, kpOwner.publicKey);

    const transaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: kpOwner.publicKey, isSigner: true, isWritable: false },
                { pubkey: walletPDA, isSigner: false, isWritable: true },
            ],
            programId,
            data: Buffer.from(new Uint8Array([Action.Withdraw]))
        })
    );

    await sendAndConfirmTransaction(connection, transaction, [kpOwner]);

    const tFees = await getTransactionFees(transaction, connection);
    feesForOwner += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

async function getNextTransactionId(
    connection: Connection,
    programId: PublicKey,
    walletOwnerPubKey: PublicKey)
    : Promise<number> {

    const walletPDA = await getOwnersWalletPDA(programId, walletOwnerPubKey);

    const accountInfo = await connection.getAccountInfo(walletPDA);

    if (accountInfo === null) {
        throw new Error('Account not found');
    }

    if (accountInfo.data.length !== 8) {
        throw new Error('Invalid account data length');
    }
    const numberHolder = borsh.deserialize(NumberHolder.schema, NumberHolder, accountInfo.data);

    return numberHolder.number / 1;
}

async function getOwnersWalletPDA(programId: PublicKey, ownerPubKey: PublicKey): Promise<PublicKey> {
    const [walletPDA] = await PublicKey.findProgramAddress(
        [Buffer.from(SEED_FOR_WALLET), ownerPubKey.toBuffer()],
        programId
    );
    return walletPDA;
}

async function getTransactionPDA(programId: PublicKey, ownerPubKey: PublicKey, idTransaction: number): Promise<PublicKey> {
    const [transactionPDA] = await PublicKey.findProgramAddress(
        [Buffer.from(SEED_FOR_TRANSACTION + idTransaction),
        ownerPubKey.toBuffer()],
        programId
    );
    return transactionPDA;
}