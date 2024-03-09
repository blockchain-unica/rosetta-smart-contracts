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

const PROGRAM_KEYPAIR_PATH = path.resolve(__dirname, '../contracts/dist/auction/auction-keypair.json');

enum Action {
    Start = 0,
    Bid = 1,
    End = 2,
}

class AuctionState {
    auction_name: string = "";
    seller: Buffer = Buffer.alloc(32);
    highest_bidder: Buffer = Buffer.alloc(32);
    end_time: number = 0;
    highest_bid: number = 0;

    constructor(fields: {
        auction_name: string,
        seller: Buffer,
        highest_bidder: Buffer,
        end_time: number,
        highest_bid: number,
    } | undefined = undefined) {
        if (fields) {
            this.auction_name = fields.auction_name;
            this.seller = fields.seller;
            this.highest_bidder = fields.highest_bidder;
            this.end_time = fields.end_time;
            this.highest_bid = fields.highest_bid;
        }
    }

    static schema = new Map([
        [AuctionState, {
            kind: 'struct', fields: [
                ['auction_name', 'string'],
                ['seller', [32]],
                ['highest_bidder', [32]],
                ['end_time', 'u64'],
                ['highest_bid', 'u64'],
            ]
        }],
    ]);
}

let feesForSeller = 0;
let feesForBidder = 0;

const SEED_FOR_AUCTION = "auction";

async function main() {
   
    const connection = getConnection();

    const programId = await getPublicKeyFromFile(PROGRAM_KEYPAIR_PATH);
    const kpSeller = await generateKeyPair(connection, 1);
    const kpBidder1 = await generateKeyPair(connection, 1);
    const kpBidder2 = await generateKeyPair(connection, 1);

    await printParticipants(connection, programId, [
        ["seller", kpSeller.publicKey], 
        ["bidder 1", kpBidder1.publicKey],
        ["bidder 2", kpBidder2.publicKey],
    ]);

    // 1. Start auction
    console.log("\n--- Start auction. Actor: the seller ---");
    const auctionName = "auction1";
    const nSlotsToWait = 20;
    console.log('    Duration:', nSlotsToWait, 'slots');
    const endTime = await connection.getSlot() + nSlotsToWait;
    const starting_bid = 0.1 * LAMPORTS_PER_SOL;
    await start(
        connection,
        programId,
        kpSeller,
        auctionName,
        endTime,
        starting_bid);

    // 2. Bid
    console.log("\n--- Bid. Actor: the bidder 1 ---");
    const amountToDepositBidder1 = 0.1 * LAMPORTS_PER_SOL + starting_bid;
    await bid(
        connection,
        programId,
        kpBidder1,
        kpSeller.publicKey,
        auctionName,
        amountToDepositBidder1);
    const feesForBidder1 = feesForBidder;
    feesForBidder = 0;

    console.log("\n--- Bid. Actor: the bidder 2 ---");
    const amountToDepositBidder2 = amountToDepositBidder1 + 100;
    await bid(
        connection,
        programId,
        kpBidder2,
        kpSeller.publicKey,
        auctionName,
        amountToDepositBidder2);
    const feesForBidder2 = feesForBidder;
    feesForBidder = 0;

    console.log("\nWaiting", nSlotsToWait, "slots to end auction...");
    const currentSlot = await connection.getSlot();
    while (await connection.getSlot() < currentSlot + nSlotsToWait) {
        await new Promise(f => setTimeout(f, 1000));//sleep 1 second
    }
    
    // 3. End auction
    console.log("\n--- End auction. Actor: the seller ---");
    await end(
        connection,
        programId,
        kpSeller,
        auctionName);

    // Costs
    console.log("\n........");
    console.log("Fees for seller:        ", feesForSeller / LAMPORTS_PER_SOL, "SOL");
    console.log("Fees for bidder 1:      ", feesForBidder1 / LAMPORTS_PER_SOL, "SOL");
    console.log("Fees for bidder 2:      ", feesForBidder2 / LAMPORTS_PER_SOL, "SOL");
    console.log("Total fees:             ", (feesForSeller + feesForBidder1 + feesForBidder2) / LAMPORTS_PER_SOL, "SOL");

}

main().then(
    () => process.exit(),
    err => {
        console.error(err);
        process.exit(-1);
    }
);

async function start(
    connection: Connection,
    programId: PublicKey,
    kpSeller: Keypair,
    auctionName: string,
    endTime: number,
    starting_bid: number
): Promise<void> {

    console.log('    Starting amount: ', starting_bid / LAMPORTS_PER_SOL, 'SOL');

    const auctionPDA = await getAuctionPDA(programId, kpSeller.publicKey, auctionName);

    const auctionState = new AuctionState({
        auction_name: auctionName,
        seller: kpSeller.publicKey.toBuffer(),
        highest_bidder: kpSeller.publicKey.toBuffer(),
        end_time: endTime,
        highest_bid: starting_bid,
    });

    const transaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: kpSeller.publicKey, isSigner: true, isWritable: false },
                { pubkey: auctionPDA, isSigner: false, isWritable: true },
                { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
            ],
            programId,
            data: Buffer.from(new Uint8Array([Action.Start, ...borsh.serialize(AuctionState.schema, auctionState)])),
        })
    );

    await sendAndConfirmTransaction(connection, transaction, [kpSeller]);

    const tFees = await getTransactionFees(transaction, connection);
    feesForSeller += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');

}

async function bid(
    connection: Connection,
    programId: PublicKey,
    kpBidder: Keypair,
    sellerPubKey: PublicKey,
    auctionName: string,
    amountToDeposit: number
): Promise<void> {

    console.log('    Amount: ', amountToDeposit / LAMPORTS_PER_SOL, 'SOL');

    const auctionPDA = await getAuctionPDA(programId, sellerPubKey, auctionName);

    const stateAccountInfo = await connection.getAccountInfo(auctionPDA);
    if (stateAccountInfo === null) {
        throw new Error('Error: cannot find the state account');
    }
    const stateInfo = borsh.deserialize(AuctionState.schema, AuctionState, stateAccountInfo.data,);

    const currentHighestBidderPubKey = new PublicKey(stateInfo.highest_bidder);

    const transaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: kpBidder.publicKey, isSigner: true, isWritable: true },
                { pubkey: currentHighestBidderPubKey, isSigner: false, isWritable: true },
                { pubkey: auctionPDA, isSigner: false, isWritable: true },
                { pubkey: sellerPubKey, isSigner: false, isWritable: true },
                { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
            ],
            programId,
            data: buildBufferFromActionAndNumber(Action.Bid, amountToDeposit)
        })
    );

    await sendAndConfirmTransaction(connection, transaction, [kpBidder]);

    const tFees = await getTransactionFees(transaction, connection);
    feesForBidder += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

async function end(
    connection: Connection,
    programId: PublicKey,
    kpSeller: Keypair,
    auctionName: string,
): Promise<void> {
    const auctionPDA = await getAuctionPDA(programId, kpSeller.publicKey, auctionName);

    const transaction = new Transaction().add(
        new TransactionInstruction({
            keys: [
                { pubkey: kpSeller.publicKey, isSigner: true, isWritable: false },
                { pubkey: auctionPDA, isSigner: false, isWritable: true },
            ],
            programId,
            data: Buffer.from(new Uint8Array([Action.End])),
        })
    );

    await sendAndConfirmTransaction(connection, transaction, [kpSeller]);

    const tFees = await getTransactionFees(transaction, connection);
    feesForSeller += tFees;
    console.log('    Transaction fees: ', tFees / LAMPORTS_PER_SOL, 'SOL');
}

async function getAuctionPDA(programId: PublicKey, ownerPubKey: PublicKey, auctionName: string): Promise<PublicKey> {
    const [pda] = await PublicKey.findProgramAddress(
        [Buffer.from(SEED_FOR_AUCTION + auctionName), ownerPubKey.toBuffer()],
        programId
    );
    return pda;
}