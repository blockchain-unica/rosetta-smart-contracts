import os from 'os';
import fs from 'mz/fs';
import path from 'path';
import yaml from 'yaml';
import {
  Connection,
  Keypair,
  LAMPORTS_PER_SOL,
  PublicKey,
  Transaction,
  TransactionInstruction,
  sendAndConfirmTransaction,
} from '@solana/web3.js';

import { keccak256 } from 'js-sha3';

async function getConfig(): Promise<any> {
  const CONFIG_FILE_PATH = path.resolve(os.homedir(), '.config', 'solana', 'cli', 'config.yml');
  const configYml = await fs.readFile(CONFIG_FILE_PATH, { encoding: 'utf8' });
  return yaml.parse(configYml);
}

export async function getSystemKeyPair(): Promise<Keypair> {
  try {
    let config = await getConfig();
    if (!config.keypair_path) throw new Error('Missing keypair path');
    return await getKeyPairFromFile(config.keypair_path);
  } catch (err) {
    console.warn(
      'Failed to create keypair from config file, falling back to new random keypair',
    );
    return Keypair.generate();
  }
}

export async function getKeyPairFromFile(keyPairPath: string): Promise<Keypair> {
  const secretKeyJson = await fs.promises.readFile(keyPairPath, 'utf8');
  const secretKey = Uint8Array.from(JSON.parse(secretKeyJson));
  return Keypair.fromSecretKey(secretKey);
}

export async function generateKeyPair(connection: Connection, balanceInSOL: number): Promise<Keypair> {
  const kp = Keypair.generate();
  const accountInfo = await connection.getAccountInfo(kp.publicKey);

  if (accountInfo === null) {
    const signature = await connection.requestAirdrop(
      kp.publicKey,
      LAMPORTS_PER_SOL * balanceInSOL
    );
    await connection.confirmTransaction(signature);
  }

  return kp;
}

export async function getPublicKeyFromFile(keyPairPath: string): Promise<PublicKey> {
  return (await getKeyPairFromFile(keyPairPath)).publicKey;
}

export async function printParticipants(connection: Connection, participants: [string, PublicKey][]) {
  const data = [];
  for (const [name, publicKey] of participants) {
    const balance = await connection.getBalance(publicKey);
    data.push({ name: name, publicKey: publicKey.toBase58(), SOL: balance / LAMPORTS_PER_SOL });
  }
  console.table(data, ['name', 'publicKey', 'SOL']);
}

export async function keccak256FromString(secret: string): Promise<number[]> {
  const hash = keccak256.create();
  hash.update(secret);
  return hash.digest();
}

export async function getTransactionFees(transaction: Transaction, connection: Connection): Promise<number> {
  const fees: number | null = await transaction.getEstimatedFee(connection);
  if (fees) {
    return fees;
  } else {
    throw new Error('Error during estimation of fees');
  }
}
export async function sendAnchorInstructions(connection: Connection, instructions: TransactionInstruction[], signers: Keypair[]): Promise<void> {
  const transaction = new Transaction().add(...instructions);

  const transactionHash = await sendAndConfirmTransaction(
    connection,
    transaction,
    signers,
  );

  console.log('Transaction hash:', transactionHash);
  const tFees = await getTransactionFees(transaction, connection);
  console.log('Transaction fees:', tFees / LAMPORTS_PER_SOL, 'SOL');
}