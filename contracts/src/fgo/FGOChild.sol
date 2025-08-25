// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOBaseChild.sol";

contract FGOChild is FGOBaseChild {
    constructor(
        uint256 childType,
        bytes32 infraId,
        address accessControl,
        string memory scm,
        string memory name,
        string memory symbol
    ) FGOBaseChild(childType, infraId, accessControl, scm, name, symbol) {}
}
