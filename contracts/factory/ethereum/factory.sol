// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

contract Product{
    string tag;
    address owner;
    address factory;

    constructor(string memory _tag){
        owner = tx.origin;
        factory = msg.sender;
        tag = _tag;
    }

    function getTag() public view returns(string memory){
        require(msg.sender == owner, "only the owner");
        return tag;
    }

    function getFactory() public view returns(address){
        return factory;
    }
}

contract Factory{
    mapping (address => address[]) productList;
    function createProduct(string memory _tag) public returns(address) {
        Product p = new Product(_tag);
        productList[msg.sender].push(address(p));
        return address(p);
    }

    function getProducts() public view returns(address[] memory){
        return productList[msg.sender];
    }
}