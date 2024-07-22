// SPDX-License-Identifier: MIT
// Adapted from https://solidity-by-example.org/app/multi-sig-wallet/

pragma solidity ^0.8.0;

contract Simple_wallet{

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    Transaction[] public transactions;
    address payable private owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner");
        _;
    }

    constructor(address payable _owner) {
        require(_owner != address(0), "Invalid address.");
        owner = _owner;
        }

    function deposit() public payable {}

    function createTransaction(address _to, uint _value, bytes memory _data) public onlyOwner {
        uint txId = transactions.length;
        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false
            })
        );
    }

    function executeTransaction(uint _txId) public onlyOwner {
        require(_txId < transactions.length, "Transaction does not exist.");
        require(!transactions[_txId].executed, "Transaction already executed.");

        //Transaction storage
        Transaction memory transaction = transactions[_txId];
        require(transaction.value < address(this).balance, "Insufficient funds.");
        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "Transfer failed.");
   }


    function withdraw() public onlyOwner {
        uint withdraw_value = address(this).balance;
        (bool success, ) = owner.call{value: withdraw_value}("");
        require(success, "Transfer failed.");
    }

}