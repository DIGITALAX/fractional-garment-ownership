// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOBaseChild.sol";

contract FGOChild is FGOBaseChild {
    constructor(
        uint256 childType,
        address accessControl,
        string memory smu,
        string memory name,
        string memory symbol
    ) FGOBaseChild(childType, accessControl, smu, name, symbol) {}
}
