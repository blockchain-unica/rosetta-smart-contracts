// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.1;

// The contract SimpleTransfer allows a user to deposit an
// amount of native cryptocurrency in the contract, and to
// specify a recipient.  At any later time, the recipient
// can withdraw any fraction of the  funds available in
// the contract.

contract SimpleTransfer{

    event Withdraw(address indexed sender, uint amount);
    address payable recipient;
    address owner;

    constructor(address payable _recipient){
        recipient = _recipient;
        owner = msg.sender;
    }

    function deposit() public payable {
        require(msg.sender == owner, "Only the owner can deposit");
    }


    function withdraw(uint256 amount) public payable {
        require(msg.sender == recipient, "only the recipient can withdraw");
        require(address(this).balance > 0, "The contract balance is zero");
        if (address(this).balance < amount){
            amount = address(this).balance;
        }
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed.");
        emit Withdraw(msg.sender, amount);

    }

}
