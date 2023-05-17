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
    getTransactionFees,
    printParticipants,
} from './utils';

import * as borsh from 'borsh';
import path from 'path';
import { Buffer } from 'buffer';
import * as BufferLayout from '@solana/buffer-layout';

const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../solana/dist/vesting/vesting-keypair.json');

enum Action {
    Initialize = 0,
    Release = 1
}

class VestingInfo {
    released: number = 0;
    funder: Buffer = Buffer.alloc(32);
    beneficiary: Buffer = Buffer.alloc(32);
    start: number = 0;
    duration: number = 0;

    constructor(fields: {
        released: number,
        funder: Buffer,
        beneficiary: Buffer,
        start: number,
        duration: number,
    } | undefined = undefined) {
        if (fields) {
            this.released = fields.released;
            this.funder = fields.funder;
            this.beneficiary = fields.beneficiary;
            this.start = fields.start;
            this.duration = fields.duration;
        }
    }

    static schema = new Map([
        [VestingInfo, {
            kind: 'struct', fields: [
                ['released', 'u64'],
                ['funder', [32]],
                ['beneficiary', [32]],
                ['start', 'u64'],
                ['duration', 'u64'],
            ]
        }],
    ]);
}

let feesForFounder = 0;
let feesForBeneficiary = 0;

async function main() {

    const connection = getConnection();

    const programId = await getPublicKeyFromFile(PROGRAM_KEYPAIR_PATH);
    const kpFunder = await generateKeyPair(connection, 1);
    const kpBeneficiary = await generateKeyPair(connection, 1);

    await printParticipants(connection, programId, [
        ["funder", kpFunder.publicKey],
        ["beneficiary", kpBeneficiary.publicKey],
    ]);

    /*
    There could be 3 possible scenarios at the moment when the beneficiary releases the funds:
        
        1)  current slot < start
            The beneficiary will obtain 0 SOL
        
        2)  current slot  > start + duration
            The beneficiary will obtain all the funds
        
        3)  Otherwise the beneficiary obtains a fraction of the funds
    */

    // Chose the number of the scenario
    const scenario: number = 2;

    let startSlot = 0;
    let duration = 1;
    let targetSlotToWait = 0;
    switch (scenario.valueOf()) {
        case 1:
            console.log("\nScenario 1: current slot < start");
            console.log("The beneficiary will obtain 0 SOL");
            startSlot = await connection.getSlot() + 9999999; // a big number
            duration = 9999999; // a big number
            targetSlotToWait = await connection.getSlot();
            break;

        case 2:
            console.log("\nScenario 2: current slot > start + duration");
            console.log("The beneficiary will obtain all the funds");
            startSlot = await connection.getSlot() + 10; // a small number
            duration = 1; // a small number
            targetSlotToWait = startSlot + duration;
            break

        case 3:
            console.log("\nScenario 3: The beneficiary obtains a fraction of the funds");
            startSlot = await connection.getSlot() + 10; // a big number
            duration = 200;
            targetSlotToWait = startSlot + duration / 2;
            break
    }

    // 1. Initialize (the founder initializes and deposits an amout of SOL)
    console.log("\n--- Initialize. Actor: the founder ---");
    const amount = 0.2 * LAMPORTS_PER_SOL; // 0.2 SOL
    console.log('    Amount:', amount / LAMPORTS_PER_SOL, 'SOL');
    let vestingInfo = new VestingInfo({
        released: 0,
        funder: kpFunder.publicKey.toBuffer(),
        beneficiary: kpBeneficiary.publicKey.toBuffer(),
        start: startSlot,
        duration,
    });
    const vestingInfoAccountPublicKey = await initialize(
        connection,
        programId,
        kpFunder,
        vestingInfo,
        amount
    );

    if (scenario != 1) {
        console.log("\nWaiting to reach the targhet slot");
        while (await connection.getSlot() < targetSlotToWait) {
            await new Promise(f => setTimeout(f, 1000));//sleep 1 second
        }
    }

    // 2. Release 
    console.log("\n--- Release. Actor: the beneficiary ---");
    await release(
        connection,
        programId,
        kpBeneficiary,
        vestingInfoAccountPublicKey,
    );

    // Costs
    const beneficiaryBalance = await connection.getBalance(kpBeneficiary.publicKey);

    console.log("\n........");
    console.log("Fees for funder:      ", feesForFounder / LAMPORTS_PER_SOL, "SOL");
    console.log("Fees for beneficiary: ", feesForBeneficiary / LAMPORTS_PER_SOL, "SOL");
    console.log("Total fees:           ", (feesForFounder + feesForBeneficiary) / LAMPORTS_PER_SOL, "SOL");
    console.log("Beneficiary's balance:", beneficiaryBalance / LAMPORTS_PER_SOL, "SOL");
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
    kpFunder: Keypair,
    vestingInfo: VestingInfo,
    amount: number,
): Promise<PublicKey> {

    let serializedVestingInfo = borsh.serialize(VestingInfo.schema, vestingInfo);

    const SEED = "abcdef" + Math.random().toString();
    const vestingInfoAccountPublicKey = await PublicKey.createWithSeed(kpFunder.publicKey, SEED, programId);

    // Instruction to create the Writing Account
    const rentExemptionAmount = await connection.getMinimumBalanceForRentExemption(serializedVestingInfo.length);
    const createvestingInfoAccountInstruction = SystemProgram.createAccountWithSeed({
        fromPubkey: kpFunder.publicKey,
        basePubkey: kpFunder.publicKey,
        seed: SEED,
        newAccountPubkey: vestingInfoAccountPublicKey,
        lamports: rentExemptionAmount + amount,
        space: serializedVestingInfo.length,
        programId: programId,
    });

    // Instruction to the program
    interface Settings { action: number, start: number, duration: number }
    const layout = BufferLayout.struct<Settings>([BufferLayout.u8("action"), BufferLayout.nu64("start"), BufferLayout.nu64("duration")]);
    const dataToSend = Buffer.alloc(layout.span);
    layout.encode({ action: Action.Initialize, start: vestingInfo.start, duration: vestingInfo.duration }, dataToSend);

    const initializeInstruction = new TransactionInstruction({
        keys: [
            { pubkey: kpFunder.publicKey, isSigner: true, isWritable: false },
            { pubkey: new PublicKey(vestingInfo.beneficiary), isSigner: false, isWritable: false },
            { pubkey: vestingInfoAccountPublicKey, isSigner: false, isWritable: true },
        ],
        programId,
        data: dataToSend,
    })

    const transactionDeposit = new Transaction().add(
        createvestingInfoAccountInstruction,
        initializeInstruction
    );

    await sendAndConfirmTransaction(connection, transactionDeposit, [kpFunder]);

    const tFees = await getTransactionFees(transactionDeposit, connection);
    feesForFounder += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');

    return vestingInfoAccountPublicKey;
}

async function release(
    connection: Connection,
    programId: PublicKey,
    kpBeneficiary: Keypair,
    vestingInfoAccountPublicKey: PublicKey,
): Promise<void> {

    // Deserialize the data from the vestingInfoAccountPublicKey to get the funder's public key
    const accountInfo = await connection.getAccountInfo(vestingInfoAccountPublicKey);
    if (accountInfo === null) {
        throw 'Error: cannot find the vestingInfo account';
    }
    const vestingInfo = borsh.deserialize(VestingInfo.schema, VestingInfo, accountInfo.data);

    const transaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: kpBeneficiary.publicKey, isSigner: true, isWritable: false },
                { pubkey: vestingInfoAccountPublicKey, isSigner: false, isWritable: true },
                { pubkey: new PublicKey(vestingInfo.funder), isSigner: false, isWritable: true },
            ],
            programId,
            data: Buffer.from(new Uint8Array([Action.Release]))
        })
    );

    await sendAndConfirmTransaction(connection, transaction, [kpBeneficiary]);

    const tFees = await getTransactionFees(transaction, connection);
    feesForBeneficiary += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}