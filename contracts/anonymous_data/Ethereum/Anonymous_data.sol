// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract AnonymousData{

    mapping (bytes32 => bytes) StoredData;
    bytes32[] IDs;
    address owner;

    constructor(){
        owner = msg.sender;
    }


    function storeData(bytes memory data, bytes32 user_ID ) public {

        if(StoredData[user_ID].length==0){
            IDs.push(user_ID);
        }
        StoredData[user_ID]=data;
    }

    function getID(uint nonce) public view returns(bytes32 ID) {
        return keccak256(abi.encode(msg.sender,nonce));
    }

    function getAllData() public view returns (bytes[] memory){
        require(msg.sender == owner, "only the owner can read");
        bytes[] memory allData = new bytes[](IDs.length);

        for(uint i=0; i<IDs.length; i++){
             allData[i]=StoredData[IDs[i]];
         }
        return allData;
    }

    function getMyData(uint nonce) public view returns(bytes memory) {
        bytes32 ID = keccak256(abi.encode(msg.sender,nonce));
        return StoredData[ID];
    }
}