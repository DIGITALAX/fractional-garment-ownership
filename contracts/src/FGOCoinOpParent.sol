// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOBaseParent.sol";

contract FGOCoinOpParent is FGOBaseParent {
    event CoinOpDesignCreated(uint256 indexed designId, address indexed designer);
    event CoinOpDesignUpdated(uint256 indexed designId);

    constructor(address _accessControl, string memory _collectionURI) 
        FGOBaseParent(_accessControl, "FGO Coin-Op Collections", "FGOCOINOP", _collectionURI) 
    {}

    function _getParentType() internal pure override returns (string memory) {
        return "CoinOp";
    }
}