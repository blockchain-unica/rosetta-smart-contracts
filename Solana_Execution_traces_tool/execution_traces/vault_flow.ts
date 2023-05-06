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

const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../solana/dist/vault/vault-keypair.json');

enum Action {
    Initialize = 0,
    Withdraw = 1,
    Finalize = 2,
    Cancel = 3
};

enum State {
    Idle = 0,
    Req = 1
};

class VaultInfo {
    owner: Buffer = Buffer.alloc(32);
    recovery: Buffer = Buffer.alloc(32);
    receiver: Buffer = Buffer.alloc(32);
    wait_time: number = 0;
    request_time: number = 0;
    amount: number = 0;
    state: State = State.Idle;

    constructor(fields: {
        owner: Buffer,
        recovery: Buffer,
        receiver: Buffer,
        wait_time: number,
        request_time: number,
        amount: number,
        state: State,
    } | undefined = undefined) {
        if (fields) {
            this.owner = fields.owner;
            this.recovery = fields.recovery;
            this.receiver = fields.receiver;
            this.wait_time = fields.wait_time;
            this.request_time = fields.request_time;
            this.amount = fields.amount;
            this.state = fields.state;
        }
    }

    static schema = new Map([
        [VaultInfo, {
            kind: 'struct', fields: [
                ['owner', [32]],
                ['recovery', [32]],
                ['receiver', [32]],
                ['wait_time', 'u64'],
                ['request_time', 'u64'],
                ['amount', 'u64'],
                ['state', 'u8'],
            ]
        }],
    ]);

    static size = borsh.serialize(
        VaultInfo.schema,
        new VaultInfo(),
    ).length
};

let feesForOwner = 0;
let feesForRecovery = 0;

async function main() {

    const connection = new Connection(clusterApiUrl("testnet"), "confirmed");

    const programId = await getPublicKeyFromFile(PROGRAM_KEYPAIR_PATH);
    const kpOwner = await generateKeyPair(connection, 1);
    const kpRecovery = await generateKeyPair(connection, 1);
    const kpReceiver = await generateKeyPair(connection, 1);

    let ownerBalance = await connection.getBalance(kpOwner.publicKey);
    let receiverBalance = await connection.getBalance(kpReceiver.publicKey);

    console.log("programId:          ", programId.toBase58());
    console.log("owner:              ", kpOwner.publicKey.toBase58());
    console.log("owner's balance:    ", ownerBalance / LAMPORTS_PER_SOL, " SOL");
    console.log("receiver:           ", kpReceiver.publicKey.toBase58());
    console.log("receiver's balance: ", receiverBalance / LAMPORTS_PER_SOL, " SOL");
    console.log("recovery:           ", kpRecovery.publicKey.toBase58());

    // 0. Initialize the valult for the owner (IDLE) 
    console.log("\n--- Initialize. Actor: the onwer ---");
    const initialAmount = 0.2 * LAMPORTS_PER_SOL;
    const waitTime = 2;
    const stateAccountPublicKey = await initialize(
        connection,
        programId,
        kpOwner,
        kpRecovery.publicKey,
        waitTime,
        initialAmount
    );

    // 1. Withdraw  IDLE -> REQ
    console.log("\n--- Withdraw. Actor: the onwer ---");
    const withdrawAmount = initialAmount / 2;
    await withdraw(
        connection,
        programId,
        kpOwner,
        kpReceiver.publicKey,
        stateAccountPublicKey,
        withdrawAmount,
    );

    // Chose if to finalize or to cancel
    const choice: Action = Action.Cancel;
    switch (choice.valueOf()) {
        case Action.Finalize:// 3. Finalize  REQ -> IDLE
            console.log("\n--- Finalize. Actor: the onwer ---");
            await new Promise(resolve => setTimeout(resolve, 3000 * waitTime));
            await finalize(
                connection,
                programId,
                kpOwner,
                stateAccountPublicKey
            );
            break;

        case Action.Cancel:// 3. Cancel REQ -> IDLE
            console.log("\n--- Cancel. Actor: the Reovery ---");
            await cancel(
                connection,
                programId,
                kpRecovery,
                stateAccountPublicKey
            );
            break;
    }

    // Costs
    ownerBalance = await connection.getBalance(kpOwner.publicKey);
    receiverBalance = await connection.getBalance(kpReceiver.publicKey);
    console.log("\n........");
    console.log("Fees for owner:         ", feesForOwner / LAMPORTS_PER_SOL, " SOL");
    console.log("Fees for recovery:      ", feesForRecovery / LAMPORTS_PER_SOL, " SOL");
    console.log("Owner's balance:        ", ownerBalance / LAMPORTS_PER_SOL, " SOL");
    console.log("Receiver's balance:     ", receiverBalance / LAMPORTS_PER_SOL, " SOL");
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
    recoveryPubKey: PublicKey,
    waitTime: number,
    initialAmount: number
): Promise<PublicKey> {

    // Generate the public key for the state account
    const SEED = "abcdef" + Math.random().toString();
    const stateAccountPublicKey = await PublicKey.createWithSeed(kpOwner.publicKey, SEED, programId);

    // Instruction to create the State Account account
    const rentExemptionAmount = await connection.getMinimumBalanceForRentExemption(VaultInfo.size);
    const createStateAccountInstruction = SystemProgram.createAccountWithSeed({
        fromPubkey: kpOwner.publicKey,
        basePubkey: kpOwner.publicKey,
        seed: SEED,
        newAccountPubkey: stateAccountPublicKey,
        lamports: rentExemptionAmount + initialAmount,
        space: VaultInfo.size,
        programId: programId,
    });

    // Instruction to the program
    const initializeVaultInstruction = new TransactionInstruction({
        keys: [
            { pubkey: kpOwner.publicKey, isSigner: true, isWritable: false },
            { pubkey: stateAccountPublicKey, isSigner: false, isWritable: true },
            { pubkey: recoveryPubKey, isSigner: false, isWritable: false },
        ],
        programId,
        data: buildBufferFromActionAndNumber(Action.Initialize, waitTime),
    })

    const transaction = new Transaction().add(
        createStateAccountInstruction,
        initializeVaultInstruction
    );
    await sendAndConfirmTransaction(connection, transaction, [kpOwner]);

    let tFees = await getTransactionFees(transaction, connection);
    feesForOwner += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, ' SOL');

    return stateAccountPublicKey;
}

async function withdraw(
    connection: Connection,
    programId: PublicKey,
    kpOwner: Keypair,
    receiverPubKey: PublicKey,
    stateAccountPublicKey: PublicKey,
    withdrawAmount: number,
): Promise<void> {

    // Instruction to the program
    const initializeVaultInstruction = new TransactionInstruction({
        keys: [
            { pubkey: kpOwner.publicKey, isSigner: true, isWritable: false },
            { pubkey: stateAccountPublicKey, isSigner: false, isWritable: true },
            { pubkey: receiverPubKey, isSigner: false, isWritable: false },
        ],
        programId,
        data: buildBufferFromActionAndNumber(Action.Withdraw, withdrawAmount)
    });

    const transaction = new Transaction().add(initializeVaultInstruction);
    await sendAndConfirmTransaction(connection, transaction, [kpOwner]);

    let tFees = await getTransactionFees(transaction, connection);
    feesForOwner += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, ' SOL');
}

async function finalize(
    connection: Connection,
    programId: PublicKey,
    kpOwner: Keypair,
    stateAccountPublicKey: PublicKey,
): Promise<void> {

    // Get the recipient from the state account
    const stateAccountInfo = await connection.getAccountInfo(stateAccountPublicKey);
    if (stateAccountInfo == null) {
        throw new Error("Error: cannot find the state account");
    }
    const vaultInfo = borsh.deserialize(VaultInfo.schema, VaultInfo, stateAccountInfo.data,);
    const recepientPubKey = new PublicKey(vaultInfo.receiver);

    // Instruction to the program
    let initializeVaultInstruction = new TransactionInstruction({
        keys: [
            { pubkey: kpOwner.publicKey, isSigner: true, isWritable: false },
            { pubkey: stateAccountPublicKey, isSigner: false, isWritable: true },
            { pubkey: recepientPubKey, isSigner: false, isWritable: true },
        ],
        programId,
        data: Buffer.from(new Uint8Array([Action.Finalize])),
    })

    const transaction = new Transaction().add(initializeVaultInstruction);
    await sendAndConfirmTransaction(connection, transaction, [kpOwner]);

    let tFees = await getTransactionFees(transaction, connection);
    feesForOwner += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, ' SOL');
}

async function cancel(
    connection: Connection,
    programId: PublicKey,
    kpRecovery: Keypair,
    stateAccountPublicKey: PublicKey,
): Promise<void> {

    // Instruction to the program
    let initializeVaultInstruction = new TransactionInstruction({
        keys: [
            { pubkey: kpRecovery.publicKey, isSigner: true, isWritable: false },
            { pubkey: stateAccountPublicKey, isSigner: false, isWritable: true },
        ],
        programId,
        data: Buffer.from(new Uint8Array([Action.Cancel])),
    })

    const transaction = new Transaction().add(initializeVaultInstruction);
    await sendAndConfirmTransaction(connection, transaction, [kpRecovery]);

    let tFees = await getTransactionFees(transaction, connection);
    feesForRecovery += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, ' SOL');
}