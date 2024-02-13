// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

contract atomicTx{

    struct Transaction {
        bytes data;
        uint8 sigV;
        bytes32 sigR;
        bytes32 sigS;
        bytes32 hash;
    }

    bool seal;

    Transaction[] public transactions;
    address owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }



    function addTransaction(Transaction memory transaction) public onlyOwner{
            require(keccak256(transaction.data)==transaction.hash, "transaction not valid");
            bool isValidSignature = ecrecover(transaction.hash, transaction.sigV, transaction.sigR, transaction.sigS) == owner;
            require(isValidSignature, "signature not valid");
            transactions.push(transaction);
    }


    function sealAtomicTransactions() public  onlyOwner{
        seal = true;
    }


    function reset() public onlyOwner {
        seal=false;
        delete transactions;
    }


    function executeTransactions() public onlyOwner {
       require(seal, "contract not sealed" );
       for (uint i=0;i<transactions.length; i++){
           Transaction memory transaction = transactions[i];
           (bool success, ) = address(this).delegatecall(transaction.data);
           require(success, "atomic transaction failed");
       }
    }


}