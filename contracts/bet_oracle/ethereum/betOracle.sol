// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Bet {

    // bettor = bettors[choice]
    mapping (uint => address payable) bettors;

    uint timeout;
    bool open = true;
    address oracle;
    uint wager;

    event newBet(address bet, address bettor, uint choice);

    modifier onlyOracle(){
        require( oracle == msg.sender , "only the oracle");
        _;
    }


    constructor(uint _timeout, uint _wager){
        wager = _wager;
        oracle = msg.sender;
        timeout = block.number + _timeout;

    }


    function bet(uint choice) payable public {

        require(msg.value == wager, "invalid value");
        require(choice > 0 && choice <= 2 , "invalid choice");
        require(open, "bets are closed");
        require(timeout >= block.number, "time out");
        require(bettors[choice] == address(0), "choice already selected" );

        bettors[choice] = payable(msg.sender);
        emit newBet(address(this), msg.sender, choice);

    }




    function oracleSetResult(uint result) external onlyOracle{
        require(timeout < block.number, "The bets are still open");
        require(open, "Results had already been set");

        open = false;
        address payable winner = bettors[result];
        (bool success,) = winner.call{value: address(this).balance}("");
        require (success, "Transfer failed.");



    }


}