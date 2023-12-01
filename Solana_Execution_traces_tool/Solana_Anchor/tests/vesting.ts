import * as anchor from '@coral-xyz/anchor';
import { Program, web3 } from '@coral-xyz/anchor';
import { Vesting } from '../target/types/vesting';
import { generateKeyPair, sendAnchorInstructions, printParticipants } from './utils'

anchor.setProvider(anchor.AnchorProvider.env());
const connection = anchor.AnchorProvider.env().connection;
const program = anchor.workspace.Vesting as Program<Vesting>;

describe('Vesting', async () => {
    let funder: web3.Keypair;
    let beneficiary: web3.Keypair;
    const initialAmountInLamports = 0.2 * web3.LAMPORTS_PER_SOL; // 0.2 SOL

    beforeEach(async () => {
        [funder, beneficiary] = await Promise.all([
            generateKeyPair(connection, 1),
            generateKeyPair(connection, 1),
        ]);

        await printParticipants(connection, [
            ['programId', program.programId],
            ['funder', funder.publicKey],
            ['beneficiary', beneficiary.publicKey],
        ]);
    });

    async function initializeVesting(actor: web3.Keypair, beneficiaryPublicKey: web3.PublicKey, startSlot: number, duration: number, amountInLamports: number): Promise<void> {
        console.log('The funder initializes the vesting with the following parameters: ');
        console.log(`- startSlot: ${startSlot}`);
        console.log(`- duration: ${duration}`);
        console.log(`- amountInLamports: ${amountInLamports}\n`);

        const instruction = await program.methods
            .initialize(
                new anchor.BN(startSlot),
                new anchor.BN(duration),
                new anchor.BN(amountInLamports),
            )
            .accounts({
                funder: actor.publicKey,
                beneficiary: beneficiaryPublicKey
            })
            .instruction();

        try {
            await sendAnchorInstructions(connection, [instruction], [actor]);
        } catch (e) {
            console.log(e);
        }
    }

    async function release(actor: web3.Keypair, funderPublicKey: web3.PublicKey): Promise<void> {
        console.log('The beneficiary releases');
        const instruction = await program.methods
            .release()
            .accounts({
                beneficiary: actor.publicKey,
                funder: funderPublicKey
            })
            .instruction();

        try {
            await sendAnchorInstructions(connection, [instruction], [actor]);
        } catch (e) {
            console.log(e);
        }
    }

    it('Scenario 1 completed', async () => {
        console.log('\nScenario 1: current slot < start\n');
        console.log('The beneficiary will obtain 0 SOL\n');

        const startSlot = await connection.getSlot() + 9999999; // a big number
        const duration = 9999999;

        await initializeVesting(funder, beneficiary.publicKey, startSlot, duration, initialAmountInLamports);
        console.log('');

        await release(beneficiary, funder.publicKey);
        console.log('')

    });

    it('Scenario 2 completed', async () => {
        console.log('\nScenario 2: current slot > start + duration\n');
        console.log('The beneficiary will obtain all the funds\n');

        const startSlot = await connection.getSlot() + 10; // a small number
        const duration = 1; // a small number
        const targetSlotToWait = startSlot + duration;

        await initializeVesting(funder, beneficiary.publicKey, startSlot, duration, initialAmountInLamports);
        console.log('');

        console.log('\nWaiting to reach the targhet slot');
        while (await connection.getSlot() < targetSlotToWait) {
            await new Promise(f => setTimeout(f, 1000)); //sleep 1 second
        }
        console.log('');

        await release(beneficiary, funder.publicKey);
        console.log('')

    });

    it('Scenario 3 completed', async () => {
        console.log('\nScenario 3: The beneficiary obtains a fraction of the funds\n');

        const startSlot = await connection.getSlot() + 10;
        const duration = 200;
        const targetSlotToWait = startSlot + (duration / 2);

        await initializeVesting(funder, beneficiary.publicKey, startSlot, duration, initialAmountInLamports);
        console.log('');

        console.log('\nWaiting to reach the targhet slot');
        while (await connection.getSlot() < targetSlotToWait) {
            await new Promise(f => setTimeout(f, 1000)); //sleep 1 second
        }
        console.log('');

        await release(beneficiary, funder.publicKey);
        console.log('')
    });

});
