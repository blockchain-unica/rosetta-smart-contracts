import smartpy as sp
from templates import fa2_lib as fa2

@sp.module
def main():
    class Token(FA2.Fa2Nft):
        @sp.entry_point
        def mint(self, owner, token_info):
            #get token_id
            token_id = self.data.last_token_id
            #mint new NFT
            self.data.ledger[token_id] = owner
            self.data.token_metadata[token_id] = sp.record(token_id = token_id, token_info = token_info)
            self.data.last_token_id += 1

   

@sp.add_test(name = "Token Transfer")
def testToken():
    #set scenario
    sc = sp.test_scenario(main)
    #create object Token
    owner = sp.test_account("Pippo") #set owner
    tt = main.Token(metadata = sp.utils.metadata_of_url("ipfs://QmRbxcd2yfNVdgHL7oYWS2yd3tztr2NZiqP2LFuw3voPW"))
    #start scenario
    sc += tt

    sc.h2("Mint")
    #set users
    buyer = sp.test_account("Sofia")
    #mint new NFT
    tt.mint(owner = owner.address, token_info = sp.map({"": sp.utils.bytes_of_string("ipfs://QmRbxcd2yfNVdgHL7oYWS2yd3tztr2NZiqP2LFuw3voPW")}))
    sc.h2("Transfer")
    tt.transfer([sp.record(from_=owner.address, txs=[sp.record(token_id=0, amount=1, to_=buyer.address)])]).run(sender = owner )

