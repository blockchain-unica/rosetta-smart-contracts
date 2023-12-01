import * as anchor from '@coral-xyz/anchor';
import { Program, web3 } from '@coral-xyz/anchor';
import { Crowdfund } from '../target/types/crowdfund';
import { generateKeyPair, sendAnchorInstructions, printParticipants } from './utils'

anchor.setProvider(anchor.AnchorProvider.env());
const connection = anchor.AnchorProvider.env().connection;
const program = anchor.workspace.Crowdfund as Program<Crowdfund>;

describe('Crowdfund', async () => {

    let campainOwner: web3.Keypair;
    let donor: web3.Keypair;

    before(async () => {
        [campainOwner, donor] = await Promise.all([
            generateKeyPair(connection, 1),
            generateKeyPair(connection, 1),
        ]);
        
        await printParticipants(connection, [
            ['programId', program.programId],
            ['campain_owner', campainOwner.publicKey],
            ['donor', donor.publicKey],
        ]);
    });


    async function createCampin(campainOwnerKeyPair: web3.Keypair, campainName: string, goalLamports: number, end_slot: number): Promise<void> {
        const instruction = await program.methods
            .initialize(
                campainName,
                new anchor.BN(end_slot),
                new anchor.BN(goalLamports),
            )
            .accounts({ campainOwner: campainOwnerKeyPair.publicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [campainOwnerKeyPair]);
    }

    async function donateToCampain(donorKeyPair: web3.Keypair, campainName: string, lamportsToDonate: number): Promise<void> {
        const [depositPda, _] = web3.PublicKey.findProgramAddressSync(
            [Buffer.from('deposit'), Buffer.from(campainName), donorKeyPair.publicKey.toBuffer()],
            program.programId
        );
        console.log('Deposit PDA:', depositPda.toBase58());

        const instruction = await program.methods
            .donate(
                campainName,
                new anchor.BN(lamportsToDonate),
            )
            .accounts({ donor: donorKeyPair.publicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [donorKeyPair]);
    }

    async function witwdrawFunds(campainOwnerKeyPair: web3.Keypair, campainName: string): Promise<void> {
        const instruction = await program.methods
            .withdraw(
                campainName,
            )
            .accounts({ campainOwner: campainOwnerKeyPair.publicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [campainOwnerKeyPair]);
    }

    async function reclaimFunds(donorKeyPair: web3.Keypair, campainName: string): Promise<void> {
        const instruction = await program.methods
            .reclaim(
                campainName,
            )
            .accounts({ donor: donorKeyPair.publicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [donorKeyPair]);
    }

    it('The first trace was completed (final action: withdraw)', async () => {
        // Initialized with random values to not fail by creating a campain with the same name (same account)
        const campainName = 'myCampain' + Math.random().toString(); // Attention: must be 30 bytes at most
        const goalLamports = 1000;
        const nSlotsToWait = 10;
        let end_slot = await connection.getSlot() + nSlotsToWait;;

        console.log('\nThe campain owner creates the campain:', campainName, "with the goal of", goalLamports / web3.LAMPORTS_PER_SOL, "SOL");
        // No needed here but useful to know how to obtain the address 
        const [campainPDA, _] = web3.PublicKey.findProgramAddressSync(
            [Buffer.from(campainName)],
            program.programId
        );
        console.log('Campain PDA:', campainPDA.toBase58());
        await createCampin(campainOwner, campainName, goalLamports, end_slot);

        const lamporstsToSend = goalLamports; // Try to decrement this value to see the error
        console.log("\nThe donor donates", lamporstsToSend / web3.LAMPORTS_PER_SOL, "SOL")
        await donateToCampain(donor, campainName, lamporstsToSend);

        console.log('\nWaiting', nSlotsToWait, 'slots for the campain to end...');
        while (await connection.getSlot() < end_slot) {
            await new Promise(f => setTimeout(f, 1000));//sleep 1 second
        }

        console.log("\nThe campain owner withdraws the funds");
        await witwdrawFunds(campainOwner, campainName);
    });


    it('The second trace was completed (final action: reclaim)', async () => {
        // Initialized with random values to not fail by creating a campain with the same name (same account)
        const campainName = 'myCampain' + Math.random().toString(); // Attention: must be 30 bytes at most
        const goalLamports = 1000;
        const nSlotsToWait = 10;
        let end_slot = await connection.getSlot() + nSlotsToWait;;

        console.log('\nThe campain owner creates the campain:', campainName, "with the goal of", goalLamports / web3.LAMPORTS_PER_SOL, "SOL");
        // No needed here but useful to know how to obtain the address 
        const [campainPDA, _] = web3.PublicKey.findProgramAddressSync(
            [Buffer.from(campainName)],
            program.programId
        );
        console.log('Campain PDA:', campainPDA.toBase58());
        await createCampin(campainOwner, campainName, goalLamports, end_slot);

        const lamporstsToSend = goalLamports - 10; // Try to set to the goal amount to see the error
        console.log("\nThe donor donates", lamporstsToSend / web3.LAMPORTS_PER_SOL, "SOL")
        await donateToCampain(donor, campainName, lamporstsToSend);

        console.log('\nWaiting', nSlotsToWait, 'slots for the campain to end...');
        while (await connection.getSlot() < end_slot) {
            await new Promise(f => setTimeout(f, 1000));//sleep 1 second
        }

        console.log("\nThe donor reclaims");
        await reclaimFunds(donor, campainName);
    });

    it('The third trace was completed (final action: reclaim)', async () => {
        // Initialized with random values to not fail by creating a campain with the same name (same account)
        const campainName = 'myCampain' + Math.random().toString(); // Attention: must be 30 bytes at most
        const goalLamports = 1000;
        const nSlotsToWait = 10;
        let end_slot = await connection.getSlot() + nSlotsToWait;;

        console.log('\nThe campain owner creates the campain:', campainName, "with the goal of", goalLamports / web3.LAMPORTS_PER_SOL, "SOL");
        // No needed here but useful to know how to obtain the address 
        const [campainPDA, _] = web3.PublicKey.findProgramAddressSync(
            [Buffer.from(campainName)],
            program.programId
        );
        console.log('Campain PDA:', campainPDA.toBase58());
        await createCampin(campainOwner, campainName, goalLamports, end_slot);

        const lamporstsToSend = goalLamports / 2 - 1 ; // Try to set to the goal amount to see the error
        console.log("\nThe donor has donates", lamporstsToSend / web3.LAMPORTS_PER_SOL, "SOL")
        await donateToCampain(donor, campainName, lamporstsToSend);
        await donateToCampain(donor, campainName, lamporstsToSend);

        console.log('\nWaiting', nSlotsToWait, 'slots for the campain to end...');
        while (await connection.getSlot() < end_slot) {
            await new Promise(f => setTimeout(f, 1000));//sleep 1 second
        }

        console.log("\nThe donor reclaims");
        await reclaimFunds(donor, campainName);
    });


});
