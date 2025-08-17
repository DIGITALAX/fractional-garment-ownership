// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOBaseChild.sol";

contract FGODigitalEffectsChild is FGOBaseChild {
    string public constant name = "FGO Digital Effects";
    string public constant symbol = "FGOFX";

    event DigitalEffectsCreated(uint256 indexed childId);
    event DigitalEffectsMinted(
        uint256 indexed childId,
        address indexed to,
        uint256 amount
    );
    event DigitalEffectsMetadataUpdated(uint256 indexed childId);
    event DigitalEffectsDeleted(uint256 indexed childId);

    constructor(
        address accessControlAddress
    ) FGOBaseChild(accessControlAddress) {}

    function deleteChild(
        uint256 childId
    ) external override onlyChildCreator(childId) {
        _deleteChild(childId);
        emit DigitalEffectsDeleted(childId);
    }

    function _getChildType() internal pure override returns (uint256) {
        return 5;
    }

    function _emitChildCreated(uint256 childId) internal override {
        emit DigitalEffectsCreated(childId);
    }

    function _emitChildMetadataUpdated(uint256 childId) internal override {
        emit DigitalEffectsMetadataUpdated(childId);
    }
}
