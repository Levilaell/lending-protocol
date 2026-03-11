// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract MockOracle {
    uint public price;

    function setPrice(uint _price) public {
        price = _price;
    }

    function getPrice() external view returns (uint) {
        return price;
    }
}
