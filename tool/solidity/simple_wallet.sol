// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

contract Simple_wallet{
    // Adapted from https://solidity-by-example.org/app/multi-sig-wallet/

    event Deposit(address indexed sender, uint amount, uint balance);
    event Withdraw(address indexed sender, uint amount);
    event SubmitTransaction(
        address indexed owner,
        uint indexed txId,
        address indexed to,
        uint value,
        bytes data
    );
    event ExecuteTransaction(address indexed owner, uint indexed txId);


    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    Transaction[] public transactions;
    address payable owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner");
        _;
    }

    constructor(address payable _owner) {
        require(_owner != address(0), "Invalid address.");
        owner = _owner;
        }

    function deposit() public payable {
         emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function createTransaction(
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwner {
        uint txId = transactions.length;
        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false
            })
        );

        emit SubmitTransaction(msg.sender, txId, _to, _value, _data);
    }

    function executeTransaction(
        uint _txId
    ) public onlyOwner {
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
        emit ExecuteTransaction(msg.sender, _txId);
    }


    function withdraw(
    ) public onlyOwner {
        uint withdraw_value = address(this).balance;
        (bool success, ) = owner.call{value: withdraw_value}("");
        require(success, "Transfer failed.");
        emit Withdraw(msg.sender, withdraw_value);
    }


}