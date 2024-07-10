// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.1;

contract PriceBet{
    uint256 initial_pot;
    uint256 deadline_block;
    uint256 exchange_rate;
    address oracle;
    address payable owner;
    address payable player;


    constructor(address _oracle, uint256 _deadline, uint256 _exchange_rate) payable {
        initial_pot = msg.value;
        owner = payable(msg.sender);
        oracle = _oracle;
        deadline_block = block.number + _deadline;
        exchange_rate = _exchange_rate;
    }

    function join() public payable {
        require(msg.value == initial_pot);
        require(player == address(0));
        player = payable(msg.sender);
    }

    function win() public {
        Oracle TheOracle = Oracle(oracle);
        require(block.number < deadline_block, "deadline expired");
        require(msg.sender == player, "invalid sender");
        require(TheOracle.get_exchange_rate() >= exchange_rate, "you lost the bet");
        (bool success, ) = player.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function timeout() public {
        require(block.number >= deadline_block, "deadline not expired");
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

}


contract Oracle{

    uint256 exchange_rate = 10;
    function get_exchange_rate() public view returns(uint256){
        return exchange_rate;
    }

}
