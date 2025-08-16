// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOBaseChild.sol";

contract FGOTemplatePackChild is FGOBaseChild {
    mapping(uint256 => FGOLibrary.ChildPlacement[]) private _templatePlacements;

    event TemplatePackCreated(uint256 indexed childId);
    event TemplatePackMinted(uint256 indexed childId, address indexed to, uint256 amount);
    event TemplatePackMetadataUpdated(uint256 indexed childId);
    event TemplatePackPlacementsUpdated(uint256 indexed childId);
    event TemplatePackDeleted(uint256 indexed childId);

    constructor(address accessControlAddress) FGOBaseChild(accessControlAddress) {}

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

    function updateTemplatePackPlacements(
        uint256 childId,
        FGOLibrary.ChildPlacement[] memory newPlacements
    ) external onlyChildCreator(childId) {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }
        
        if (_childSupply[childId] > 0) {
            revert FGOErrors.InvalidAmount();
        }
        
        delete _templatePlacements[childId];
        
        for (uint256 i = 0; i < newPlacements.length; i++) {
            _templatePlacements[childId].push(newPlacements[i]);
        }
        
        emit TemplatePackPlacementsUpdated(childId);
    }

    function deleteChild(uint256 childId) external override onlyChildCreator(childId) {
        _deleteChild(childId);
        delete _templatePlacements[childId];
        emit TemplatePackDeleted(childId);
    }

    function getTemplatePackPlacements(uint256 id) public view returns (FGOLibrary.ChildPlacement[] memory) {
        return _templatePlacements[id];
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
            FGOLibrary.ChildType.TEMPLATE_PACK,
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

    function createTemplatePack(
        uint256 price,
        uint256 version,
        uint256 maxPhysicalFulfillments,
        uint256 minPaymentValue,
        FGOLibrary.ChildAvailability availability,
        bool isImmutable,
        string memory childUri,
        address[] memory acceptedCurrencies,
        address[] memory acceptedMarkets,
        FGOLibrary.ChildPlacement[] memory placements
    ) public onlyAdminOrSupplier returns (uint256) {
        uint256 childId = _createChild(
            price,
            version,
            maxPhysicalFulfillments,
            minPaymentValue,
            FGOLibrary.ChildType.TEMPLATE_PACK,
            availability,
            isImmutable,
            childUri,
            acceptedCurrencies,
            acceptedMarkets
        );

        for (uint256 i = 0; i < placements.length; i++) {
            _templatePlacements[childId].push(placements[i]);
        }

        return childId;
    }

    function _getChildType() internal pure override returns (FGOLibrary.ChildType) {
        return FGOLibrary.ChildType.TEMPLATE_PACK;
    }

    function _emitChildCreated(uint256 childId) internal override {
        emit TemplatePackCreated(childId);
    }

    function _emitChildMetadataUpdated(uint256 childId) internal override {
        emit TemplatePackMetadataUpdated(childId);
    }
}