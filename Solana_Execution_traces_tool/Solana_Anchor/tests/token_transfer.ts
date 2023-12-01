import * as anchor from '@coral-xyz/anchor';
import { Program, web3 } from '@coral-xyz/anchor';
import { TokenTransfer } from '../target/types/token_transfer';
import { generateKeyPair, sendAnchorInstructions, printParticipants } from './utils'
import {
  createMint,
  getMint,
  mintToChecked,
  getMinimumBalanceForRentExemptAccount,
  getOrCreateAssociatedTokenAccount,
  createInitializeAccountInstruction,
  createTransferInstruction,
  Account as AssociatedTokenAccount,
  ACCOUNT_SIZE as TOKEN_ACCOUNT_SIZE,
  TOKEN_PROGRAM_ID,
} from '@solana/spl-token'


anchor.setProvider(anchor.AnchorProvider.env());
const connection = anchor.AnchorProvider.env().connection;
const program = anchor.workspace.TokenTransfer as Program<TokenTransfer>;

describe('Token Transfer', async () => {

  let mintInitializer: web3.Keypair;
  let mintPubkey: web3.PublicKey;

  let sender: web3.Keypair;
  let recipient: web3.Keypair;

  let senderATA: AssociatedTokenAccount;
  let recipientATA: AssociatedTokenAccount;
  let tempAtaPublicKey: web3.PublicKey;

  let atasHolderPDA: web3.PublicKey;

  const decimals = 9;
  const numTokensToMint = 100;
  const nTokenToDeposit = 50;

  before(async () => {
    [sender, recipient, mintInitializer] = await Promise.all([
      generateKeyPair(connection, 1),
      generateKeyPair(connection, 1),
      generateKeyPair(connection, 1),
    ]);

    // Setup 
    mintPubkey = await createMint(
      connection, // conneciton
      mintInitializer, // fee payer
      mintInitializer.publicKey, // mint authority
      mintInitializer.publicKey, // freeze authority (you can use `null` to disable it. when you disable it, you can't turn it on again)
      decimals
    );

    // No needed here but useful to know how to obtain the address 
    [atasHolderPDA] = web3.PublicKey.findProgramAddressSync(
      [Buffer.from('atas_holder')],
      program.programId
    );

    senderATA = await getOrCreateAssociatedTokenAccount( // Create
      connection,
      sender,
      mintPubkey,
      sender.publicKey
    );

    recipientATA = await getOrCreateAssociatedTokenAccount( // Create
      connection,
      recipient,
      mintPubkey,
      recipient.publicKey
    );

    // Mint tokens to the sender
    console.log('Minting', numTokensToMint, 'tokens to the sender\'s ATA');
    await mintToChecked(
      connection,
      mintInitializer,
      mintPubkey,
      senderATA.address, // destination
      mintInitializer, // mint authority
      numTokensToMint * Math.pow(10, decimals), // amount. if your decimals is 9, you mint 10^9 for 1 token
      decimals
    );

    await printParticipants(connection, [
      ['programId', program.programId],
      ['mintInitializer', mintInitializer.publicKey],
      ['mint', mintPubkey],
      ['sender', sender.publicKey],
      ['recipient', recipient.publicKey],
      ['senderATA', senderATA.address],
      ['recipientATA', recipientATA.address],
      ['atasHolderPDA', atasHolderPDA],
    ]);
  });

  it('The sender has deposited', async () => {
    console.log('Creating the temp token account to transfer to the program')
    const tempSenderTokenAccountKeypair = web3.Keypair.generate();
    tempAtaPublicKey = tempSenderTokenAccountKeypair.publicKey;
    console.log('Temp token account:', tempSenderTokenAccountKeypair.publicKey.toBase58())
    const createTempTokenAccountInstruction = web3.SystemProgram.createAccount({
      fromPubkey: sender.publicKey, // fee payer
      newAccountPubkey: tempSenderTokenAccountKeypair.publicKey,
      space: TOKEN_ACCOUNT_SIZE,
      lamports: await getMinimumBalanceForRentExemptAccount(connection),
      programId: TOKEN_PROGRAM_ID,
    });

    // Instruction to init token account
    const initTempAccountInstruction = createInitializeAccountInstruction(
      tempSenderTokenAccountKeypair.publicKey,
      mintPubkey,
      sender.publicKey
    );

    const mint = await getMint(connection, mintPubkey);
    // Instruction to transfer tokens to the second associated token account
    const transferTokensToTempAccInstruction = createTransferInstruction(
      senderATA.address, // from
      tempSenderTokenAccountKeypair.publicKey, // to
      sender.publicKey, //owner
      nTokenToDeposit * Math.pow(10, mint.decimals) // amount. if your decimals is 9, you mint 10^9 for 1 token
    );

    console.log('The sender deposits:', nTokenToDeposit, 'tokens');
    const depositInstruction = await program.methods
      .deposit()
      .accounts({
        sender: sender.publicKey,
        recipient: recipient.publicKey,
        mint: mintPubkey,
        tempAta: tempSenderTokenAccountKeypair.publicKey,
      })
      .instruction();

    try {
      await sendAnchorInstructions(
        connection,
        [
          createTempTokenAccountInstruction,
          initTempAccountInstruction,
          transferTokensToTempAccInstruction,
          depositInstruction
        ],
        [sender, tempSenderTokenAccountKeypair]
      );
    } catch (e) {
      console.log(e)
    }
  });

  it('The recipient has done a partial withdraw', async () => {
    const amountToWithdraw = new anchor.BN(nTokenToDeposit / 2);
    console.log('Amount to withdraw: ' + amountToWithdraw.toNumber());
    const instruction = await program.methods
      .withdraw(amountToWithdraw)
      .accounts({
        recipient: recipient.publicKey,
        sender: sender.publicKey,
        mint: mintPubkey,
        recipientAta: recipientATA.address,
        tempAta: tempAtaPublicKey,
      })
      .instruction();

    await sendAnchorInstructions(connection, [instruction], [recipient]);
  });


  it('The recipient has done a partial withdraw (the last one)', async () => {
    const amountToWithdraw = new anchor.BN(nTokenToDeposit / 2);
    console.log('Amount to withdraw: ' + amountToWithdraw.toNumber());
    const instruction = await program.methods
      .withdraw(amountToWithdraw)
      .accounts({
        recipient: recipient.publicKey,
        sender: sender.publicKey,
        mint: mintPubkey,
        recipientAta: recipientATA.address,
        tempAta: tempAtaPublicKey,
      })
      .instruction();

    await sendAnchorInstructions(connection, [instruction], [recipient]);
  });

});
