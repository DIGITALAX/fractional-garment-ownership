// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOTemplateBaseChild.sol";

contract FGOTemplateChild is FGOTemplateBaseChild {
    constructor(
        uint256 childType,
        address accessControl,
        string memory smu,
        string memory name,
        string memory symbol
    ) FGOTemplateBaseChild(childType, accessControl, smu, name, symbol) {}
}
