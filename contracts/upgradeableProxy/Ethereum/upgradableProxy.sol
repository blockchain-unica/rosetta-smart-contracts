// SPDX-License-Identifier: MIT

// Adapted from OpenZeppelin Contracts (last updated v4.6.0) (proxy/Proxy.sol)
// this code implements a simple upgradeable Proxy (no Beacon) with a non-upgradeable admin
// reference: https://docs.openzeppelin.com/contracts/4.x/api/proxy

pragma solidity ^0.8.0;


library StorageSlot {
    struct AddressSlot {
        address value;
    }
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }
}


library Address{

    function isContract(address account) internal view returns (bool) {

        return account.code.length > 0;
    }

    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage)
        internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        require(success, errorMessage);
        return returndata;
    }
}



abstract contract Proxy {

    function _delegate(address implementation) internal virtual {
        assembly {

            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function _implementation() internal view virtual returns (address);

    function _fallback() internal virtual {
        _beforeFallback();
        _delegate(_implementation());
    }

    fallback() external payable virtual {
        _fallback();
    }

    receive() external payable virtual {
        _fallback();
    }

    function _beforeFallback() internal virtual {}
}



abstract contract SimplifiedERC1967Upgrade {

    event Upgraded(address indexed implementation);

    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;


    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    function setAdmin(address newAdmin) internal {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    function _getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
    }

}

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



