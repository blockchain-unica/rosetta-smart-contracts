struct ByteData {
    data: [u8; 512],
    length: u32,
}

program storage_contract.aleo {

    storage byte_sequence: ByteData;
    storage text_string: ByteData;

    @noupgrade
    constructor() {}

    fn store_bytes(data_: [u8; 512], length_: u32) -> Final {
        return final {
            assert(length_ <= 512u32);
            byte_sequence = ByteData { data: data_, length: length_ };
        };
    }

    fn store_string(data_: [u8; 512], length_: u32) -> Final {
        return final {
            assert(length_ <= 512u32);
            text_string = ByteData { data: data_, length: length_ };
        };
    }
}