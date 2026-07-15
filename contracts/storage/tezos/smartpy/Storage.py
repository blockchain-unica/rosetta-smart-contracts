import smartpy as sp

@sp.module
def main():
    class StorageRosetta(sp.Contract):
        def __init__(self):
            self.data.byte_sequence = sp.cast(None, sp.option[sp.bytes])
            self.data.text_string = sp.cast(None, sp.option[sp.string])

        @sp.entrypoint
        def storeBytes(self, byte_sequence: sp.bytes):
            self.data.byte_sequence = sp.Some(byte_sequence)
            sp.emit(sp.record(sender=sp.sender), tag="BytesStored")

        @sp.entrypoint
        def storeString(self, text_string: sp.string):
            self.data.text_string = sp.Some(text_string)
            sp.emit(sp.record(sender=sp.sender), tag="StringStored")

def _compile_targets():
    """Entry point for in-process compilation by the toolchain."""
    return [
        (main.StorageRosetta, ()),
    ]

