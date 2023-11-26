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
    printParticipants,
    getTransactionFees,
} from './utils';

import * as BufferLayout from '@solana/buffer-layout';

import path from 'path';
import * as borsh from 'borsh';

const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../contracts/dist/oracle_bet/oracle_bet-keypair.json');

enum Action {
    Initialize = 0,
    Bet,
    OracleSetResult,
}

class OracleBetInfo {
    oracle: Buffer = Buffer.alloc(32);
    participant1: Buffer = Buffer.alloc(32);
    participant2: Buffer = Buffer.alloc(32);
    wager: number = 0;
    deadline: number = 0;
    participant1_has_deposited: boolean = false;
    participant2_has_deposited: boolean = false;
    winner_was_chosen: boolean = false;

    constructor(fields: {
        oracle: Buffer,
        participant1: Buffer,
        participant2: Buffer,
        wager: number,
        deadline: number,
        participant1_has_deposited: boolean,
        participant2_has_deposited: boolean,
        winner_was_chosen: boolean,
    } | undefined = undefined) {
        if (fields) {
            this.oracle = fields.oracle;
            this.participant1 = fields.participant1;
            this.participant2 = fields.participant2;
            this.wager = fields.wager;
            this.deadline = fields.deadline;
            this.participant1_has_deposited = fields.participant1_has_deposited;
            this.participant2_has_deposited = fields.participant2_has_deposited;
            this.winner_was_chosen = fields.winner_was_chosen;
        }
    }

    static schema = new Map([
        [OracleBetInfo, {
            kind: 'struct', fields: [
                ['oracle', [32]],
                ['participant1', [32]],
                ['participant2', [32]],
                ['wager', 'u64'],
                ['deadline', 'u64'],
                ['participant1_has_deposited', 'u8'],
                ['participant2_has_deposited', 'u8'],
                ['winner_was_chosen', 'u8'],
            ]
        }],
    ]);

    static size = borsh.serialize(
        OracleBetInfo.schema,
        new OracleBetInfo(),
    ).length
};


let totalFees = 0;

async function main() {

    const connection = getConnection();

    const programId = await getPublicKeyFromFile(PROGRAM_KEYPAIR_PATH);
    const kpOracle = await generateKeyPair(connection, 1);
    const kpParticipant1 = await generateKeyPair(connection, 1);
    const kpParticipant2 = await generateKeyPair(connection, 1);

    await printParticipants(connection, programId, [
        ["oracle", kpOracle.publicKey],
        ["kpParticipant1", kpParticipant1.publicKey],
        ["kpParticipant2", kpParticipant2.publicKey],
    ]);

    const deadlineSlot = await connection.getSlot() + 10;
    const wagerInLamports = 100;

    /******************* Trace 1 *********************/
    console.log("\n---       Trace 1       ---");
    console.log("All participants join and the oracle choses the winner");

    // 1. Initialize
    console.log("\n--- Initialize. ---");
    const oracleBetPubKey = await initialize(
        connection,
        programId,
        kpOracle,
        kpParticipant1.publicKey,
        kpParticipant2.publicKey,
        deadlineSlot,
        wagerInLamports
    );

    console.log('\n--- Join participant 1 ---');
    await bet(
        connection,
        programId,
        kpParticipant1,
        oracleBetPubKey,
        wagerInLamports,
    );

    console.log('\n--- Join participant 2 ---');
    await bet(
        connection,
        programId,
        kpParticipant2,
        oracleBetPubKey,
        wagerInLamports,
    );

    console.log('\n--- Waiting for the deadline ---');
    while (await connection.getSlot() <  deadlineSlot) {
        await new Promise(f => setTimeout(f, 1000));//sleep 1 second
    }
    console.log('Deadline reached');

    const winnerPubKey = kpParticipant1.publicKey;
    console.log('\n--- Oracle sets the result: winner: ', winnerPubKey.toBase58(), ' ---');
    await oracleSetResult(
        connection,
        programId,
        kpOracle,
        oracleBetPubKey,
        winnerPubKey,
    );

    // Costs
    console.log("\n........");
    console.log("Total fees:            ", totalFees / LAMPORTS_PER_SOL, "SOL");

    totalFees = 0;
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
    kpOracle: Keypair,
    participant1PubKey: PublicKey,
    participant2PubKey: PublicKey,
    deadline: number,
    wagerInLamports: number,
): Promise<PublicKey> {

    console.log('The oracle starts the game setting a deadline to', deadline, ' and a wager of', wagerInLamports, 'lamports');

    // Generate the public key for the state account
    const SEED = "abcdef" + Math.random().toString();
    const oracleBetPubKey = await PublicKey.createWithSeed(kpOracle.publicKey, SEED, programId);

    // Instruction to create the State Account account
    const rentExemptionAmount = await connection.getMinimumBalanceForRentExemption(OracleBetInfo.size);
    const createStateAccountInstruction = SystemProgram.createAccountWithSeed({
        fromPubkey: kpOracle.publicKey,
        basePubkey: kpOracle.publicKey,
        seed: SEED,
        newAccountPubkey: oracleBetPubKey,
        lamports: rentExemptionAmount,
        space: OracleBetInfo.size,
        programId: programId,
    });

    // Encode the data to send
    interface Settings { action: number, deadline: number, wagerInLamports: number }
    const layout = BufferLayout.struct<Settings>([BufferLayout.u8("action"), BufferLayout.nu64("deadline"), BufferLayout.nu64("wagerInLamports")]);
    const dataToSend = Buffer.alloc(layout.span);
    layout.encode({ action: Action.Initialize, deadline, wagerInLamports }, dataToSend);

    const initInstruction = new TransactionInstruction({
        programId: programId,
        keys: [
            { pubkey: kpOracle.publicKey, isSigner: true, isWritable: true },
            { pubkey: participant1PubKey, isSigner: false, isWritable: false },
            { pubkey: participant2PubKey, isSigner: false, isWritable: false },
            { pubkey: oracleBetPubKey, isSigner: false, isWritable: true },
        ],
        data: dataToSend
    });

    const transaction = new Transaction().add(createStateAccountInstruction, initInstruction);

    const signature = await sendAndConfirmTransaction(connection, transaction, [kpOracle]);

    const tFees = await getTransactionFees(transaction, connection);
    totalFees += tFees;
    console.log('    Transaction hash: ', signature);
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');

    return oracleBetPubKey;
}

async function bet(
    connection: Connection,
    programId: PublicKey,
    kpParticipant: Keypair,
    oracleBetPubKey: PublicKey,
    wagerInLamports: number
) {

    const transferInstruction = SystemProgram.transfer({
        fromPubkey: kpParticipant.publicKey,
        toPubkey: oracleBetPubKey,
        lamports: wagerInLamports,
    });

    const joinInstruction = new TransactionInstruction({
        programId: programId,
        keys: [
            { pubkey: kpParticipant.publicKey, isSigner: true, isWritable: true },
            { pubkey: oracleBetPubKey, isSigner: false, isWritable: true },
            { pubkey: SystemProgram.programId, isSigner: false, isWritable: false }
        ],
        data: Buffer.from([Action.Bet])
    });

    const transaction = new Transaction().add(transferInstruction, joinInstruction);

    const signature = await sendAndConfirmTransaction(connection, transaction, [kpParticipant]);
    console.log('    Transaction hash: ', signature);

    const tFees = await getTransactionFees(transaction, connection);
    totalFees += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

async function oracleSetResult(
    connection: Connection,
    programId: PublicKey,
    kpOracle: Keypair,
    oracleBetPubKey: PublicKey,
    winner: PublicKey,
) {
    const setResultInstruction = new TransactionInstruction({
        programId: programId,
        keys: [
            { pubkey: kpOracle.publicKey, isSigner: true, isWritable: true },
            { pubkey: winner, isSigner: false, isWritable: true },
            { pubkey: oracleBetPubKey, isSigner: false, isWritable: true },
        ],
        data: Buffer.from([Action.OracleSetResult])
    });

    const transaction = new Transaction().add(setResultInstruction);

    const signature = await sendAndConfirmTransaction(connection, transaction, [kpOracle]);
    console.log('    Transaction hash: ', signature);

    const tFees = await getTransactionFees(transaction, connection);
    totalFees += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}