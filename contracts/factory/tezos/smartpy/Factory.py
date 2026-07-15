import smartpy as sp

@sp.module
def main():
    class ProductRosetta(sp.Contract):
        def __init__(self, owner: sp.address, factory: sp.address, tag: sp.string):
            self.data.tag = tag
            self.data.owner = owner
            self.data.factory = factory
            
        @sp.offchain_view()
        def getTag(self):
            assert sp.sender == self.data.owner, "only the owner"
            return self.data.tag

        @sp.offchain_view()
        def getFactory(self):
            return self.data.factory

    class FactoryRosetta(sp.Contract):
        def __init__(self):
            self.data.product_list = sp.cast(sp.big_map(), sp.big_map[sp.address, sp.list[sp.address]])

        @sp.entrypoint
        def createProduct(self, tag: sp.string):
            address = sp.create_contract(
                ProductRosetta, None, sp.tez(0), sp.record(factory=sp.self_address, owner=sp.sender, tag=tag))
            if self.data.product_list.contains(sp.sender):
                self.data.product_list[sp.sender] = sp.cons(address, self.data.product_list[sp.sender])
            else:
                self.data.product_list[sp.sender] = [address]
            
            sp.emit(address)

        @sp.offchain_view()
        def getProducts(self, owner: sp.address) -> sp.list[sp.address]:
            assert self.data.product_list.contains(owner), "Address not avaiable"

            return self.data.product_list[owner]

def _compile_targets():
    """Entry point for in-process compilation by the toolchain."""
    return [
        (main.FactoryRosetta, ()),
    ]

