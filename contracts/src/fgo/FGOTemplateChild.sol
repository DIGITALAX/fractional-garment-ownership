// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOTemplateBaseChild.sol";

contract FGOTemplateChild is FGOTemplateBaseChild {
    constructor(
        uint256 childType,
        bytes32 infraId,
        address accessControl,
        string memory scm,
        string memory name,
        string memory symbol
    ) FGOTemplateBaseChild(childType, infraId, accessControl, scm, name, symbol) {}
}
