// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Escrow {
    enum States{IDLE, ACTIVE, WAITING_CONFIRMATION, PAYED}
    address buyer;
    address payable seller;
    address admin;
    uint256 price;
    States state;
    event Log(string func, uint value);
    modifier onlyBuyer(){
        require(msg.sender==buyer, "Only the buyer");
        _;
    }
    modifier onlySeller(){
        require(msg.sender==seller, "Only the seller");
        _;
    }

    constructor(uint256 _price, address _buyer, address payable _seller){
        admin = msg.sender;
        price = _price;
        buyer = _buyer;
        seller = _seller;
        state = States.IDLE;

    }
    fallback() external payable onlyBuyer{
        require(state == States.IDLE, "Invalid State");
        require(msg.value == price, "Invalid value");
        require(seller != address(0x0) && buyer != address(0x0), "set buyer and seller first""");
        emit Log("DEPOSIT", 0);
        state = States.ACTIVE;
    }
    function shipped() public onlySeller{
        require(state == States.ACTIVE, "Invalid State");
        emit Log("Shipped",0);
        state = States.WAITING_CONFIRMATION;
    }
    function payment() payable public onlyBuyer{
        require(state == States.WAITING_CONFIRMATION, "Invalid State");
        emit Log("Confirmation", msg.value);
        state = States.PAYED;
        seller.transfer(price);
    }

}
