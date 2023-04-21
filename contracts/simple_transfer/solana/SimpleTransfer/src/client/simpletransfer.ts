import {
  Connection,
  Keypair,
  LAMPORTS_PER_SOL,
  PublicKey,
  SystemProgram,
  Transaction,
  TransactionInstruction,
  sendAndConfirmTransaction,
} from '@solana/web3.js';
import * as borsh from 'borsh';
import fs from 'mz/fs';
import path from 'path';

import { Buffer } from 'buffer';
import { createKeypairFromFile, getPayer, getRpcUrl, PayerType } from './utils';

let connection: Connection;
let payer: Keypair;
let programId: PublicKey;
let writingAccountPublicKey: PublicKey;

const PROGRAM_PATH = path.resolve(__dirname, '../../dist/program');
const PROGRAM_SO_PATH = path.join(PROGRAM_PATH, 'simpletransfer.so');
const PROGRAM_KEYPAIR_PATH = path.join(PROGRAM_PATH, 'simpletransfer-keypair.json');
const LAMPORTS_ACCOUNT_PATH = 'lamports-account.txt';

class DonationDetails {
  sender: Buffer = Buffer.alloc(32);
  receiver: Buffer = Buffer.alloc(32);
  amount: number = 0;

  constructor(fields: {
    sender: Buffer,
    receiver: Buffer,
    amount: number,
  } | undefined = undefined) {
    if (fields) {
      this.sender = fields.sender;
      this.receiver = fields.receiver;
      this.amount = fields.amount;
    }
  }

  static schema = new Map([
    [DonationDetails, {
      kind: 'struct', fields: [
        ['sender', [32]],
        ['receiver', [32]],
        ['amount', 'u64'],
      ]
    }],
  ]);

}

class WithdrawRequest {
  amount: number = 0;

  constructor(fields: {
    amount: number,
  } | undefined = undefined) {
    if (fields) {
      this.amount = fields.amount;
    }
  }

  static schema = new Map([
    [WithdrawRequest, {
      kind: 'struct', fields: [
        ['amount', 'u64'],
      ]
    }],
  ]);

}

const DONATION_SIZE = borsh.serialize(
  DonationDetails.schema,
  new DonationDetails(),
).length;

const WITHDRAW_REQUEST_SIZE = borsh.serialize(
  WithdrawRequest.schema,
  new WithdrawRequest(),
).length;

export async function establishConnection(): Promise<void> {
  const rpcUrl = await getRpcUrl();
  connection = new Connection(rpcUrl, 'confirmed');
  const version = await connection.getVersion();
  console.log('Connection to cluster established:', rpcUrl, version);
}

export async function establishPayer(payerType: PayerType): Promise<void> {
  let fees = 0;
  if (!payer) {
    const { feeCalculator } = await connection.getRecentBlockhash();
    fees += await connection.getMinimumBalanceForRentExemption(DONATION_SIZE);
    fees += await connection.getMinimumBalanceForRentExemption(WITHDRAW_REQUEST_SIZE);
    fees += feeCalculator.lamportsPerSignature * 100; // wag
    payer = await getPayer(payerType);
  }

  let lamports = await connection.getBalance(payer.publicKey);
  if (lamports < fees) {
    // If current balance is not enough to pay for fees, request an airdrop
    const sig = await connection.requestAirdrop(
      payer.publicKey,
      fees - lamports,
    );
    await connection.confirmTransaction(sig);
    lamports = await connection.getBalance(payer.publicKey);
  }

  console.log('Using account', payer.publicKey.toBase58(), 'containing', lamports / LAMPORTS_PER_SOL, 'SOL',);
}

export async function checkProgram(): Promise<void> {
  try {
    const programKeypair = await createKeypairFromFile(PROGRAM_KEYPAIR_PATH);
    programId = programKeypair.publicKey;
  } catch (err) {
    const errMsg = (err as Error).message;
    throw new Error(
      `Failed to read program keypair at '${PROGRAM_KEYPAIR_PATH}' due to error: ${errMsg}. Program may need to be deployed`,
    );
  }

  // Check if the program has been deployed
  const programInfo = await connection.getAccountInfo(programId);
  if (programInfo === null) {
    if (fs.existsSync(PROGRAM_SO_PATH)) {
      throw new Error(
        'Program needs to be deployed with `solana program deploy dist/program/helloworld.so`',
      );
    } else {
      throw new Error('Program needs to be built and deployed');
    }
  } else if (!programInfo.executable) {
    throw new Error(`Program is not executable`);
  }
  console.log(`On chain program address: ${programId.toBase58()}`);
}

export async function donate(amount: number, receiver: PublicKey): Promise<void> {

  let donation = new DonationDetails(
    {
      sender: payer.publicKey.toBuffer(),
      receiver: receiver.toBuffer(),
      amount: amount
    }
  );

  let data = borsh.serialize(DonationDetails.schema, donation);
  let data_to_send = Buffer.from(new Uint8Array([0, ...data]));

  const SEED = "abcdef" + Math.random().toString();
  writingAccountPublicKey = await PublicKey.createWithSeed(
    payer.publicKey,
    SEED,
    programId,
  );

  const lamports =
    (await connection.getMinimumBalanceForRentExemption(data.length));

  const transaction = new Transaction().add(
    SystemProgram.createAccountWithSeed({
      fromPubkey: payer.publicKey,
      basePubkey: payer.publicKey,
      seed: SEED,
      newAccountPubkey: writingAccountPublicKey,
      lamports: lamports,
      space: data.length,
      programId: programId,
    }));
  await sendAndConfirmTransaction(connection, transaction, [payer]);

  const SEED2 = "abcdef" + Math.random().toString();
  let lamportsHolderAccountPublicKey = await PublicKey.createWithSeed(
    payer.publicKey,
    SEED2,
    programId
  );

  await fs.promises.writeFile(LAMPORTS_ACCOUNT_PATH, writingAccountPublicKey.toBase58());

  const transactionLamportsAccount = new Transaction().add(
    SystemProgram.createAccountWithSeed({
      fromPubkey: payer.publicKey,
      basePubkey: payer.publicKey,
      seed: SEED2,
      newAccountPubkey: lamportsHolderAccountPublicKey,
      lamports: amount,
      space: 1,
      programId: programId,
    }));
  await sendAndConfirmTransaction(connection, transactionLamportsAccount, [payer]);

  const instruction = new TransactionInstruction({
    keys: [
      { pubkey: writingAccountPublicKey, isSigner: false, isWritable: true },
      { pubkey: lamportsHolderAccountPublicKey, isSigner: false, isWritable: true },
      { pubkey: payer.publicKey, isSigner: true, isWritable: false },
    ],
    programId,
    data: data_to_send,
  });
  await sendAndConfirmTransaction(
    connection,
    new Transaction().add(instruction),
    [payer],
  );
}

export async function withdraw(amount: number): Promise<void> {

  const lamportsAddress = await fs.promises.readFile(LAMPORTS_ACCOUNT_PATH, 'utf8');

  let withdraw_request = new WithdrawRequest({ amount: amount });
  let data = borsh.serialize(WithdrawRequest.schema, withdraw_request);
  let data_to_send = Buffer.from(new Uint8Array([1, ...data]));

  const instruction = new TransactionInstruction({
    keys: [
      { pubkey: new PublicKey(lamportsAddress), isSigner: false, isWritable: true },
      { pubkey: payer.publicKey, isSigner: true, isWritable: false },
    ],
    programId,
    data: data_to_send,
  });

  const transactionSignature = await sendAndConfirmTransaction(
    connection,
    new Transaction().add(instruction),
    [payer],
  );

  console.log('Now the receiver account',  'has', (await connection.getBalance(payer.publicKey)) / LAMPORTS_PER_SOL, 'SOL');

}