import * as anchor from '@coral-xyz/anchor';
import { Program, web3 } from '@coral-xyz/anchor';
import { Storage } from '../target/types/storage';
import { generateKeyPair, sendAnchorInstructions, printParticipants } from './utils'
import { assert } from 'chai';

anchor.setProvider(anchor.AnchorProvider.env());
const connection = anchor.AnchorProvider.env().connection;
const program = anchor.workspace.Storage as Program<Storage>;

describe('Storage', async () => {

    let user: web3.Keypair;
    let memoryStringPdaPublicKey: web3.PublicKey;
    let memoryBytesPDAPublicKey: web3.PublicKey;

    const INITIAL_PDA_SIZE = 12;

    before(async () => {
        user = await generateKeyPair(connection, 1);

        [memoryStringPdaPublicKey] = web3.PublicKey.findProgramAddressSync(
            [Buffer.from('storage_string'), user.publicKey.toBuffer()],
            program.programId,
        );

        [memoryBytesPDAPublicKey] = web3.PublicKey.findProgramAddressSync(
            [Buffer.from('storage_bytes'), user.publicKey.toBuffer()],
            program.programId,
        );

        await printParticipants(connection, [
            ['programId', program.programId],
            ['user', user.publicKey],
            ['storageStringPDA', memoryStringPdaPublicKey],
            ['memoryBytesPDA', memoryBytesPDAPublicKey]
        ]);
    });

    function generateSequences(type) {
        const sequences = [];

        for (let i = 1; i <= 5; i++) {
            if (type === 'byte') {
                sequences.push(Buffer.from(Array.from({ length: i }, (_, index) => index + 1)));
            } else if (type === 'string') {
                sequences.push(Array.from({ length: i }, (_, index) => String.fromCharCode(97 + index)).join(''));
            }
        }

        return sequences;
    }

    it('Initialize', async () => {
        console.log('The user initializes the storage pdas');
        const instruction = await program.methods
            .initialize()
            .accounts({ user: user.publicKey })
            .instruction();

        await sendAnchorInstructions(connection, [instruction], [user]);

        // Check if the accounts data length is INITIAL_PDA_SIZE
        const stringAccount = await connection.getAccountInfo(memoryStringPdaPublicKey);
        assert.equal(stringAccount.data.length, INITIAL_PDA_SIZE);

        const bytesAccount = await connection.getAccountInfo(memoryBytesPDAPublicKey);
        assert.equal(bytesAccount.data.length, INITIAL_PDA_SIZE);

    });

    it('Store String', async () => {
        console.log('Storing some strings');

        const stringSequences = generateSequences('string');
        for (const stringToStore of stringSequences) {
            console.log("    Storing string:   ", stringToStore);

            const instruction = await program.methods
                .storeString(stringToStore)
                .accounts({ user: user.publicKey })
                .instruction();
            await sendAnchorInstructions(connection, [instruction], [user]);

            // Check if the data was stored correctly
            const anchorMemoryStringPdaAccount = await program.account.memoryStringPda.fetch(memoryStringPdaPublicKey);
            assert.equal(anchorMemoryStringPdaAccount.myString, stringToStore);

            // Check if the accounts data length is INITIAL_PDA_SIZE + string length
            const stringAccount = await connection.getAccountInfo(memoryStringPdaPublicKey);
            assert.equal(stringAccount.data.length, INITIAL_PDA_SIZE + stringToStore.length);
        }
    });

    it('Store Bytes', async () => {
        console.log('Storing some strings');

        const stringSequences = generateSequences('byte');
        for (const bytesToStore of stringSequences) {
            console.log("    Storing bytes:   ", bytesToStore);

            const instruction = await program.methods
                .storeBytes(bytesToStore)
                .accounts({ user: user.publicKey })
                .instruction();

            await sendAnchorInstructions(connection, [instruction], [user]);

            // Check if the data was stored correctly
            const anchorMemoryBytesPdaAccount = await program.account.memoryBytesPda.fetch(memoryBytesPDAPublicKey);
            assert.equal(anchorMemoryBytesPdaAccount.myBytes.toString(), bytesToStore.toString());

            // Check if the accounts data length is INITIAL_PDA_SIZE + string length
            const bytesAccount = await connection.getAccountInfo(memoryBytesPDAPublicKey);
            assert.equal(bytesAccount.data.length, INITIAL_PDA_SIZE + bytesToStore.length);
        }
    });
});
