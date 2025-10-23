// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOBaseParent.sol";

contract FGOParent is FGOBaseParent {
    constructor(
        bytes32 infraId,
        address accessControl,
        address fulfillers,
        address supplyCoordination,
        string memory scm,
        string memory name,
        string memory symbol,
        string memory parentURI
    ) FGOBaseParent(infraId, accessControl, fulfillers, supplyCoordination, scm, name, symbol, parentURI) {}
}
