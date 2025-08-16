// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

interface IPriceOracle {
    function getPrice(address currency) external view returns (uint256 price, uint8 decimals);
}