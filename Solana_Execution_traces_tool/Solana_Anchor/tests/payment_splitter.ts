import * as anchor from '@coral-xyz/anchor';
import { Program, web3 } from '@coral-xyz/anchor';
import { PaymentSplitter } from '../target/types/payment_splitter';
import { generateKeyPair, sendAnchorInstructions, printParticipants } from './utils'
import { assert } from 'chai';

anchor.setProvider(anchor.AnchorProvider.env());
const connection = anchor.AnchorProvider.env().connection;
const program = anchor.workspace.PaymentSplitter as Program<PaymentSplitter>;

describe('PaymentSplitter', async () => {

    let initializer: web3.Keypair;
    let payees: web3.Keypair[] = [];
    let paymentSplitterInfoPDA: web3.PublicKey;

    before(async () => {
        initializer = await generateKeyPair(connection, 1);

        payees = await Promise.all([
            generateKeyPair(connection, 1),
            generateKeyPair(connection, 1),
        ]);

        // No needed here but useful to know how to obtain the address
        [paymentSplitterInfoPDA] = web3.PublicKey.findProgramAddressSync(
            [Buffer.from("payment_splitter"), initializer.publicKey.toBuffer()],
            program.programId
        );

        const mapPayeesNamesPublicKeys = []
        for (let i = 0; i < payees.length; i++) {
            mapPayeesNamesPublicKeys.push([`payee${i}`, payees[i].publicKey]);
        }

        await printParticipants(connection, [
            ['programId', program.programId],
            ['initializer', initializer.publicKey],
            ...mapPayeesNamesPublicKeys,
            ['paymentSplitterInfoPDA', paymentSplitterInfoPDA],
        ]);
    });

    it('The initializer has initialized the payment splitter', async () => {
        const lamportsToTransfer = 1000000; // 0.25 * LAMPORTS_PER_SOL;
        const sharesAmounts: anchor.BN[] = [];
        console.log('The initializer initializes the payment splitter with ', lamportsToTransfer / web3.LAMPORTS_PER_SOL, ' SOL');
        console.log('The shares map is:');
        for (const payee of payees) {
            const share = new anchor.BN(1);
            sharesAmounts.push(share);
            console.log(`\t${payee.publicKey.toBase58()}: ${share}`);
        }

        // We need to calculate the size of the account to be created and pass it to the instruction
        // because anchor expects the account to be created before the instruction is executed
        // See the off chain code to check the structure of the account
        // and also https://book.anchor-lang.com/anchor_references/space.html

        const totalSpace =
            8 + // anchor discriminator
            8 + // initial amount
            4 + (32 * payees.length) + // shares vector (4 is for the Vec<> type, 32 is for each public key)
            4 + (8 * payees.length) + // shares vector (4 is for the Vec<> type, 8 is for each u64)
            4 + (8 * payees.length); // shares vector (4 is for the Vec<> type, 8 is for each u64)

        const instruction = await program.methods
            .initialize(
                new anchor.BN(lamportsToTransfer),
                new anchor.BN(totalSpace),
                sharesAmounts
            )
            .accounts({ initializer: initializer.publicKey })
            .remainingAccounts(payees.map(payee => {
                return { pubkey: payee.publicKey, isWritable: false, isSigner: false };
            }))
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [initializer]);

        // Fetch the account to check the data
        const psAccountData = await program.account.paymentSplitterInfo.fetch(paymentSplitterInfoPDA);

        psAccountData.payees.forEach((payee, index) => {
            assert.equal(payee.toBase58(), payees[index].publicKey.toBase58());
        });

        psAccountData.sharesAmounts.forEach((share, index) => {
            assert.equal(share.toString(), sharesAmounts[index].toString());
        });

        psAccountData.releasedAmounts.forEach((releasedAmount, index) => {
            assert.equal(releasedAmount.toString(), '0');
        });

        console.log('');
    });

    it('The release instruction was called by all payees', async () => {
        for (const payee of payees) {
            console.log('The payee', payee.publicKey.toBase58(), 'releases the payment');

            const instruction = await program.methods
                .release()
                .accounts({ payee: payee.publicKey, initializer: initializer.publicKey })
                .instruction();

            await sendAnchorInstructions(connection, [instruction], [payee]);

            console.log('');
        }
    });

});
