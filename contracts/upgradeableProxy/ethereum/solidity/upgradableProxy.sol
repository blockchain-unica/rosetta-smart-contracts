// SPDX-License-Identifier: MIT

// Adapted from OpenZeppelin Contracts (last updated v4.6.0) (proxy/Proxy.sol)
// this code implements a simple upgradeable Proxy (no Beacon) with a non-upgradeable admin
// reference: https://docs.openzeppelin.com/contracts/4.x/api/proxy

pragma solidity ^0.8.0;
import 'utilsProxy.sol';

contract TheProxy is Proxy, SimplifiedERC1967Upgrade {

    constructor(address _logic) payable{
        _upgradeTo(_logic);
        setAdmin(msg.sender);
    }

    function _implementation() internal view virtual override returns (address impl) {
        return SimplifiedERC1967Upgrade._getImplementation();
    }

    function implementation() public view  returns (address impl) {
        return _implementation();

    }
    function getAdmin() public view returns (address) {
        return _getAdmin();
    }

    function upgradeTo(address newImplementation) public {
        _upgradeTo(newImplementation);
    }

}


contract Caller{

    /// @dev This function Calls the Logic function "check" passing its same address.
    function callLogicByProxy(address _proxy) public returns(bool,bool){
        string memory _abi = "check(address)";
        address param = address(this);
        bytes memory payload = abi.encodeWithSignature(_abi,param);
        (bool success, bytes memory result) = _proxy.call(payload);
        if (result[result.length-1] == bytes1(0x01)) return (success,true);
        return (success,false);

    }
}


contract Logic{

    /// @dev returns true if the balance of the _toCheck address is lower than 100.
    function check(address _toCheck) public view returns(bool) {
        if (_toCheck.balance < 100) return true;
        return false;
    }

}



