// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOBaseChild.sol";

contract FGOFinishingTreatmentsChild is FGOBaseChild {
    string public constant name = "FGO Finishing Treatments";
    string public constant symbol = "FGOFINISH";
    
    event FinishingTreatmentsCreated(uint256 indexed childId);
    event FinishingTreatmentsMinted(uint256 indexed childId, address indexed to, uint256 amount);
    event FinishingTreatmentsMetadataUpdated(uint256 indexed childId);
    event FinishingTreatmentsDeleted(uint256 indexed childId);

    constructor(address accessControlAddress) FGOBaseChild(accessControlAddress) {}


    function deleteChild(uint256 childId) external override onlyChildCreator(childId) {
        _deleteChild(childId);
        emit FinishingTreatmentsDeleted(childId);
    }

    function _getChildType() internal pure override returns (uint256) {
        return 6; 
    }

    function _emitChildCreated(uint256 childId) internal override {
        emit FinishingTreatmentsCreated(childId);
    }

    function _emitChildMetadataUpdated(uint256 childId) internal override {
        emit FinishingTreatmentsMetadataUpdated(childId);
    }
}