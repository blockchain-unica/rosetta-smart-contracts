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

const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../contracts/dist/escrow/escrow-keypair.json');

enum Action {
    Initialize = 0,
    Deposit = 1,
    Pay = 2,
    Refund = 3,
}

enum State {
    WaitDeposit = 0,
    WaitRecipient = 1,
    Closed = 2,
};

class EscrowInfo {
    seller: Buffer = Buffer.alloc(32);
    buyer: Buffer = Buffer.alloc(32);
    amount: number = 0;
    state: State = State.WaitDeposit;

    constructor(fields: {
        seller: Buffer,
        buyer: Buffer,
        amount: number,
        state: State,
    } | undefined = undefined) {
        if (fields) {
            this.seller = fields.seller;
            this.buyer = fields.buyer;
            this.amount = fields.amount;
            this.state = fields.state;
        }
    }

    static schema = new Map([
        [EscrowInfo, {
            kind: 'struct', fields: [
                ['seller', [32]],
                ['buyer', [32]],
                ['amount', 'u64'],
                ['state', 'u8'],
            ]
        }],
    ]);

    static size = borsh.serialize(
        EscrowInfo.schema,
        new EscrowInfo(),
    ).length
}

let feesForSeller = 0;
let feesForBuyer = 0;

async function main() {
    
    const connection = getConnection();

    const programId = await getPublicKeyFromFile(PROGRAM_KEYPAIR_PATH);
    const kpSeller = await generateKeyPair(connection, 1);
    const kpBuyer = await generateKeyPair(connection, 1);

    await printParticipants(connection, programId, [
        ["seller", kpSeller.publicKey], 
        ["buyer", kpBuyer.publicKey],
    ]);

    // 0. Initialize
    console.log("\n--- Initialize. Actor: the seller ---");
    const requiredAmount = 0.1 * LAMPORTS_PER_SOL;
    console.log("    Required amount: ", requiredAmount / LAMPORTS_PER_SOL, "SOL");
    let stateAccountPublicKey = await initialize(
        connection,
        programId,
        kpSeller,
        kpBuyer.publicKey,
        requiredAmount
    );

    // 1. Deposit money (the buyer deposits the amount equal to price)
    console.log("\n--- Deposit. Actor: the buyer ---");
    const amountToDeposit = requiredAmount;
    console.log("    Amount: ", amountToDeposit / LAMPORTS_PER_SOL, "SOL");
    await deposit(
        connection,
        programId,
        kpBuyer,
        stateAccountPublicKey,
        amountToDeposit
    );

    // Chose if to pay or to refund
    const choice: Action = Action.Refund;
    switch (choice.valueOf()) {
        case Action.Pay:     // 2. Payment
            console.log("\n--- Pay. Actor: the buyer ---");
            await pay(
                connection,
                programId,
                kpBuyer,
                stateAccountPublicKey,
            );
            break;

        case Action.Refund:  // 2. Refund
            console.log("\n--- Refund. Actor: the seller ---");
            await refund(
                connection,
                programId,
                kpSeller,
                stateAccountPublicKey,
            );
            break;
    }

    // Costs
    console.log("\n........");
    console.log("Fees for seller: ", feesForSeller / LAMPORTS_PER_SOL, "SOL");
    console.log("Fees for buyer:  ", feesForBuyer / LAMPORTS_PER_SOL, "SOL");
    console.log("Total fees:      ", (feesForSeller + feesForBuyer) / LAMPORTS_PER_SOL, "SOL");
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
    kpSeller: Keypair,
    buyerPubKey: PublicKey,
    amount: number,
): Promise<PublicKey> {

    const SEED = "abcdef" + Math.random().toString();
    const stateAccountPublicKey = await PublicKey.createWithSeed(kpSeller.publicKey, SEED, programId);

    // Instruction to create the State Account account
    const createStateAccountInstruction = SystemProgram.createAccountWithSeed({
        fromPubkey: kpSeller.publicKey,
        basePubkey: kpSeller.publicKey,
        seed: SEED,
        newAccountPubkey: stateAccountPublicKey,
        lamports: await connection.getMinimumBalanceForRentExemption(EscrowInfo.size),
        space: EscrowInfo.size,
        programId: programId,
    });

    const initInstruction = new TransactionInstruction({
        keys: [
            { pubkey: kpSeller.publicKey, isSigner: true, isWritable: false },
            { pubkey: buyerPubKey, isSigner: false, isWritable: false },
            { pubkey: stateAccountPublicKey, isSigner: false, isWritable: true },
        ],
        programId,
        data: buildBufferFromActionAndNumber(Action.Initialize, amount)
    });

    // Instruction to the program
    const transaction = new Transaction().add(
        createStateAccountInstruction,
        initInstruction
    );
    await sendAndConfirmTransaction(connection, transaction, [kpSeller]);

    let tFees = await getTransactionFees(transaction, connection);
    feesForSeller += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');

    return stateAccountPublicKey;
}

async function deposit(
    connection: Connection,
    programId: PublicKey,
    kpBuyer: Keypair,
    stateAccountPublicKey: PublicKey,
    amount: number
): Promise<void> {

    // Instruction to transfer lamports to the State Account account
    const transferLamportsToStateAccount = SystemProgram.transfer({
        fromPubkey: kpBuyer.publicKey,
        toPubkey: stateAccountPublicKey,
        lamports: amount
    });

    // Instruction to the program
    const depositInstruction = new TransactionInstruction({
        keys: [
            { pubkey: kpBuyer.publicKey, isSigner: true, isWritable: false },
            { pubkey: stateAccountPublicKey, isSigner: false, isWritable: true },
        ],
        programId,
        data: Buffer.from(new Uint8Array([Action.Deposit])),
    });

    const transaction = new Transaction().add(
        transferLamportsToStateAccount,
        depositInstruction
    );
    await sendAndConfirmTransaction(connection, transaction, [kpBuyer]);

    let tFees = await getTransactionFees(transaction, connection);
    feesForBuyer += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

async function pay(
    connection: Connection,
    programId: PublicKey,
    kpBuyer: Keypair,
    stateAccountPublicKey: PublicKey,
): Promise<void> {

    const stateAccountInfo = await connection.getAccountInfo(stateAccountPublicKey);
    if (stateAccountInfo === null) {
        throw new Error('Error: cannot find the state account');
    }
    const stateInfo = borsh.deserialize(EscrowInfo.schema, EscrowInfo, stateAccountInfo.data,);

    // Instruction to the program
    const payInstruction = new TransactionInstruction({
        keys: [
            { pubkey: kpBuyer.publicKey, isSigner: true, isWritable: false },
            { pubkey: new PublicKey(stateInfo.seller), isSigner: false, isWritable: true },
            { pubkey: stateAccountPublicKey, isSigner: false, isWritable: true },
        ],
        programId,
        data: Buffer.from(new Uint8Array([Action.Pay])),
    });

    const transaction = new Transaction().add(payInstruction);
    await sendAndConfirmTransaction(connection, transaction, [kpBuyer]);

    let tFees = await getTransactionFees(transaction, connection);
    feesForBuyer += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

async function refund(
    connection: Connection,
    programId: PublicKey,
    kpSeller: Keypair,
    stateAccountPublicKey: PublicKey,
): Promise<void> {

    const stateAccountInfo = await connection.getAccountInfo(stateAccountPublicKey);
    if (stateAccountInfo === null) {
        throw new Error('Error: cannot find the state account');
    }
    const stateInfo = borsh.deserialize(EscrowInfo.schema, EscrowInfo, stateAccountInfo.data,);

    // Instruction to the program
    const refundInstruction = new TransactionInstruction({
        keys: [
            { pubkey: kpSeller.publicKey, isSigner: true, isWritable: true },
            { pubkey: new PublicKey(stateInfo.buyer), isSigner: false, isWritable: true },
            { pubkey: stateAccountPublicKey, isSigner: false, isWritable: true },
        ],
        programId,
        data: Buffer.from(new Uint8Array([Action.Refund])),
    });

    const transaction = new Transaction().add(refundInstruction);
    await sendAndConfirmTransaction(connection, transaction, [kpSeller]);

    let tFees = await getTransactionFees(transaction, connection);
    feesForSeller += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}
