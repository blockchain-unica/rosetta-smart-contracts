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
} from '@solana/web3.js';

import * as crypto from 'crypto';
import * as BufferLayout from '@solana/buffer-layout';

async function getConfig(): Promise<any> {
  const CONFIG_FILE_PATH = path.resolve(
    os.homedir(),
    '.config',
    'solana',
    'cli',
    'config.yml',
  );
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

export async function getTransactionFees(transaction: Transaction, connection: Connection): Promise<number> {
  const fees: number | null = await transaction.getEstimatedFee(connection);
  if (fees) {
    return fees;
  } else {
    throw new Error('Error durig estimation of fees');
  }
}

export function buildBufferFromActionAndNumber(action: any, passedNumber: number): Buffer {
  interface Settings { action: number, amount: number }
  const layout = BufferLayout.struct<Settings>([BufferLayout.u8("action"), BufferLayout.nu64("amount")]);
  const dataToSend = Buffer.alloc(layout.span);
  layout.encode({ action, amount: passedNumber }, dataToSend);
  return dataToSend;
}

export async function hashSHA256(secret: string) {
  const hash = crypto.createHash('sha256');
  hash.update(secret);
  return hash.digest();
}