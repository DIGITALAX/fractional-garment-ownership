// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOBaseMarket.sol";

contract FGOMarket is FGOBaseMarket {
    constructor(
        bytes32 infraId,
        address accessControl,
        address fulfillers,
        string memory symbol,
        string memory name,
        string memory marketURI
    )
        FGOBaseMarket(
            infraId,
            accessControl,
            fulfillers,
            symbol,
            name,
            marketURI
        )
    {}
}
