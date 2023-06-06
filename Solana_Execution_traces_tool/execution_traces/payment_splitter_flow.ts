import {
    Connection,
    Keypair,
    Struct,
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
    getTransactionFees,
    printParticipants,
} from './utils';

import path from 'path';
import * as borsh from 'borsh';

const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../contracts/dist/payment_splitter/payment_splitter-keypair.json');

enum Action {
    Initialize = 0,
    Release = 1,
}

class PaymentSplitterInfo extends Struct {
    constructor(properties: any) {
        super(properties);
    }

    encode(): Buffer {
        return Buffer.from(borsh.serialize(PS_INFO_SCHEMA, this));
    }

    static decode(data: Buffer): PaymentSplitterInfo {
        return borsh.deserialize(PS_INFO_SCHEMA, this, data);
    }
}

const PS_INFO_SCHEMA = new Map([
    [
        PaymentSplitterInfo,
        {
            kind: "struct",
            fields: [
                [
                    "shares_map",
                    { kind: "map", key: [32], value: "u64" },
                ],
                [
                    "released_map",
                    { kind: "map", key: [32], value: "u64" },
                ],
                ['initial_lamports', 'u64'],
            ],
        },
    ],
]);

const PS_SEED = "PS_SEEDsssssdsssssssdd";

let feesForInitializer = 0;
let feesForPayees = 0;

async function main() {

    const connection = getConnection();

    const programId = await getPublicKeyFromFile(PROGRAM_KEYPAIR_PATH);
    const kpInitializer = await generateKeyPair(connection, 1);
    const kpPayee1 = await generateKeyPair(connection, 1);
    const kpPayee2 = await generateKeyPair(connection, 1);

    await printParticipants(connection, programId, [
        ["Initializer", kpInitializer.publicKey],
        ["kpPayee1", kpPayee1.publicKey],
        ["kpPayee2", kpPayee2.publicKey],
    ]);

    // 1. Initialize
    const shares_map = new Map<Buffer, number>();
    shares_map.set(kpPayee1.publicKey.toBuffer(), 1);
    shares_map.set(kpPayee2.publicKey.toBuffer(), 1);
    const initial_lamports = 0.5 * LAMPORTS_PER_SOL;
    console.log("\n--- Initialize with ", initial_lamports / LAMPORTS_PER_SOL, " SOL. Actor: the initializer ---");
    printShareMap(shares_map);
    await initialize(
        connection,
        programId,
        kpInitializer,
        shares_map,
        initial_lamports);

    // 2. Release
    console.log("\n--- Release. Actor: the payee1 ---");
    await release(
        connection,
        programId,
        kpPayee1,);

    // 2. Release
    console.log("\n--- Release. Actor: the payee2 ---");
    await release(
        connection,
        programId,
        kpPayee2,);

    // Costs
    console.log("\n........");
    console.log("Fees for initializer:     ", feesForInitializer / LAMPORTS_PER_SOL, "SOL");
    console.log("Fees for payees:          ", feesForPayees / LAMPORTS_PER_SOL, "SOL");
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
    kdInitializer: Keypair,
    shares_map: Map<Buffer, number>,
    initial_lamports: number,
): Promise<void> {

    const psPDAPubKey = await getPSPDA(programId);

    let released_map: Map<Buffer, number> = new Map();
    shares_map.forEach((value, key) => {
        released_map.set(key, 0);
    });
    const psInfo = new PaymentSplitterInfo({
        shares_map,
        released_map,
        initial_lamports,
    });

    const transaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: kdInitializer.publicKey, isSigner: true, isWritable: false },
                { pubkey: psPDAPubKey, isSigner: false, isWritable: true },
                { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
            ],
            programId,
            data: Buffer.from(new Uint8Array([Action.Initialize, ...psInfo.encode()])),
        }));
    await sendAndConfirmTransaction(connection, transaction, [kdInitializer]);

    let tFees = await getTransactionFees(transaction, connection);
    feesForInitializer += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');

}


async function getPSPDA(programId: PublicKey): Promise<PublicKey> {
    const [ammPDA] = await PublicKey.findProgramAddress(
        [Buffer.from(PS_SEED)],
        programId
    );
    return ammPDA;
}

async function release(
    connection: Connection,
    programId: PublicKey,
    kpPayee: Keypair,
): Promise<void> {

    const psPDAPubKey = await getPSPDA(programId);

    const transaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: kpPayee.publicKey, isSigner: true, isWritable: false },
                { pubkey: psPDAPubKey, isSigner: false, isWritable: true },
                { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
            ],
            programId,
            data: Buffer.from(new Uint8Array([Action.Release])),
        }));
    await sendAndConfirmTransaction(connection, transaction, [kpPayee]);

    let tFees = await getTransactionFees(transaction, connection);
    feesForPayees += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

function printShareMap(shares_map: Map<Buffer, number>): void {
    console.log("    Share Map:");
    shares_map.forEach((value, key) => {
        console.log("       ", new PublicKey(key).toBase58(), ": ", value);
    });
}