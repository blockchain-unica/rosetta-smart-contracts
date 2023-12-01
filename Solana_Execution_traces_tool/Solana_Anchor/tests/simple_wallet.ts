import * as anchor from '@coral-xyz/anchor';
import { Program, web3 } from '@coral-xyz/anchor';
import { SimpleWallet } from '../target/types/simple_wallet';
import { generateKeyPair, sendAnchorInstructions, printParticipants } from './utils'

anchor.setProvider(anchor.AnchorProvider.env());
const connection = anchor.AnchorProvider.env().connection;
const program = anchor.workspace.SimpleWallet as Program<SimpleWallet>;

describe('SimpleWallet', async () => {
    let owner: web3.Keypair;
    let reciever: web3.Keypair;
    let walletPdaPublicKey: web3.PublicKey;

    const transactionSeed = 'transaction1';
    const amountToDeposit = 0.2 * web3.LAMPORTS_PER_SOL;
    const amountToSendToReciever = amountToDeposit / 2;
    const amountToWithdraw = amountToDeposit - amountToSendToReciever;

    before(async () => {
        [owner, reciever] = await Promise.all([
            generateKeyPair(connection, 1),
            generateKeyPair(connection, 1),
        ]);

        [walletPdaPublicKey] = web3.PublicKey.findProgramAddressSync(
            [Buffer.from("wallet"), owner.publicKey.toBuffer()],
            program.programId
        );

        await printParticipants(connection, [
            ['programId', program.programId],
            ['owner', owner.publicKey],
            ['reciever', reciever.publicKey],
            ['walletPdaPublicKey', walletPdaPublicKey],
        ]);
    });

    it('The onwer has performed the initialization and has deposited', async () => {
        console.log('The owner initializes his wallet PDA and deposits', amountToDeposit / web3.LAMPORTS_PER_SOL, 'SOL');

        const instruction = await program.methods
            .deposit(new anchor.BN(amountToDeposit))
            .accounts({ owner: owner.publicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [owner]);
    });

    it('The onwer has created the transaction PDA', async () => {
        console.log('The creates the transaction with the following parameters:');
        console.log('\t- amount to send:', amountToSendToReciever / web3.LAMPORTS_PER_SOL, 'SOL');
        console.log('\t- reciever:', reciever.publicKey.toBase58());
        console.log('\t- transaction seed:', transactionSeed);

        const instruction = await program.methods
            .createTransaction(transactionSeed, new anchor.BN(amountToSendToReciever))
            .accounts({ owner: owner.publicKey, reciever: reciever.publicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [owner]);
    });

    it('The onwer has executed the transaction', async () => {
        console.log('The onwer executes the transaction with the seed', transactionSeed);

        const instruction = await program.methods
            .executeTransaction(transactionSeed)
            .accounts({ owner: owner.publicKey, reciever: reciever.publicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [owner]);
    });

    it('The owner has performed the withdraw', async () => {
        console.log('The owner withdraws', amountToWithdraw / web3.LAMPORTS_PER_SOL, 'SOL')

        const instruction = await program.methods
            .withdraw(new anchor.BN(amountToWithdraw))
            .accounts({ owner: owner.publicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [owner]);
    });

});
