// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.1;

contract SaveValue {
	uint16 public savedValue;
	constructor() {
		savedValue = 10;
	}


	function writevalue(uint16 newVal) public{
		savedValue = newVal;
	}
}
