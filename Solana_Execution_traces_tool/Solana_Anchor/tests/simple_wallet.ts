import * as anchor from '@coral-xyz/anchor';
import { Program, web3 } from '@coral-xyz/anchor';
import { SimpleWallet } from '../target/types/simple_wallet';
import { generateKeyPair, sendAnchorInstructions, printParticipants } from './utils'

anchor.setProvider(anchor.AnchorProvider.env());
const connection = anchor.AnchorProvider.env().connection;
const program = anchor.workspace.SimpleWallet as Program<SimpleWallet>;

describe('SimpleWallet', async () => {
    let owner: web3.Keypair;
    let receiver: web3.Keypair;
    let walletPdaPublicKey: web3.PublicKey;

    const transactionSeed = 'transaction1';
    const amountToDeposit = 0.2 * web3.LAMPORTS_PER_SOL;
    const amountToSendToReceiver = amountToDeposit / 2;
    const amountToWithdraw = amountToDeposit - amountToSendToReceiver;

    before(async () => {
        [owner, receiver] = await Promise.all([
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
            ['receiver', receiver.publicKey],
            ['walletPdaPublicKey', walletPdaPublicKey],
        ]);
    });

    it('The owner has performed the initialization and has deposited', async () => {
        console.log('The owner initializes his wallet PDA and deposits', amountToDeposit / web3.LAMPORTS_PER_SOL, 'SOL');

        const instruction = await program.methods
            .deposit(new anchor.BN(amountToDeposit))
            .accounts({ owner: owner.publicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [owner]);
    });

    it('The owner has created the transaction PDA', async () => {
        console.log('The creates the transaction with the following parameters:');
        console.log('\t- amount to send:', amountToSendToReceiver / web3.LAMPORTS_PER_SOL, 'SOL');
        console.log('\t- receiver:', receiver.publicKey.toBase58());
        console.log('\t- transaction seed:', transactionSeed);

        const instruction = await program.methods
            .createTransaction(transactionSeed, new anchor.BN(amountToSendToReceiver))
            .accounts({ owner: owner.publicKey, receiver: receiver.publicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [owner]);
    });

    it('The owner has executed the transaction', async () => {
        console.log('The owner executes the transaction with the seed', transactionSeed);

        const instruction = await program.methods
            .executeTransaction(transactionSeed)
            .accounts({ owner: owner.publicKey, receiver: receiver.publicKey })
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
