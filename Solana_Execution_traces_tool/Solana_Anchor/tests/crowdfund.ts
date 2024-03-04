import * as anchor from '@coral-xyz/anchor';
import { Program, web3 } from '@coral-xyz/anchor';
import { Crowdfund } from '../target/types/crowdfund';
import { generateKeyPair, sendAnchorInstructions, printParticipants } from './utils'

anchor.setProvider(anchor.AnchorProvider.env());
const connection = anchor.AnchorProvider.env().connection;
const program = anchor.workspace.Crowdfund as Program<Crowdfund>;

describe('Crowdfund', async () => {

    let campaignOwner: web3.Keypair;
    let donor: web3.Keypair;

    before(async () => {
        [campaignOwner, donor] = await Promise.all([
            generateKeyPair(connection, 1),
            generateKeyPair(connection, 1),
        ]);
        
        await printParticipants(connection, [
            ['programId', program.programId],
            ['campaign_owner', campaignOwner.publicKey],
            ['donor', donor.publicKey],
        ]);
    });


    async function createCampaign(campaignOwnerKeyPair: web3.Keypair, campaignName: string, goalLamports: number, end_slot: number): Promise<void> {
        const instruction = await program.methods
            .initialize(
                campaignName,
                new anchor.BN(end_slot),
                new anchor.BN(goalLamports),
            )
            .accounts({ campaignOwner: campaignOwnerKeyPair.publicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [campaignOwnerKeyPair]);
    }

    async function donateToCampaign(donorKeyPair: web3.Keypair, campaignName: string, lamportsToDonate: number): Promise<void> {
        const [depositPda, _] = web3.PublicKey.findProgramAddressSync(
            [Buffer.from('deposit'), Buffer.from(campaignName), donorKeyPair.publicKey.toBuffer()],
            program.programId
        );
        console.log('Deposit PDA:', depositPda.toBase58());

        const instruction = await program.methods
            .donate(
                campaignName,
                new anchor.BN(lamportsToDonate),
            )
            .accounts({ donor: donorKeyPair.publicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [donorKeyPair]);
    }

    async function withdrawFunds(campaignOwnerKeyPair: web3.Keypair, campaignName: string): Promise<void> {
        const instruction = await program.methods
            .withdraw(
                campaignName,
            )
            .accounts({ campaignOwner: campaignOwnerKeyPair.publicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [campaignOwnerKeyPair]);
    }

    async function reclaimFunds(donorKeyPair: web3.Keypair, campaignName: string): Promise<void> {
        const instruction = await program.methods
            .reclaim(
                campaignName,
            )
            .accounts({ donor: donorKeyPair.publicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [donorKeyPair]);
    }

    it('The first trace was completed (final action: withdraw)', async () => {
        // Initialized with random values to not fail by creating a campaign with the same name (same account)
        const campaignName = 'myCampaign' + Math.random().toString(); // Attention: must be 30 bytes at most
        const goalLamports = 1000;
        const nSlotsToWait = 10;
        let end_slot = await connection.getSlot() + nSlotsToWait;;

        console.log('\nThe campaign owner creates the campaign:', campaignName, "with the goal of", goalLamports / web3.LAMPORTS_PER_SOL, "SOL");
        // No needed here but useful to know how to obtain the address 
        const [campaignPDA, _] = web3.PublicKey.findProgramAddressSync(
            [Buffer.from(campaignName)],
            program.programId
        );
        console.log('Campaign PDA:', campaignPDA.toBase58());
        await createCampaign(campaignOwner, campaignName, goalLamports, end_slot);

        const lamportsToSend = goalLamports; // Try to decrement this value to see the error
        console.log("\nThe donor donates", lamportsToSend / web3.LAMPORTS_PER_SOL, "SOL")
        await donateToCampaign(donor, campaignName, lamportsToSend);

        console.log('\nWaiting', nSlotsToWait, 'slots for the campaign to end...');
        while (await connection.getSlot() < end_slot) {
            await new Promise(f => setTimeout(f, 1000));//sleep 1 second
        }

        console.log("\nThe campaign owner withdraws the funds");
        await withdrawFunds(campaignOwner, campaignName);
    });


    it('The second trace was completed (final action: reclaim)', async () => {
        // Initialized with random values to not fail by creating a campaign with the same name (same account)
        const campaignName = 'myCampaign' + Math.random().toString(); // Attention: must be 30 bytes at most
        const goalLamports = 1000;
        const nSlotsToWait = 10;
        let end_slot = await connection.getSlot() + nSlotsToWait;;

        console.log('\nThe campaign owner creates the campaign:', campaignName, "with the goal of", goalLamports / web3.LAMPORTS_PER_SOL, "SOL");
        // No needed here but useful to know how to obtain the address 
        const [campaignPDA, _] = web3.PublicKey.findProgramAddressSync(
            [Buffer.from(campaignName)],
            program.programId
        );
        console.log('Campaign PDA:', campaignPDA.toBase58());
        await createCampaign(campaignOwner, campaignName, goalLamports, end_slot);

        const lamportsToSend = goalLamports - 10;
        console.log("\nThe donor donates", lamportsToSend / web3.LAMPORTS_PER_SOL, "SOL")
        await donateToCampaign(donor, campaignName, lamportsToSend);

        console.log('\nWaiting', nSlotsToWait, 'slots for the campaign to end...');
        while (await connection.getSlot() < end_slot) {
            await new Promise(f => setTimeout(f, 1000));//sleep 1 second
        }

        console.log("\nThe donor reclaims");
        await reclaimFunds(donor, campaignName);
    });

});
