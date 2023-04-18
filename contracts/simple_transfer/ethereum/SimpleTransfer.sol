// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.1;

contract SimpleTransfer{

    address payable recipient;
    address owner;

    constructor(address payable _recipient){
        recipient = _recipient;
        owner = msg.sender;
    }

    function deposit() public payable {
        require(msg.sender == owner, "only the owner can deposit");
    }

    function withdraw(uint256 amount) public {
        require(msg.sender == recipient, "only the recipient can withdraw");
	require(amount <= address(this).balance, "the contract balance is less then required amount");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed.");
    }

}
