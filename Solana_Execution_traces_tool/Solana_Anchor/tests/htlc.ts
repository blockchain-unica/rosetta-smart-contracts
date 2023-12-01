import * as anchor from '@coral-xyz/anchor';
import { Program, web3 } from '@coral-xyz/anchor';
import { Htlc } from '../target/types/htlc';
import { generateKeyPair, sendAnchorInstructions, printParticipants, keccak256FromString } from './utils'

anchor.setProvider(anchor.AnchorProvider.env());
const connection = anchor.AnchorProvider.env().connection;
const program = anchor.workspace.Htlc as Program<Htlc>;

describe('HTLC', async () => {
  
  let owner: web3.Keypair;
  let verifier: web3.Keypair;
  const secret = 'password123';
  const hashedSecret = await keccak256FromString(secret);
  const delaySlots = 100;
  const amountLamports = 100000;

  before(async () => {
    [owner, verifier] = await Promise.all([
      generateKeyPair(connection, 1),
      generateKeyPair(connection, 1),
    ]);

    // No needed here but useful to know how to obtain the address
    const [htlcInfoPDA, _] = web3.PublicKey.findProgramAddressSync(
      [owner.publicKey.toBuffer(), verifier.publicKey.toBuffer()],
      program.programId
    );

    await printParticipants(connection, [
      ['programId', program.programId],
      ['owner', owner.publicKey],
      ['verifier', verifier.publicKey],
      ['htlcInfoPDA', htlcInfoPDA],
    ]);
  });

  it('The first trace was completed', async () => {
    console.log('The owner submits the secret, setting a deadline of', delaySlots, 'rounds');
    const initInstruction = await program.methods
      .initialize(
        hashedSecret,
        new anchor.BN(delaySlots),
        new anchor.BN(amountLamports),
      )
      .accounts({ owner: owner.publicKey, verifier: verifier.publicKey })
      .instruction();

    await sendAnchorInstructions(connection, [initInstruction], [owner]);

    let nSlotsToWait = 50;
    console.log('\nAfter 50 rounds, the owner performs the reveal action. Waiting', nSlotsToWait, 'slots...');
    let currentSlot = await connection.getSlot();
    while (await connection.getSlot() < currentSlot + nSlotsToWait) {
      await new Promise(f => setTimeout(f, 1000)); //sleep 1 second
    }

    const revealInstruction = await program.methods
      .reveal(secret) // Try with a wrong secret to see the error
      .accounts({ owner: owner.publicKey, verifier: verifier.publicKey })
      .instruction();

    await sendAnchorInstructions(connection, [revealInstruction], [owner]);
  });

  it('The second trace was completed', async () => {
    console.log('The owner submits the secret, setting a deadline of', delaySlots, 'rounds');
    const initInstruction = await program.methods
      .initialize(
        hashedSecret,
        new anchor.BN(delaySlots),
        new anchor.BN(amountLamports),
      )
      .accounts({ owner: owner.publicKey, verifier: verifier.publicKey })
      .instruction();

    await sendAnchorInstructions(connection, [initInstruction], [owner]);

    let nSlotsToWait = delaySlots + 10;
    console.log('\nAfter 100 rounds, the receiver performs the timeout action. Waiting', nSlotsToWait, 'slots...');
    let currentSlot = await connection.getSlot();
    while (await connection.getSlot() < currentSlot + nSlotsToWait) {
      await new Promise(f => setTimeout(f, 1000)); //sleep 1 second
    }

    const revealInstruction = await program.methods
      .timeout()
      .accounts({ owner: owner.publicKey, verifier: verifier.publicKey })
      .instruction();

    await sendAnchorInstructions(connection, [revealInstruction], [verifier]);
  });

});
