// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOBaseChild.sol";

contract FGOEmbellishmentsChild is FGOBaseChild {
    string public constant name = "FGO Embellishments";
    string public constant symbol = "FGOEMBEL";

    event EmbellishmentsCreated(uint256 indexed childId);
    event EmbellishmentsMinted(
        uint256 indexed childId,
        address indexed to,
        uint256 amount
    );
    event EmbellishmentsMetadataUpdated(uint256 indexed childId);
    event EmbellishmentsDeleted(uint256 indexed childId);

    constructor(
        address accessControlAddress
    ) FGOBaseChild(accessControlAddress) {}

    function deleteChild(
        uint256 childId
    ) external override onlyChildCreator(childId) {
        _deleteChild(childId);
        emit EmbellishmentsDeleted(childId);
    }

    function _getChildType() internal pure override returns (uint256) {
        return 3;
    }

    function _emitChildCreated(uint256 childId) internal override {
        emit EmbellishmentsCreated(childId);
    }

    function _emitChildMetadataUpdated(uint256 childId) internal override {
        emit EmbellishmentsMetadataUpdated(childId);
    }
}
