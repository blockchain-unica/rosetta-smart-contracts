import * as anchor from '@coral-xyz/anchor';
import { Program, web3 } from '@coral-xyz/anchor';
import { TinyAmm } from '../target/types/tiny_amm';
import { generateKeyPair, sendAnchorInstructions, printParticipants } from './utils'
import {
    createMint,
    mintToChecked,
    getMinimumBalanceForRentExemptAccount,
    getOrCreateAssociatedTokenAccount,
    createInitializeAccountInstruction,
    Account as AssociatedTokenAccount,
    ACCOUNT_SIZE as TOKEN_ACCOUNT_SIZE,
    TOKEN_PROGRAM_ID,
} from '@solana/spl-token'

anchor.setProvider(anchor.AnchorProvider.env());
const connection = anchor.AnchorProvider.env().connection;
const program = anchor.workspace.TinyAmm as Program<TinyAmm>;

describe('TinyAmm', async () => {

    const MINT_DECIMALS = 9;
    let setup_fee_payer: web3.Keypair;
    let initializer: web3.Keypair;
    let sender: web3.Keypair;
    let mint0Pubkey: web3.PublicKey;
    let mint1Pubkey: web3.PublicKey;
    let ammInfoPDA: web3.PublicKey;
    let mintedPDA: web3.PublicKey;
    const programTokenAccount0KeyPair = web3.Keypair.generate();
    const programTokenAccount1KeyPair = web3.Keypair.generate();
    let sendersTokenAccountForMint0: AssociatedTokenAccount;
    let sendersTokenAccountForMint1: AssociatedTokenAccount;


    before(async () => {
        [setup_fee_payer, initializer, sender] = await Promise.all([
            generateKeyPair(connection, 1),
            generateKeyPair(connection, 1),
            generateKeyPair(connection, 1),
        ]);

        await setup(connection, sender.publicKey);

        ammInfoPDA = await getAmmPDA(program.programId, mint0Pubkey, mint1Pubkey);
        mintedPDA = await getMintedPDA(program.programId, sender.publicKey);

        await printParticipants(connection, [
            ['programId', program.programId],
            ['initializer', initializer.publicKey],
            ['sender', sender.publicKey],
            ['mint0', mint0Pubkey],
            ['mint1', mint1Pubkey],
            ['ammInfoPDA', ammInfoPDA],
            ['mintedPDA', mintedPDA],
            ['programTokenAccount0', programTokenAccount0KeyPair.publicKey],
            ['programTokenAccount1', programTokenAccount1KeyPair.publicKey],
            ['sendersTokenAccount0', sendersTokenAccountForMint0.address],
            ['sendersTokenAccount1', sendersTokenAccountForMint1.address],
        ]);
    });

    async function setup(
        connection: web3.Connection,
        userKeypair: web3.PublicKey,
    ): Promise<void> {
        console.log('Setup:');
        mint0Pubkey = await createMint(
            connection,
            setup_fee_payer,
            setup_fee_payer.publicKey,
            setup_fee_payer.publicKey,
            MINT_DECIMALS
        );

        mint1Pubkey = await createMint(
            connection,
            setup_fee_payer,
            setup_fee_payer.publicKey,
            setup_fee_payer.publicKey,
            MINT_DECIMALS
        );

        // Create the token associated account for the user (Mint 0)
        sendersTokenAccountForMint0 = await getOrCreateAssociatedTokenAccount(
            connection,
            setup_fee_payer,
            mint0Pubkey,
            userKeypair
        );

        // Create the token associated account for the user (Mint 1)
        sendersTokenAccountForMint1 = await getOrCreateAssociatedTokenAccount(
            connection,
            setup_fee_payer,
            mint1Pubkey,
            userKeypair
        );

        // Mint tokens to the associated token accounts
        await mintToChecked(
            connection,
            setup_fee_payer,
            mint0Pubkey,
            sendersTokenAccountForMint0.address,
            setup_fee_payer,
            100 * Math.pow(10, MINT_DECIMALS),
            MINT_DECIMALS
        );
        let t0Balance = Number((await connection.getTokenAccountBalance(sendersTokenAccountForMint0.address)).value.amount);

        await mintToChecked(
            connection,
            setup_fee_payer,
            mint1Pubkey,
            sendersTokenAccountForMint1.address,
            setup_fee_payer,
            100 * Math.pow(10, MINT_DECIMALS),
            MINT_DECIMALS
        );
    }

    it('Initialize', async () => {
        console.log('Initialization of the Tiny Amm by the actor: ', initializer.publicKey.toBase58());

        const createTokenAccount0Instruction = web3.SystemProgram.createAccount({
            fromPubkey: initializer.publicKey,
            newAccountPubkey: programTokenAccount0KeyPair.publicKey,
            space: TOKEN_ACCOUNT_SIZE,
            lamports: await getMinimumBalanceForRentExemptAccount(connection),
            programId: TOKEN_PROGRAM_ID,
        });

        const initTokenAccount0Instruction = createInitializeAccountInstruction(
            programTokenAccount0KeyPair.publicKey,
            mint0Pubkey,
            initializer.publicKey
        );

        const createTokenAccount1Instruction = web3.SystemProgram.createAccount({
            fromPubkey: initializer.publicKey,
            newAccountPubkey: programTokenAccount1KeyPair.publicKey,
            space: TOKEN_ACCOUNT_SIZE,
            lamports: await getMinimumBalanceForRentExemptAccount(connection),
            programId: TOKEN_PROGRAM_ID,
        });

        const initTokenAccount1Instruction = createInitializeAccountInstruction(
            programTokenAccount1KeyPair.publicKey,
            mint1Pubkey,
            initializer.publicKey
        );

        const initializeInstruction = await program.methods
            .initialize()
            .accounts({
                initializer: initializer.publicKey,
                mint0: mint0Pubkey,
                mint1: mint1Pubkey,
                tokenAccount0: programTokenAccount0KeyPair.publicKey,
                tokenAccount1: programTokenAccount1KeyPair.publicKey,
            })
            .instruction();

        await sendAnchorInstructions(
            connection, [
            createTokenAccount0Instruction,
            initTokenAccount0Instruction,
            createTokenAccount1Instruction,
            initTokenAccount1Instruction,
            initializeInstruction
        ], [
            initializer,
            programTokenAccount0KeyPair,
            programTokenAccount1KeyPair
        ]);
    });

    it('Deposit', async () => {
        const amount0 = 6;
        const amount1 = 6;

        console.log('The acotor: deposits ', amount0, ' of mint 0 and ', amount1, ' of mint 1');

        const instruction = await program.methods
            .deposit(
                new anchor.BN(amount0),
                new anchor.BN(amount1),
            )
            .accounts({
                sender: sender.publicKey,
                mint0: mint0Pubkey,
                mint1: mint1Pubkey,
                pdasTokenAccount0: programTokenAccount0KeyPair.publicKey,
                pdasTokenAccount1: programTokenAccount1KeyPair.publicKey,
                sendersTokenAccount0: sendersTokenAccountForMint0.address,
                sendersTokenAccount1: sendersTokenAccountForMint1.address,
            })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [sender]);

    });

    /*     it('Redeem', async () => {
            const amountToRedeem = 6;
            console.log('The sender: redeems ', amountToRedeem, 'tokens');
            const instruction = await program.methods
                .redeem(new anchor.BN(amountToRedeem))
                .accounts({
                    sender: sender.publicKey,
                    mint0: mint0Pubkey,
                    mint1: mint1Pubkey,
                    pdasTokenAccount0: programTokenAccount0KeyPair.publicKey,
                    pdasTokenAccount1: programTokenAccount1KeyPair.publicKey,
                    sendersTokenAccount0: sendersTokenAccountForMint0.address,
                    sendersTokenAccount1: sendersTokenAccountForMint1.address,
                })
                .instruction();
    
            await sendAnchorInstructions(connection, [instruction], [sender]);
        }); */

    it('Swap', async () => {
        const for_mint_0 = true; // true for mint0 to mint1, false for mint1 to mint0
        const amountIn = 3;
        const minAmountOut = 2;
        console.log('The sender: swaps ', amountIn, ' of mint ', for_mint_0 ? 0 : 1, ' for mint ', for_mint_0 ? 1 : 0, ' with minimum amount out of ', minAmountOut);
        const instruction = await program.methods
            .swap(
                for_mint_0, // true for mint0 to mint1, false for mint1 to mint0
                new anchor.BN(amountIn),
                new anchor.BN(minAmountOut),
            )
            .accounts({
                sender: sender.publicKey,
                mint0: mint0Pubkey,
                mint1: mint1Pubkey,
                pdasTokenAccount0: programTokenAccount0KeyPair.publicKey,
                pdasTokenAccount1: programTokenAccount1KeyPair.publicKey,
                sendersTokenAccount0: sendersTokenAccountForMint0.address,
                sendersTokenAccount1: sendersTokenAccountForMint1.address,
            })
            .instruction();

        try {
            await sendAnchorInstructions(connection, [instruction], [sender]);
        } catch (e) {
            console.log(e)
        }
    });

    async function getAmmPDA(programId: web3.PublicKey, mint0Pubkey: web3.PublicKey, mint1Pubkey: web3.PublicKey): Promise<web3.PublicKey> {
        const SEED_FOR_AMM = 'amm';
        const [ammPDA] = web3.PublicKey.findProgramAddressSync(
            [Buffer.from(SEED_FOR_AMM), mint0Pubkey.toBuffer(), mint1Pubkey.toBuffer()],
            programId
        );
        return ammPDA;
    }

    async function getMintedPDA(programId: web3.PublicKey, depositor: web3.PublicKey): Promise<web3.PublicKey> {
        const SEED_FOR_MINTED = 'minted';
        const [ammPDA] = web3.PublicKey.findProgramAddressSync(
            [Buffer.from(SEED_FOR_MINTED), depositor.toBuffer()],
            programId
        );
        return ammPDA;
    }

});
