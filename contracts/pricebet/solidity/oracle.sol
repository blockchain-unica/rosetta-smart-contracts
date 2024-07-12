// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.1;

contract Oracle{

    uint256 exchange_rate = 10;
    function get_exchange_rate() public view returns(uint256){
        return exchange_rate;
    }

}
