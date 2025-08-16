// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOBaseChild.sol";

contract FGODigitalEffectsChild is FGOBaseChild {
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

    function updateChildMetadata(
        uint256 childId,
        uint256 price,
        uint256 version,
        uint256 minPaymentValue,
        string memory childUri,
        uint256 maxPhysicalFulfillments,
        address[] memory acceptedCurrencies,
        address[] memory acceptedMarkets,
        bool makeImmutable,
        string memory updateReason
    ) external onlyChildCreator(childId) {
        _updateChildMetadata(childId, price, version, maxPhysicalFulfillments, minPaymentValue, FGOLibrary.ChildAvailability.BOTH, makeImmutable, childUri, updateReason, acceptedCurrencies, acceptedMarkets);
        _emitChildMetadataUpdated(childId);
    }

    function deleteChild(uint256 childId) external override onlyChildCreator(childId) {
        _deleteChild(childId);
        emit DigitalEffectsDeleted(childId);
    }

    function createChild(
        uint256 price,
        uint256 version,
        uint256 maxPhysicalFulfillments,
        uint256 minPaymentValue,
        FGOLibrary.ChildAvailability availability,
        bool isImmutable,
        string memory childUri,
        address[] memory acceptedCurrencies,
        address[] memory acceptedMarkets
    ) external override onlyAdminOrSupplier returns (uint256) {
        uint256 childId = _createChild(
            price,
            version,
            maxPhysicalFulfillments,
            minPaymentValue,
            FGOLibrary.ChildType.DIGITAL_EFFECTS,
            availability,
            isImmutable,
            childUri,
            acceptedCurrencies,
            acceptedMarkets
        );
        _emitChildCreated(childId);
        return childId;
    }

    function createChildrenBatch(
        uint256[] memory prices,
        uint256[] memory versions,
        uint256[] memory maxPhysicalFulfillments,
        uint256[] memory minPaymentValues,
        FGOLibrary.ChildAvailability[] memory availabilityFlags,
        bool[] memory isImmutableFlags,
        string[] memory childUris,
        address[][] memory acceptedCurrencies,
        address[][] memory acceptedMarkets
    ) external onlyAdminOrSupplier returns (uint256[] memory) {
        uint256[] memory childIds = _createChildrenBatch(
            prices,
            versions,
            maxPhysicalFulfillments,
            minPaymentValues,
            _getChildType(),
            availabilityFlags,
            isImmutableFlags,
            childUris,
            acceptedCurrencies,
            acceptedMarkets
        );
        
        for (uint256 i = 0; i < childIds.length; i++) {
            _emitChildCreated(childIds[i]);
        }
        
        return childIds;
    }

    function updateChildrenBatch(
        uint256[] memory childIds,
        uint256[] memory prices,
        uint256[] memory versions,
        uint256[] memory minPaymentValues,
        string[] memory childUris,
        uint256[] memory maxPhysicalFulfillments,
        address[][] memory acceptedCurrencies,
        address[][] memory acceptedMarkets,
        bool[] memory makeImmutableFlags,
        string[] memory updateReasons
    ) external {
        _updateChildrenBatch(
            childIds,
            prices,
            versions,
            maxPhysicalFulfillments,
            minPaymentValues,
            new FGOLibrary.ChildAvailability[](childIds.length),
            makeImmutableFlags,
            childUris,
            updateReasons,
            acceptedCurrencies,
            acceptedMarkets
        );
        
        for (uint256 i = 0; i < childIds.length; i++) {
            _emitChildMetadataUpdated(childIds[i]);
        }
    }

    function _getChildType() internal pure override returns (FGOLibrary.ChildType) {
        return FGOLibrary.ChildType.DIGITAL_EFFECTS;
    }

    function _emitChildCreated(uint256 childId) internal override {
        emit DigitalEffectsCreated(childId);
    }

    function _emitChildMetadataUpdated(uint256 childId) internal override {
        emit DigitalEffectsMetadataUpdated(childId);
    }
}
