import { Keypair, LAMPORTS_PER_SOL } from '@solana/web3.js';
import {
  establishConnection,
  establishPayer,
  checkProgram,
  donate,
} from './simpletransfer';
import { PayerType } from './utils';
import { fs } from 'mz';

async function main() {

  await establishConnection();

  await establishPayer(PayerType.Donator);

  await checkProgram();

  console.log('\n---------------------');

  let amount = 0.5 * LAMPORTS_PER_SOL;
  console.log('Ammount in lamports: ', amount);

  const secretKeyJson = await fs.promises.readFile('keypair-receiver.json', 'utf8');
  const secretKey = Uint8Array.from(JSON.parse(secretKeyJson));
  const receiver = Keypair.fromSecretKey(secretKey).publicKey;

  console.log('Receiver address:    ', receiver.toBase58());
  console.log('---------------------');

  await donate(amount, receiver);

  console.log('\nSuccess\n');

}

main().then(
  () => process.exit(),
  err => {
    console.error(err);
    process.exit(-1);
  },
);
