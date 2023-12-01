import * as anchor from '@coral-xyz/anchor';
import { Program, web3 } from '@coral-xyz/anchor';
import { Auction } from '../target/types/auction';
import { generateKeyPair, sendAnchorInstructions, printParticipants } from './utils'

anchor.setProvider(anchor.AnchorProvider.env());
const connection = anchor.AnchorProvider.env().connection;
const program = anchor.workspace.Auction as Program<Auction>;

describe('Auction', async () => {
    let seller: web3.Keypair;
    let bidder1: web3.Keypair;
    let bidder2: web3.Keypair;
    let auctionPDA: web3.PublicKey;

    // Auction data
    const auctionName = "test" + Math.random();
    const durationSlots = 20;
    const startingBid = 0.1 * web3.LAMPORTS_PER_SOL; // 0.1 SOL

    before(async () => {
        [seller, bidder1, bidder2] = await Promise.all([
            generateKeyPair(connection, 1),
            generateKeyPair(connection, 1),
            generateKeyPair(connection, 1),
        ]);

        [auctionPDA] = web3.PublicKey.findProgramAddressSync(
            [Buffer.from(auctionName)],
            program.programId,
        );

        await printParticipants(connection, [
            ['programId', program.programId],
            ['seller', seller.publicKey],
            ['bidder 1', bidder1.publicKey],
            ['bidder 2', bidder2.publicKey],
            ['auctionPDA', auctionPDA]
        ]);
    });

    it('Start', async () => {
        console.log('The seller starts the auction with durationSlots: ', durationSlots, ' and starting_bid: ', startingBid / web3.LAMPORTS_PER_SOL, 'SOL');
        const instruction = await program.methods
            .start(
                auctionName,
                new anchor.BN(durationSlots),
                new anchor.BN(startingBid),
            )
            .accounts({ seller: seller.publicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [seller]);
    });

    it('Bid (bidder 1)', async () => {
        const bidAmount = 0.1 * web3.LAMPORTS_PER_SOL + startingBid;
        console.log('The bidder 1 bids with amount: ', bidAmount / web3.LAMPORTS_PER_SOL, 'SOL');

        const auctionAccount = await program.account.auctionInfo.fetch(auctionPDA);
        const highestBidder: web3.PublicKey = auctionAccount.highestBidder;

        const instruction = await program.methods
            .bid(auctionName, new anchor.BN(bidAmount))
            .accounts({ bidder: bidder1.publicKey, currentHighestBidder: highestBidder })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [bidder1]);
    });

    it('Bid (bidder 2)', async () => {
        const bidAmount = 100 + (0.1 * web3.LAMPORTS_PER_SOL + startingBid);
        console.log('The bidder 2 bids with amount: ', bidAmount / web3.LAMPORTS_PER_SOL, 'SOL');

        const auctionAccount = await program.account.auctionInfo.fetch(auctionPDA);
        const highestBidder: web3.PublicKey = auctionAccount.highestBidder;

        const instruction = await program.methods
            .bid(auctionName, new anchor.BN(bidAmount))
            .accounts({ bidder: bidder2.publicKey, currentHighestBidder: highestBidder })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [bidder2]);
    });


    it('End', async () => {
        const endSlot = await connection.getSlot() + durationSlots;
        console.log("\nWaiting the auction to end...");
        while (await connection.getSlot() < endSlot) {
            await new Promise(f => setTimeout(f, 1000));//sleep 1 second
        }

        console.log('\nThe seller ends the auction.');
        const instruction = await program.methods
            .end(auctionName)
            .accounts({ seller: seller.publicKey, })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [seller]);
    });

});
