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
    Join,
    Win,
    Timeout,
}

const SEED_FOR_PDA = "oracle_bet";

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
    const wagerInLamports = 0.1 * LAMPORTS_PER_SOL;

    /******************* Trace 1 *********************/
    console.log("\n---       Trace 1       ---");
    console.log("All participants join and the oracle choses the winner");

    console.log("\n--- Initialize. ---");
    const contractStoragePubKey = await initialize(
        connection,
        programId,
        kpOracle,
        kpParticipant1.publicKey,
        kpParticipant2.publicKey,
        deadlineSlot,
        wagerInLamports
    );

    console.log('\n--- Join participants ---');
    await join(
        connection,
        programId,
        kpParticipant1,
        kpParticipant2,
        contractStoragePubKey,
    );

    const winnerPubKey = kpParticipant1.publicKey;
    console.log('\n--- Oracle sets the result: winner: ', winnerPubKey.toBase58(), ' ---');
    await win(
        connection,
        programId,
        kpOracle,
        contractStoragePubKey,
        winnerPubKey,
    );

    // Costs
    console.log("\n........");
    console.log("Total fees:            ", totalFees / LAMPORTS_PER_SOL, "SOL");

    totalFees = 0;

    // /******************* Trace 2 *********************/
    console.log("\n---       Trace 2       ---");
    console.log("All participants join and the oracle does not set the winner");

    console.log("\n--- Initialize. ---");
    const contractStoragePubKey2 = await initialize(
        connection,
        programId,
        kpOracle,
        kpParticipant1.publicKey,
        kpParticipant2.publicKey,
        deadlineSlot,
        wagerInLamports
    );

    console.log('\n--- Join participants ---');
    await join(
        connection,
        programId,
        kpParticipant1,
        kpParticipant2,
        contractStoragePubKey2,
    );

    console.log('\n--- Oracle does not set the result. ---');

    console.log('\n--- Waiting for the deadline ---');
    while (await connection.getSlot() < deadlineSlot) {
        await new Promise(f => setTimeout(f, 1000));//sleep 1 second
    }
    console.log('Deadline reached');

    console.log('\n--- Timeout ---');

    await timeout(
        connection,
        programId,
        kpOracle,
        kpParticipant1.publicKey,
        kpParticipant2.publicKey,
        contractStoragePubKey2,
    );
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

    const contractStoragePubKey = await getPDA(programId, kpOracle.publicKey);

    interface Settings { action: number, deadline: number, wagerInLamports: number }
    const layout = BufferLayout.struct<Settings>([BufferLayout.u8("action"), BufferLayout.nu64("deadline"), BufferLayout.nu64("wagerInLamports")]);
    const dataToSend = Buffer.alloc(layout.span);
    layout.encode({ action: Action.Initialize, deadline, wagerInLamports }, dataToSend);

    const transaction = new Transaction().add(
        new TransactionInstruction({
        programId: programId,
        keys: [
            { pubkey: kpOracle.publicKey, isSigner: true, isWritable: true },
            { pubkey: participant1PubKey, isSigner: false, isWritable: false },
            { pubkey: participant2PubKey, isSigner: false, isWritable: false },
            { pubkey: contractStoragePubKey, isSigner: false, isWritable: true },
            { pubkey: SystemProgram.programId, isSigner: false, isWritable: false }
        ],
        data: dataToSend
    }));

    const signature = await sendAndConfirmTransaction(connection, transaction, [kpOracle]);

    const tFees = await getTransactionFees(transaction, connection);
    totalFees += tFees;
    console.log('    Transaction hash: ', signature);
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');

    return contractStoragePubKey;
}

async function join(
    connection: Connection,
    programId: PublicKey,
    kpParticipant1: Keypair,
    kpParticipant2: Keypair,
    contractStoragePubKey: PublicKey,
) {
    const joinInstruction = new TransactionInstruction({
        programId: programId,
        keys: [
            { pubkey: kpParticipant1.publicKey, isSigner: true, isWritable: true },
            { pubkey: kpParticipant2.publicKey, isSigner: true, isWritable: true },
            { pubkey: contractStoragePubKey, isSigner: false, isWritable: true },
            { pubkey: SystemProgram.programId, isSigner: false, isWritable: false }
        ],
        data: Buffer.from([Action.Join])
    });

    const transaction = new Transaction().add(
        joinInstruction
    );

    const signature = await sendAndConfirmTransaction(connection, transaction, [kpParticipant1, kpParticipant2]);
    console.log('    Transaction hash: ', signature);

    const tFees = await getTransactionFees(transaction, connection);
    totalFees += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

async function win(
    connection: Connection,
    programId: PublicKey,
    kpOracle: Keypair,
    contractStoragePubKey: PublicKey,
    winner: PublicKey,
) {
    const setResultInstruction = new TransactionInstruction({
        programId: programId,
        keys: [
            { pubkey: kpOracle.publicKey, isSigner: true, isWritable: true },
            { pubkey: winner, isSigner: false, isWritable: true },
            { pubkey: contractStoragePubKey, isSigner: false, isWritable: true },
        ],
        data: Buffer.from([Action.Win])
    });

    const transaction = new Transaction().add(setResultInstruction);

    const signature = await sendAndConfirmTransaction(connection, transaction, [kpOracle]);
    console.log('    Transaction hash: ', signature);

    const tFees = await getTransactionFees(transaction, connection);
    totalFees += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

async function timeout(
    connection: Connection,
    programId: PublicKey,
    kpOracle: Keypair,
    participant1PubKey: PublicKey,
    participant2PubKey: PublicKey,
    contractStoragePubKey: PublicKey,
) {
    const transaction = new Transaction().add(
         new TransactionInstruction({
        programId: programId,
        keys: [
            { pubkey: kpOracle.publicKey, isSigner: true, isWritable: true },
            { pubkey: participant1PubKey, isSigner: false, isWritable: true },
            { pubkey: participant2PubKey, isSigner: false, isWritable: true },
            { pubkey: contractStoragePubKey, isSigner: false, isWritable: true },
        ],
        data: Buffer.from([Action.Timeout])
    }));

    const signature = await sendAndConfirmTransaction(connection, transaction, [kpOracle]);
    console.log('    Transaction hash: ', signature);

    const tFees = await getTransactionFees(transaction, connection);
    totalFees += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

async function getPDA(programId: PublicKey, oraclePubkey: PublicKey): Promise<PublicKey> {
    const [pda] = await PublicKey.findProgramAddress(
        [Buffer.from(SEED_FOR_PDA), oraclePubkey.toBuffer()],
        programId
    );
    return pda;
}
