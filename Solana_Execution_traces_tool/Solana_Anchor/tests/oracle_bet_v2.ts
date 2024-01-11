import * as anchor from '@coral-xyz/anchor';
import { Program, web3 } from '@coral-xyz/anchor';
import { OracleBetV2 } from '../target/types/oracle_bet_v2';
import { generateKeyPair, sendAnchorInstructions, printParticipants } from './utils'

anchor.setProvider(anchor.AnchorProvider.env());
const connection = anchor.AnchorProvider.env().connection;
const program = anchor.workspace.OracleBetV2 as Program<OracleBetV2>;

describe('Oracle Bet V2', async () => {

  let oracle: web3.Keypair;
  let participant1: web3.Keypair;
  let participant2: web3.Keypair;
  const delaySlots = 10;
  const wagerInLamports = 100;
  const gameInstanceName = 'OracleBet' + Date.now().toString(); // random name

  beforeEach(async () => {
    [oracle, participant1, participant2] = await Promise.all([
      generateKeyPair(connection, 1),
      generateKeyPair(connection, 1),
      generateKeyPair(connection, 1),
    ]);

    // No needed here but useful to know how to obtain the address
    const [oracleBetInfoPDA, _] = web3.PublicKey.findProgramAddressSync(
      [Buffer.from(gameInstanceName)],
      program.programId
    );

    await printParticipants(connection, [
      ['programId', program.programId],
      ['oracle', oracle.publicKey],
      ['participant1', participant1.publicKey],
      ['participant2', participant2.publicKey],
      ['oracleBetInfoPDA', oracleBetInfoPDA],
    ]);
  });

  async function initializeGame(): Promise<void> {
    console.log('The oracle starts the game ', gameInstanceName, ', setting a deadline of', delaySlots, 'slots', ' and a wager of', wagerInLamports, 'lamports');
    const initInstruction = await program.methods
      .initialize(
        gameInstanceName,
        new anchor.BN(delaySlots),
        new anchor.BN(wagerInLamports),
      )
      .accounts({
        oracle: oracle.publicKey,
        participant1: participant1.publicKey,
        participant2: participant2.publicKey,
      })
      .instruction();

    await sendAnchorInstructions(connection, [initInstruction], [oracle]);
  }

  async function join(participant1: web3.Keypair, participant2: web3.Keypair): Promise<void> {
    console.log('\nThe participant 1', participant1.publicKey.toBase58(), ' joins the game ', gameInstanceName);
    console.log('The participant 2', participant2.publicKey.toBase58(), ' joins the game ', gameInstanceName);
    const betInstruction = await program.methods
      .bet(gameInstanceName)
      .accounts({ 
        participant1: participant1.publicKey,
        participant2: participant2.publicKey,
       })
      .instruction();

    await sendAnchorInstructions(connection, [betInstruction], [participant1, participant2]);
  }

  async function oracleSetResult(winner: web3.PublicKey): Promise<void> {
    console.log('\n Waiting', delaySlots, 'slots...');
    let currentSlot = await connection.getSlot();
    while (await connection.getSlot() < currentSlot + delaySlots + 5) {
      await new Promise(f => setTimeout(f, 1000)); //sleep 1 second
    }

    console.log('The oracle reveals the winner: ', winner.toBase58());
    const oracleSetResultInstruction = await program.methods
      .oracleSetResult(gameInstanceName)
      .accounts({
        oracle: oracle.publicKey,
        winner: winner,
      })
      .instruction();

    await sendAnchorInstructions(connection, [oracleSetResultInstruction], [oracle]);
  }

  async function timeout(): Promise<void> {

    console.log('\n Waiting', delaySlots, 'slots...');
    let currentSlot = await connection.getSlot();
    while (await connection.getSlot() < currentSlot + delaySlots + 5) {
      await new Promise(f => setTimeout(f, 1000)); //sleep 1 second
    }

    console.log('\n Timeout');
    const oracleSetResultInstruction = await program.methods
      .timeout(gameInstanceName)
      .accounts({
        oracle: oracle.publicKey,
        participant1: participant1.publicKey,
        participant2: participant2.publicKey,
      })
      .instruction();

    try {
      await sendAnchorInstructions(connection, [oracleSetResultInstruction], [participant1]);
    } catch (e) {
      console.log(e);
    }
  }

  it('The first trace was completed', async () => {
    await initializeGame();
    await join(participant1, participant2);
    await oracleSetResult(participant1.publicKey);
  });

  it('The first trace was completed', async () => {
    await initializeGame();
    await join(participant1, participant2);
    await timeout();
  });
});
