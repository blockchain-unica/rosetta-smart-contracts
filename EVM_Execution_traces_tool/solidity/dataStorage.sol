// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

contract DataStorage {

    bytes public byteSequence;
    string public textString;

    function storeBytes(bytes memory _byteSequence) public {
        byteSequence =  _byteSequence;
    }

    function storeString(string memory  _textString) public {
        textString = _textString;
    }

}