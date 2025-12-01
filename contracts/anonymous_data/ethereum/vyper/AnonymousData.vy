# pragma version ^0.4.0

MAX_DATASIZE: constant(uint256) = 100
usersData: HashMap[bytes32, Bytes[MAX_DATASIZE]]

@deploy
def __init__():
    pass


@view
@internal
def calculateID(_addr: address, _nonce: uint256) -> bytes32:
    return keccak256(
        concat(
            convert(_addr, bytes20),
            convert(_nonce, bytes32)
        )
    )

@view 
@external
def getID(_nonce: uint256) -> bytes32:
    return self.calculateID(msg.sender, _nonce)


@external
def storeData(_userID: bytes32, _data: Bytes[MAX_DATASIZE]):
    assert len(_data) != 0, "0 bytes of data sent"
    assert self.usersData[_userID] == empty(Bytes[MAX_DATASIZE]), "Contract already stores data for this ID"

    self.usersData[_userID] = _data


@view 
@external
def getMyData(_nonce: uint256) -> Bytes[MAX_DATASIZE]:
    id: bytes32 = self.calculateID(msg.sender, _nonce)
    return self.usersData[id]
