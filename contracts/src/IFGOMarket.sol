// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

interface IFGOMarket {
    function completePhysicalOrder(
        uint256 orderId,
        address buyer,
        uint256 parentTokenId
    ) external;
}
