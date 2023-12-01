import * as anchor from '@coral-xyz/anchor';
import { Program, web3 } from '@coral-xyz/anchor';
import { SimpleTransfer } from '../target/types/simple_transfer';
import { generateKeyPair, sendAnchorInstructions, printParticipants } from './utils'

anchor.setProvider(anchor.AnchorProvider.env());
const connection = anchor.AnchorProvider.env().connection;
const program = anchor.workspace.SimpleTransfer as Program<SimpleTransfer>;

describe('Simple Transfer', async () => {

  let sender: web3.Keypair;
  let recipient: web3.Keypair;

  const lamportsToDeposit = 100;

  before(async () => {
    [sender, recipient] = await Promise.all([
      generateKeyPair(connection, 1),
      generateKeyPair(connection, 1),
    ]);

    // No needed here but useful to know how to obtain the address 
    const [balanceHolderPDA, _] = web3.PublicKey.findProgramAddressSync(
      [recipient.publicKey.toBuffer()],
      program.programId
    );

    await printParticipants(connection, [
      ['programId', program.programId],
      ['sender', sender.publicKey],
      ['recipient', recipient.publicKey],
      ['balanceHolderPDA', balanceHolderPDA],
    ]);
  });

  it('The sender has deposited', async () => {
    console.log('Amount to deposit: ' + lamportsToDeposit);
    const instruction = await program.methods
      .deposit(new anchor.BN(lamportsToDeposit))
      .accounts({ sender: sender.publicKey, recipient: recipient.publicKey })
      .instruction();

    await sendAnchorInstructions(connection, [instruction], [sender]);
  });

  it('The recipient has done a partial withdraw', async () => {
    const amountToWithdraw = new anchor.BN(lamportsToDeposit / 2);
    console.log('Amount to withdraw: ' + amountToWithdraw.toNumber());
    const instruction = await program.methods
      .withdraw(amountToWithdraw)
      .accounts({ recipient: recipient.publicKey, sender: sender.publicKey })
      .instruction();

    await sendAnchorInstructions(connection, [instruction], [recipient]);
  });

  it('The recipient has done a partial withdraw (the last one)', async () => {
    const amountToWithdraw = new anchor.BN(lamportsToDeposit / 2);
    console.log('Amount to withdraw: ' + amountToWithdraw.toNumber());
    const instruction = await program.methods
      .withdraw(amountToWithdraw)
      .accounts({ recipient: recipient.publicKey, sender: sender.publicKey })
      .instruction();

    await sendAnchorInstructions(connection, [instruction], [recipient]);
  });
});
