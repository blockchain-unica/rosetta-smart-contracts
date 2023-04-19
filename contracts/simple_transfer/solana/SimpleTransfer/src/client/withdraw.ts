import { LAMPORTS_PER_SOL } from '@solana/web3.js';
import {
  establishConnection,
  establishPayer,
  checkProgram,
  withdraw,
} from './simpletransfer';
import { PayerType } from './utils';

async function main() {

  await establishConnection();

  await establishPayer(PayerType.Receiver);

  await checkProgram();

  let amount = 0.1 * LAMPORTS_PER_SOL;
  await withdraw(amount);

  console.log('Success');
  
}

main().then(
  () => process.exit(),
  err => {
    console.error(err);
    process.exit(-1);
  },
);
