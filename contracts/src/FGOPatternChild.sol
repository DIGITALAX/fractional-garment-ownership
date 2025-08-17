// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOBaseChild.sol";

contract FGOPatternChild is FGOBaseChild {
    string public constant name = "FGO Patterns";
    string public constant symbol = "FGOPAT";

    event PatternCreated(uint256 indexed childId);
    event PatternMinted(
        uint256 indexed childId,
        address indexed to,
        uint256 amount
    );
    event PatternMetadataUpdated(uint256 indexed childId);
    event PatternDeleted(uint256 indexed childId);

    constructor(
        address accessControlAddress
    ) FGOBaseChild(accessControlAddress) {}

    function createChild(
        FGOLibrary.CreateChildParams memory params
    ) external override onlyAdminOrSupplier returns (uint256) {
        uint256 childId = _createChild(params, 0); // PATTERN
        _emitChildCreated(childId);
        return childId;
    }

    function createChildrenBatch(
        uint256[] memory prices,
        uint256[] memory versions,
        uint256[] memory maxPhysicalFulfillments,
        FGOLibrary.ChildAvailability[] memory availabilityFlags,
        bool[] memory isImmutableFlags,
        string[] memory childUris,
        address[] memory preferredPayoutCurrencies,
        address[][] memory acceptedMarkets
    ) external onlyAdminOrSupplier returns (uint256[] memory) {
        FGOLibrary.CreateChildrenBatchParams memory batchParams = FGOLibrary
            .CreateChildrenBatchParams({
                prices: prices,
                versions: versions,
                maxPhysicalFulfillments: maxPhysicalFulfillments,
                isImmutableFlags: isImmutableFlags,
                availabilities: availabilityFlags,
                uris: childUris,
                preferredPayoutCurrencies: preferredPayoutCurrencies,
                acceptedMarkets: acceptedMarkets
            });

        uint256[] memory childIds = _createChildrenBatch(
            batchParams,
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

    function deleteChild(
        uint256 childId
    ) external override onlyChildCreator(childId) {
        _deleteChild(childId);
        emit PatternDeleted(childId);
    }

    function _getChildType() internal pure override returns (uint256) {
        return 0;
    }

    function _emitChildCreated(uint256 childId) internal override {
        emit PatternCreated(childId);
    }

    function _emitChildMetadataUpdated(uint256 childId) internal override {
        emit PatternMetadataUpdated(childId);
    }
}
