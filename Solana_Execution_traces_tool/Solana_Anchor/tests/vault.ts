import * as anchor from '@coral-xyz/anchor';
import { Program, web3 } from '@coral-xyz/anchor';
import { Vault } from '../target/types/vault';
import { generateKeyPair, sendAnchorInstructions, printParticipants } from './utils'

anchor.setProvider(anchor.AnchorProvider.env());
const connection = anchor.AnchorProvider.env().connection;
const program = anchor.workspace.Vault as Program<Vault>;

describe('Vault', async () => {
    let owner: web3.Keypair;
    let recovery: web3.Keypair;
    let receiver: web3.Keypair;
    const waitTime = 10;
    const amountInLamports = 1000;
    const initialAmount = 1000000;

    beforeEach(async () => {
        [owner, recovery, receiver] = await Promise.all([
            generateKeyPair(connection, 1),
            generateKeyPair(connection, 1),
            generateKeyPair(connection, 1),
        ]);

        await printParticipants(connection, [
            ['programId', program.programId],
            ['owner', owner.publicKey],
            ['recovery', recovery.publicKey],
            ['receiver', receiver.publicKey],
        ]);
    });

    async function initializeVault(actor: web3.Keypair, recoveryPublicKey: web3.PublicKey, waitTime: number, initialAmount: number): Promise<void> {
        console.log('The owner initializes the vault account');
        const instruction = await program.methods
            .initialize(
                new anchor.BN(waitTime),
                new anchor.BN(initialAmount),
            )
            .accounts({
                owner: owner.publicKey,
                recovery: recoveryPublicKey
            })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [actor]);
    }

    async function withdraw(actor: web3.Keypair, receiverPublicKey: web3.PublicKey, amount: number): Promise<void> {
        console.log('The owner initializes the withdraw request for', amount, 'lamports');
        const instruction = await program.methods
            .withdraw(new anchor.BN(amount))
            .accounts({ owner: actor.publicKey, receiver: receiverPublicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [actor]);
    }

    async function finalize(actor: web3.Keypair, receiverPublicKey: web3.PublicKey): Promise<void> {
        console.log('The owner finalizes the withdraw request');
        const instruction = await program.methods
            .finalize()
            .accounts({ owner: actor.publicKey, receiver: receiverPublicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [actor]);
    }

    async function cancel(actor: web3.Keypair, ownerPublicKey: web3.PublicKey): Promise<void> {
        console.log('The recovery cancels the withdraw request');
        const instruction = await program.methods
            .cancel()
            .accounts({ recovery: actor.publicKey, owner: ownerPublicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [actor]);
    }


    it('The first trace was completed (final action: finalize)', async () => {
        await initializeVault(owner, recovery.publicKey, waitTime, initialAmount);
        console.log('');

        await withdraw(owner, receiver.publicKey, amountInLamports);
        console.log('');

        console.log('Waiting for', waitTime, 'slots');
        let endSlot = await connection.getSlot() + waitTime + 5;
        while (await connection.getSlot() < endSlot) {
            await new Promise(f => setTimeout(f, 1000)); //sleep 1 second
        }

        await finalize(owner, receiver.publicKey);
        console.log('');
    });

    it('The second trace was completed (final action: cancel)', async () => {
        await initializeVault(owner, recovery.publicKey, waitTime, initialAmount);
        console.log('');

        await withdraw(owner, receiver.publicKey, amountInLamports);
        console.log('')

        await cancel(recovery, owner.publicKey);
        console.log('');
    });

});
