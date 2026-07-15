import credits.aleo;

struct PendingTx {
    to: address,
    amount: u64,
    data: [u8; 256],
    data_length: u32,
    executed: bool,
}

program simple_wallet.aleo {

    storage owner: address;
    storage tx_counter: u32;
    mapping transactions: u32 => PendingTx;

    @noupgrade
    constructor() {}

    fn initialize(owner_: address) -> Final {
        return final {
            assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(owner_ != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            owner = owner_;
            tx_counter = 0u32;
        };
    }

    fn deposit(amount_: u64) -> Final {
        let caller_: address = self.signer;
        let f: Final = credits.aleo::transfer_public_as_signer(self.address, amount_);

        return final {
            assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(caller_ == owner.unwrap());
            assert(amount_ > 0u64);
            f.run();
        };
    }

    fn create_transaction(to_: address, amount_: u64, data_: [u8; 256], data_length_: u32) -> Final {
        let caller_: address = self.signer;

        return final {
            assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(caller_ == owner.unwrap());
            assert(to_ != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(amount_ > 0u64);
            assert(data_length_ <= 256u32);

            let new_id: u32 = tx_counter.unwrap_or(0u32);
            let new_tx: PendingTx = PendingTx {
                to: to_,
                amount: amount_,
                data: data_,
                data_length: data_length_,
                executed: false,
            };
            transactions.set(new_id, new_tx);
            tx_counter = new_id + 1u32;
        };
    }

    fn execute_transaction(tx_id_: u32, to_: address, amount_: u64) -> Final {
        let caller_: address = self.signer;
        let f: Final = credits.aleo::transfer_public(to_, amount_);

        return final {
            assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(caller_ == owner.unwrap());
            assert(tx_id_ < tx_counter.unwrap_or(0u32));

            let tx: PendingTx = transactions.get(tx_id_);
            assert(!tx.executed);
            assert(tx.to == to_);
            assert(tx.amount == amount_);

            let bal: u64 = credits.aleo::account.get_or_use(self.address, 0u64);
            assert(bal >= amount_);

            let updated_tx: PendingTx = PendingTx {
                to: tx.to,
                amount: tx.amount,
                data: tx.data,
                data_length: tx.data_length,
                executed: true,
            };
            transactions.set(tx_id_, updated_tx);

            f.run();
        };
    }

    fn withdraw(amount_: u64) -> Final {
        let caller_: address = self.signer;
        let f: Final = credits.aleo::transfer_public(caller_, amount_);

        return final {
            assert(owner.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) != aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
            assert(caller_ == owner.unwrap());
            let bal: u64 = credits.aleo::account.get_or_use(self.address, 0u64);
            assert(amount_ == bal);
            f.run();
        };
    }
}