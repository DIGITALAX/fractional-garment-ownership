// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOBaseChild.sol";

contract FGOMaterialChild is FGOBaseChild {
    string public constant name = "FGO Materials";
    string public constant symbol = "FGOMAT";

    event MaterialCreated(uint256 indexed childId);
    event MaterialMinted(
        uint256 indexed childId,
        address indexed to,
        uint256 amount
    );
    event MaterialMetadataUpdated(uint256 indexed childId);
    event MaterialDeleted(uint256 indexed childId);

    constructor(
        address accessControlAddress
    ) FGOBaseChild(accessControlAddress) {}

    function deleteChild(
        uint256 childId
    ) external override onlyChildCreator(childId) {
        _deleteChild(childId);
        emit MaterialDeleted(childId);
    }

    function createChild(
        FGOLibrary.CreateChildParams memory params
    ) external override onlyAdminOrSupplier returns (uint256) {
        uint256 childId = _createChild(params, 1); // MATERIAL
        _emitChildCreated(childId);
        return childId;
    }

    function createChildrenBatch(
        FGOLibrary.CreateChildrenBatchParams memory params
    ) external override onlyAdminOrSupplier returns (uint256[] memory) {
        uint256[] memory childIds = _createChildrenBatch(
            params,
            _getChildType()
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
        string[] memory childUris,
        uint256[] memory maxPhysicalFulfillments,
        address[] memory preferredPayoutCurrencies,
        address[][] memory acceptedMarkets,
        bool[] memory makeImmutableFlags,
        string[] memory updateReasons
    ) external {
        FGOLibrary.ChildAvailability[]
            memory availabilities = new FGOLibrary.ChildAvailability[](
                childIds.length
            );
        for (uint256 i = 0; i < childIds.length; i++) {
            availabilities[i] = FGOLibrary.ChildAvailability.BOTH;
        }

        FGOLibrary.UpdateChildrenBatchParams memory updateParams = FGOLibrary
            .UpdateChildrenBatchParams({
                childIds: childIds,
                prices: prices,
                versions: versions,
                maxPhysicalFulfillments: maxPhysicalFulfillments,
                makeImmutableFlags: makeImmutableFlags,
                availabilities: availabilities,
                childUris: childUris,
                updateReasons: updateReasons,
                preferredPayoutCurrencies: preferredPayoutCurrencies,
                acceptedMarkets: acceptedMarkets
            });

        _updateChildrenBatch(updateParams);

        for (uint256 i = 0; i < childIds.length; i++) {
            _emitChildMetadataUpdated(childIds[i]);
        }
    }

    function _getChildType() internal pure override returns (uint256) {
        return 1;
    }

    function _emitChildCreated(uint256 childId) internal override {
        emit MaterialCreated(childId);
    }

    function _emitChildMetadataUpdated(uint256 childId) internal override {
        emit MaterialMetadataUpdated(childId);
    }
}
