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

const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../contracts/dist/crowdfund/crowdfund-keypair.json');

enum Action {
    CreateCampaign = 0,
    Donate = 1,
    Withdraw = 2,
    Reclaim = 3,
}

class Campaign {
    receiver: Buffer = Buffer.alloc(32);
    end_donate_slot: number = 0;
    goal: number = 0;

    constructor(fields: {
        receiver: Buffer,
        end_donate_slot: number,
        goal: number,
    } | undefined = undefined) {
        if (fields) {
            this.receiver = fields.receiver;
            this.end_donate_slot = fields.end_donate_slot;
            this.goal = fields.goal;
        }
    }

    static schema = new Map([
        [Campaign, {
            kind: 'struct', fields: [
                ['receiver', [32]],
                ['end_donate_slot', 'u64'],
                ['goal', 'u64'],
            ]
        }],
    ]);
}

class DonationInfo {
    donor: Buffer = Buffer.alloc(32);
    receiver_campaign: Buffer = Buffer.alloc(32);
    amount_donated: number = 0;

    constructor(fields: {
        donor: Buffer,
        receiver_campaign: Buffer,
        amount_donated: number,
    } | undefined = undefined) {
        if (fields) {
            this.donor = fields.donor;
            this.receiver_campaign = fields.receiver_campaign;
            this.amount_donated = fields.amount_donated;
        }
    }

    static schema = new Map([
        [DonationInfo, {
            kind: 'struct', fields: [
                ['donor', [32]],
                ['receiver_campaign', [32]],
                ['amount_donated', 'u64'],
            ]
        }],
    ]);
}

let feesForCreator = 0;
let feesForDonor = 0;

const SEED_FOR_DONATION_ACCOUNTS = "Donation";

async function main() {

    const connection = getConnection();

    const programId = await getPublicKeyFromFile(PROGRAM_KEYPAIR_PATH);
    const kpCreator = await generateKeyPair(connection, 1);
    const kpDonor = await generateKeyPair(connection, 1);

    await printParticipants(connection, programId, [
        ["creator", kpCreator.publicKey],
        ["donor", kpDonor.publicKey],
    ]);

    // 1. Create campaign
    console.log("\n--- Create campaign. Actor: the creator ---");
    const nSlotsToWait = 10;
    console.log('    Duration:', nSlotsToWait, 'slots');

    const campaign = new Campaign({
        receiver: kpCreator.publicKey.toBuffer(),
        end_donate_slot: await connection.getSlot() + nSlotsToWait,
        goal: 0.1 * LAMPORTS_PER_SOL, // 0.1 SOL
    });

    const campaignAccountPubKey = await createCampaign(
        connection,
        programId,
        kpCreator,
        campaign
    );

    // 2. Donate
    console.log("\n--- Donate to campaign. Actor: the donor ---");
    const donatedAmount = campaign.goal;
    console.log("    Amount:", donatedAmount / LAMPORTS_PER_SOL, "SOL");
    await donate(
        connection,
        programId,
        kpDonor,
        campaignAccountPubKey,
        donatedAmount
    );

    // Wait for the campaign to end
    console.log("\nWaiting", nSlotsToWait, "slots for the campaign to end...");
    while (await connection.getSlot() < campaign.end_donate_slot) {
        await new Promise(f => setTimeout(f, 1000));//sleep 1 second
    }

    // Chose if to withdraw or to reclaim
    const choice: Action = Action.Withdraw;

    switch (choice.valueOf()) {
        case Action.Withdraw:     // 3. Withdraw
            console.log("\n--- Withdraw. Actor: the creator ---");
            await withdraw(
                connection,
                programId,
                kpCreator,
                campaignAccountPubKey,
            );
            break;

        case Action.Reclaim:    // 3. Reclaim
            console.log("\n--- Reclaim. Actor: the donor ---");
            await reclaim(
                connection,
                programId,
                kpDonor,
                campaignAccountPubKey,
            );
            break;
    }

    // Costs
    console.log("\n........");
    console.log("Fees for creator:  ", feesForCreator / LAMPORTS_PER_SOL, "SOL");
    console.log("Fees for donor:    ", feesForDonor / LAMPORTS_PER_SOL, "SOL");
    console.log("Total fees:        ", (feesForCreator + feesForDonor) / LAMPORTS_PER_SOL, "SOL");
}

main().then(
    () => process.exit(),
    err => {
        console.error(err);
        process.exit(-1);
    }
);

async function createCampaign(
    connection: Connection,
    programId: PublicKey,
    kpCreator: Keypair,
    campaign: Campaign,
): Promise<PublicKey> {

    const data = borsh.serialize(Campaign.schema, campaign);

    const SEED = "abcdef" + Math.random().toString();
    const campaignAccountPubKey = await PublicKey.createWithSeed(kpCreator.publicKey, SEED, programId);

    // Instruction to create the campaign Account
    const createCampaignAccountInstruction = SystemProgram.createAccountWithSeed({
        fromPubkey: kpCreator.publicKey,
        basePubkey: kpCreator.publicKey,
        seed: SEED,
        newAccountPubkey: campaignAccountPubKey,
        lamports: await connection.getMinimumBalanceForRentExemption(data.length),
        space: data.length,
        programId: programId,
    });

    // Instruction to the program
    const createCampaignInstruction = new TransactionInstruction({
        keys: [
            { pubkey: kpCreator.publicKey, isSigner: true, isWritable: false },
            { pubkey: campaignAccountPubKey, isSigner: false, isWritable: true },
        ],
        programId,
        data: Buffer.from(new Uint8Array([Action.CreateCampaign, ...data])),
    })

    const transaction = new Transaction().add(
        createCampaignAccountInstruction,
        createCampaignInstruction
    );

    await sendAndConfirmTransaction(connection, transaction, [kpCreator]);

    const tFees = await getTransactionFees(transaction, connection);
    feesForCreator += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');

    return campaignAccountPubKey;
}

async function donate(
    connection: Connection,
    programId: PublicKey,
    kpDonor: Keypair,
    campaignAccountPubKey: PublicKey,
    donatedAmount: number,
): Promise<void> {

    const donationInfo = new DonationInfo({
        donor: kpDonor.publicKey.toBuffer(),
        receiver_campaign: campaignAccountPubKey.toBuffer(),
        amount_donated: donatedAmount,
    });

    const data = borsh.serialize(DonationInfo.schema, donationInfo);

    // Instruction to create the Donation Account
    const donationAccountPubKey = await PublicKey.createWithSeed(kpDonor.publicKey, SEED_FOR_DONATION_ACCOUNTS, programId);

    const rentExemptionAmount = await connection.getMinimumBalanceForRentExemption(data.length);
    const createDonationAccountInstruction = SystemProgram.createAccountWithSeed({
        fromPubkey: kpDonor.publicKey,
        basePubkey: kpDonor.publicKey,
        seed: SEED_FOR_DONATION_ACCOUNTS,
        newAccountPubkey: donationAccountPubKey,
        lamports: rentExemptionAmount + donatedAmount,
        space: data.length,
        programId: programId,
    });

    // Instruction to the program
    const donationInstruction = new TransactionInstruction({
        keys: [
            { pubkey: kpDonor.publicKey, isSigner: true, isWritable: false },
            { pubkey: campaignAccountPubKey, isSigner: false, isWritable: true },
            { pubkey: donationAccountPubKey, isSigner: false, isWritable: true },
        ],
        programId,
        data: Buffer.from(new Uint8Array([Action.Donate, ...data]))
    })

    const transaction = new Transaction().add(
        createDonationAccountInstruction,
        donationInstruction
    );

    await sendAndConfirmTransaction(connection, transaction, [kpDonor]);

    const tFees = await getTransactionFees(transaction, connection);
    feesForDonor += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

async function withdraw(
    connection: Connection,
    programId: PublicKey,
    kpCreator: Keypair,
    campaignAccountPubKey: PublicKey,
): Promise<void> {

    const transaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: kpCreator.publicKey, isSigner: true, isWritable: false },
                { pubkey: campaignAccountPubKey, isSigner: false, isWritable: true },
            ],
            programId,
            data: Buffer.from(new Uint8Array([Action.Withdraw])),
        })
    );

    await sendAndConfirmTransaction(connection, transaction, [kpCreator]);

    const tFees = await getTransactionFees(transaction, connection);
    feesForCreator += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

async function reclaim(
    connection: Connection,
    programId: PublicKey,
    kpDonor: Keypair,
    campaignAccountPubKey: PublicKey,
): Promise<void> {

    const donationAccountPubKey = await PublicKey.createWithSeed(kpDonor.publicKey, SEED_FOR_DONATION_ACCOUNTS, programId);

    const transaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: kpDonor.publicKey, isSigner: true, isWritable: false },
                { pubkey: campaignAccountPubKey, isSigner: false, isWritable: true },
                { pubkey: donationAccountPubKey, isSigner: false, isWritable: true },
            ],
            programId,
            data: Buffer.from(new Uint8Array([Action.Reclaim])),
        })
    );

    await sendAndConfirmTransaction(connection, transaction, [kpDonor]);

    const tFees = await getTransactionFees(transaction, connection);
    feesForDonor += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}
