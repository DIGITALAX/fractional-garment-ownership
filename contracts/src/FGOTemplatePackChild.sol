// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOBaseChild.sol";

contract FGOTemplatePackChild is FGOBaseChild {
    string public constant name = "FGO Template Packs";
    string public constant symbol = "FGOPACK";

    mapping(uint256 => FGOLibrary.ChildPlacement[]) private _templatePlacements;

    event TemplatePackCreated(uint256 indexed childId);
    event TemplatePackMinted(
        uint256 indexed childId,
        address indexed to,
        uint256 amount
    );
    event TemplatePackMetadataUpdated(uint256 indexed childId);
    event TemplatePackPlacementsUpdated(uint256 indexed childId);
    event TemplatePackDeleted(uint256 indexed childId);

    constructor(
        address accessControlAddress
    ) FGOBaseChild(accessControlAddress) {}

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

    function deleteChild(
        uint256 childId
    ) external override onlyChildCreator(childId) {
        _deleteChild(childId);
        delete _templatePlacements[childId];
        emit TemplatePackDeleted(childId);
    }

    function getTemplatePackPlacements(
        uint256 id
    ) public view returns (FGOLibrary.ChildPlacement[] memory) {
        return _templatePlacements[id];
    }

    function createChild(
        FGOLibrary.CreateChildParams memory
    ) external pure override returns (uint256) {
        revert FGOErrors.InvalidChild();
    }

    function createChildrenBatch(
        FGOLibrary.CreateChildrenBatchParams memory
    ) external pure override returns (uint256[] memory) {
        revert FGOErrors.InvalidChild();
    }

    function updateChildrenBatch(
        FGOLibrary.UpdateChildrenBatchParams memory params
    ) external override {
        _updateChildrenBatch(params);

        for (uint256 i = 0; i < params.childIds.length; i++) {
            _emitChildMetadataUpdated(params.childIds[i]);
        }
    }

    function createTemplatePack(
        FGOLibrary.CreateTemplatePackParams memory params
    ) public onlyAdminOrSupplier returns (uint256) {
        if (params.placements.length == 0) {
            revert FGOErrors.InvalidAmount();
        }

        FGOLibrary.CreateChildParams memory childParams = FGOLibrary
            .CreateChildParams({
                price: params.price,
                version: params.version,
                maxPhysicalFulfillments: params.maxPhysicalFulfillments,
                preferredPayoutCurrency: params.preferredPayoutCurrency,
                availability: params.availability,
                isImmutable: params.isImmutable,
                childUri: params.childUri,
                acceptedMarkets: params.acceptedMarkets
            });

        uint256 childId = _createChild(childParams, 7);

        for (uint256 i = 0; i < params.placements.length; i++) {
            _templatePlacements[childId].push(params.placements[i]);
        }

        return childId;
    }

    function _getChildType() internal pure override returns (uint256) {
        return 7;
    }

    function _emitChildCreated(uint256 childId) internal override {
        emit TemplatePackCreated(childId);
    }

    function _emitChildMetadataUpdated(uint256 childId) internal override {
        emit TemplatePackMetadataUpdated(childId);
    }
}
