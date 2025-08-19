// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOBaseParent.sol";

contract FGOParent is FGOBaseParent {
    constructor(
        address accessControl,
        string memory smu,
        string memory name,
        string memory symbol,
        string memory parentURI
    ) FGOBaseParent(accessControl, smu, name, symbol, parentURI) {}
}
