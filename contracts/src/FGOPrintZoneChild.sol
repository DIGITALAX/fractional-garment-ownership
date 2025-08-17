// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOBaseChild.sol";

contract FGOPrintZoneChild is FGOBaseChild {
    string public constant name = "FGO Print Zones";
    string public constant symbol = "FGOZONE";

    event PrintZoneCreated(uint256 indexed childId);
    event PrintZoneMinted(
        uint256 indexed childId,
        address indexed to,
        uint256 amount
    );
    event PrintZoneMetadataUpdated(uint256 indexed childId);
    event PrintZoneDeleted(uint256 indexed childId);

    constructor(
        address accessControlAddress
    ) FGOBaseChild(accessControlAddress) {}

    function deleteChild(
        uint256 childId
    ) external override onlyChildCreator(childId) {
        _deleteChild(childId);
        emit PrintZoneDeleted(childId);
    }

    function _getChildType() internal pure override returns (uint256) {
        return 8;
    }

    function _emitChildCreated(uint256 childId) internal override {
        emit PrintZoneCreated(childId);
    }

    function _emitChildMetadataUpdated(uint256 childId) internal override {
        emit PrintZoneMetadataUpdated(childId);
    }
}