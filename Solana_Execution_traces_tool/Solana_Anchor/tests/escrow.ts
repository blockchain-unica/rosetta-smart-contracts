import * as anchor from '@coral-xyz/anchor';
import { Program, web3 } from '@coral-xyz/anchor';
import { Escrow } from '../target/types/escrow';
import { generateKeyPair, sendAnchorInstructions, printParticipants } from './utils'

anchor.setProvider(anchor.AnchorProvider.env());
const connection = anchor.AnchorProvider.env().connection;
const program = anchor.workspace.Escrow as Program<Escrow>;

describe('Escrow', async () => {
  let seller: web3.Keypair;
  let buyer: web3.Keypair;

  before(async () => {
    [seller, buyer] = await Promise.all([
      generateKeyPair(connection, 1),
      generateKeyPair(connection, 1),
    ]);

    await printParticipants(connection, [
      ['programId', program.programId],
      ['seller', seller.publicKey],
      ['buyer', buyer.publicKey],
    ]);
  });

  async function initializeEscrow(actor: web3.Keypair, escrowName: string, requiredAmountInLamports: number): Promise<void> {
    console.log('The seller initializes the escrow account');
    const instruction = await program.methods
      .initialize(
        new anchor.BN(requiredAmountInLamports),
        escrowName
      )
      .accounts({ seller: seller.publicKey, buyer: buyer.publicKey })
      .instruction();

    await sendAnchorInstructions(connection, [instruction], [actor]);
  }

  async function deposit(actor: web3.Keypair, escrowName: string): Promise<void> {
    console.log('The buyer deposits');
    const instruction = await program.methods
      .deposit(escrowName)
      .accounts({ seller: seller.publicKey, buyer: buyer.publicKey })
      .instruction();

    await sendAnchorInstructions(connection, [instruction], [actor]);
  }

  async function pay(actor: web3.Keypair, escrowName: string): Promise<void> {
    console.log('The buyer pays');
    const instruction = await program.methods
      .pay(escrowName)
      .accounts({ seller: seller.publicKey, buyer: buyer.publicKey })
      .instruction();

    await sendAnchorInstructions(connection, [instruction], [actor]);
  }

  async function refund(actor: web3.Keypair, escrowName: string): Promise<void> {
    console.log('The seller refunds');
    const instruction = await program.methods
      .refund(escrowName)
      .accounts({ seller: seller.publicKey, buyer: buyer.publicKey })
      .instruction();

    await sendAnchorInstructions(connection, [instruction], [actor]);
  }

  it('The first trace was completed (last action: pay)', async () => {
    const escrowName = 'test-escrow' + Math.random();
    const requiredAmountInLamports = 1000000;
    await initializeEscrow(seller, escrowName, requiredAmountInLamports);
    console.log('');
    await deposit(buyer, escrowName);
    console.log('');
    await pay(buyer, escrowName);
  });

  it('The first trace was completed (last action: refund)', async () => {
    const escrowName = 'test-escrow' + Math.random();
    const requiredAmountInLamports = 1000000;
    await initializeEscrow(seller, escrowName, requiredAmountInLamports);
    console.log('');
    await deposit(buyer, escrowName);
    console.log('');
    await refund(seller, escrowName);
  });
});
