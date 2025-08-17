// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOBaseChild.sol";

contract FGOPrintDesignChild is FGOBaseChild {
    string public constant name = "FGO Print Designs";
    string public constant symbol = "FGOPRINT";

    event PrintDesignCreated(uint256 indexed childId);
    event PrintDesignMinted(
        uint256 indexed childId,
        address indexed to,
        uint256 amount
    );
    event PrintDesignMetadataUpdated(uint256 indexed childId);
    event PrintDesignDeleted(uint256 indexed childId);

    constructor(
        address accessControlAddress
    ) FGOBaseChild(accessControlAddress) {}

    function deleteChild(
        uint256 childId
    ) external override onlyChildCreator(childId) {
        _deleteChild(childId);
        emit PrintDesignDeleted(childId);
    }

    function _getChildType() internal pure override returns (uint256) {
        return 2;
    }

    function _emitChildCreated(uint256 childId) internal override {
        emit PrintDesignCreated(childId);
    }

    function _emitChildMetadataUpdated(uint256 childId) internal override {
        emit PrintDesignMetadataUpdated(childId);
    }
}
