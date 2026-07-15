program editable_nft.aleo {
    
    struct nft_data {
        content: [field; 4],
    }

    record NFT {
        owner: address,
        id: u64,
        data: nft_data,
        sealed: bool,
    }

    storage next_id: u64;

    @noupgrade
    constructor() {}

    fn buy(id_proposed: u64) -> (NFT, Final) {

        let empty_data: nft_data = nft_data {
            content: [0field, 0field, 0field, 0field],
        };

        let newNFT: NFT = NFT {
            owner: self.signer,
            id: id_proposed,
            data: empty_data,
            sealed: false,
        };

        return (newNFT, final {
            assert(id_proposed == (next_id.unwrap_or(0u64) + 1u64));
            next_id = id_proposed;
        });
    }

    fn edit(nftRecord: NFT, new_data: nft_data) -> NFT {

        assert(nftRecord.sealed == false);

        return NFT {
            owner: nftRecord.owner,
            id: nftRecord.id,
            data: new_data,
            sealed: false,
        };
    }

    fn transferTo(nftRecord: NFT, new_owner: address) -> NFT {

        return NFT {
            owner: new_owner,
            id: nftRecord.id,
            data: nftRecord.data,
            sealed: nftRecord.sealed,
        };
    }

    fn seal(nftRecord: NFT) -> NFT {
        assert(nftRecord.sealed == false);

        return NFT {
            owner: nftRecord.owner,
            id: nftRecord.id,
            data: nftRecord.data,
            sealed: true,
        };
    }
}