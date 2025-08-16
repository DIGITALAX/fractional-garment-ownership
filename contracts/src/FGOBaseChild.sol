// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./FGOAccessControl.sol";
import "./FGOLibrary.sol";
import "./FGOErrors.sol";

abstract contract FGOBaseChild is ERC1155 {
    FGOAccessControl public accessControl;
    mapping(uint256 => FGOLibrary.ChildMetadata) internal _childTokens;
    mapping(uint256 => uint256) internal _childSupply;
    mapping(address => mapping(uint256 => uint256)) private physicalRights;
    uint256 internal _supply;

    modifier onlyAdminOrSupplier() {
        if (!accessControl.canCreateChildren(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    modifier onlyChildCreator(uint256 childId) {
        if (_childTokens[childId].creator != msg.sender) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    modifier onlyAuthorizedMinter() {
        if (!accessControl.isAuthorizedMarket(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    event ChildCreated(uint256 indexed childId);
    event ChildMinted(
        uint256 indexed childId,
        address indexed to,
        uint256 amount
    );
    event ChildMetadataUpdated(uint256 indexed childId);
    event ChildDeleted(uint256 indexed childId);
    event ChildDisabled(uint256 indexed childId);
    event ChildEnabled(uint256 indexed childId);
    event ChildURIUpdated(
        uint256 indexed childId,
        string newURI,
        uint256 version,
        string updateReason
    );
    event PhysicalFulfillmentRequested(
        uint256 indexed childId,
        address indexed requester
    );
    event PhysicalFulfillmentCompleted(
        uint256 indexed childId,
        address indexed fulfiller
    );
    event BulkChildrenCreated(
        uint256 indexed startId,
        uint256 count,
        address indexed creator
    );

    constructor(address accessControlAddress) ERC1155("") {
        accessControl = FGOAccessControl(accessControlAddress);
    }

    function _createChild(
        uint256 price,
        uint256 version,
        uint256 maxPhysicalFulfillments,
        uint256 minPaymentValue,
        FGOLibrary.ChildType childType,
        FGOLibrary.ChildAvailability availability,
        bool isImmutable,
        string memory childUri,
        address[] memory acceptedCurrencies,
        address[] memory acceptedMarkets
    ) internal returns (uint256) {
        _supply++;

        _childTokens[_supply] = FGOLibrary.ChildMetadata({
            uri: childUri,
            price: price,
            childType: childType,
            version: version,
            maxPhysicalFulfillments: maxPhysicalFulfillments,
            physicalFulfillments: 0,
            acceptedCurrencies: acceptedCurrencies,
            minPaymentValue: minPaymentValue,
            acceptedMarkets: acceptedMarkets,
            status: FGOLibrary.ChildStatus.ACTIVE,
            uriVersion: 1,
            usageCount: 0,
            uriHistory: new FGOLibrary.URIVersion[](0),
            isImmutable: isImmutable,
            creator: msg.sender,
            availability: availability
        });

        _childTokens[_supply].uriHistory.push(
            FGOLibrary.URIVersion({
                uri: childUri,
                version: 1,
                timestamp: block.timestamp,
                updateReason: "Initial creation"
            })
        );

        emit ChildCreated(_supply);
        return _supply;
    }

    function uri(uint256 id) public view override returns (string memory) {
        return _childTokens[id].uri;
    }

    function _updateChildMetadata(
        uint256 childId,
        uint256 price,
        uint256 version,
        uint256 maxPhysicalFulfillments,
        uint256 minPaymentValue,
        FGOLibrary.ChildAvailability availability,
        bool makeImmutable,
        string memory childUri,
        string memory updateReason,
        address[] memory acceptedCurrencies,
        address[] memory acceptedMarkets
    ) internal {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }

        _childTokens[childId].price = price;
        _childTokens[childId].acceptedCurrencies = acceptedCurrencies;
        _childTokens[childId].minPaymentValue = minPaymentValue;
        _childTokens[childId].acceptedMarkets = acceptedMarkets;

        if (!_childTokens[childId].isImmutable) {
            _childTokens[childId].version = version;
            _childTokens[childId]
                .maxPhysicalFulfillments = maxPhysicalFulfillments;
            _childTokens[childId].availability = availability;

            if (bytes(childUri).length > 0) {
                _updateChildURI(childId, childUri, updateReason);
            }

            if (makeImmutable) {
                _childTokens[childId].isImmutable = true;
            }
        }

        emit ChildMetadataUpdated(childId);
    }


    function _deleteChild(uint256 childId) internal {
        if (_childSupply[childId] > 0) {
            revert FGOErrors.InvalidAmount();
        }

        if (_childTokens[childId].usageCount > 0) {
            revert FGOErrors.InvalidAmount();
        }

        _childTokens[childId].status = FGOLibrary.ChildStatus.DELETED;

        emit ChildDeleted(childId);
    }

    function _disableChild(uint256 childId) internal {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }

        _childTokens[childId].status = FGOLibrary.ChildStatus.DISABLED;
        emit ChildDisabled(childId);
    }

    function _updateChildURI(
        uint256 childId,
        string memory newURI,
        string memory updateReason
    ) internal {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }

        _childTokens[childId].uriVersion++;
        _childTokens[childId].uri = newURI;

        _childTokens[childId].uriHistory.push(
            FGOLibrary.URIVersion({
                uri: newURI,
                version: _childTokens[childId].uriVersion,
                timestamp: block.timestamp,
                updateReason: updateReason
            })
        );

        emit ChildURIUpdated(
            childId,
            newURI,
            _childTokens[childId].uriVersion,
            updateReason
        );
    }

    function _incrementUsageCount(uint256 childId) internal {
        _childTokens[childId].usageCount++;
    }

    function _decrementUsageCount(uint256 childId) internal {
        if (_childTokens[childId].usageCount > 0) {
            _childTokens[childId].usageCount--;
        }
    }

    function incrementUsageCount(uint256 childId) external {
        if (!accessControl.isAuthorizedMarket(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _incrementUsageCount(childId);
    }

    function decrementUsageCount(uint256 childId) external {
        if (!accessControl.isAuthorizedMarket(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _decrementUsageCount(childId);
    }


    function mintWithPhysicalRights(
        address to,
        uint256 childId,
        uint256 amount,
        uint256 physicalAmount
    ) external virtual onlyAuthorizedMinter {
        if (bytes(_childTokens[childId].uri).length == 0) {
            revert FGOErrors.InvalidChild();
        }

        if (physicalAmount > amount) {
            revert FGOErrors.InvalidAmount();
        }


        if (
            physicalAmount > 0 &&
            (_childTokens[childId].maxPhysicalFulfillments > 0 &&
                _childTokens[childId].physicalFulfillments + physicalAmount >
                _childTokens[childId].maxPhysicalFulfillments)
        ) {
            revert FGOErrors.MaxSupplyReached();
        }

        _mint(to, childId, amount, "");
        _childSupply[childId] += amount;

        if (physicalAmount > 0) {
            physicalRights[to][childId] += physicalAmount;
        }

        emit ChildMinted(childId, to, amount);
    }

    function getTokenSupply() public view returns (uint256) {
        return _supply;
    }

    function getChildURI(uint256 id) public view returns (string memory) {
        return _childTokens[id].uri;
    }

    function getChildPrice(uint256 id) public view returns (uint256) {
        return _childTokens[id].price;
    }

    function getChildVersion(uint256 id) public view returns (uint256) {
        return _childTokens[id].version;
    }

    function getChildType(
        uint256 id
    ) public view returns (FGOLibrary.ChildType) {
        return _childTokens[id].childType;
    }

    function getChildSupply(uint256 childId) public view returns (uint256) {
        return _childSupply[childId];
    }


    function childExists(uint256 childId) public view returns (bool) {
        if (bytes(_childTokens[childId].uri).length == 0) {
            return false;
        }
        return
            _childTokens[childId].status == FGOLibrary.ChildStatus.ACTIVE ||
            _childTokens[childId].status == FGOLibrary.ChildStatus.DISABLED;
    }

    function getChildMetadata(
        uint256 childId
    ) public view returns (FGOLibrary.ChildMetadata memory) {
        return _childTokens[childId];
    }

    function getPhysicalFulfillments(
        uint256 childId
    ) public view returns (uint256) {
        return _childTokens[childId].physicalFulfillments;
    }

    function getMaxPhysicalFulfillments(
        uint256 childId
    ) public view returns (uint256) {
        return _childTokens[childId].maxPhysicalFulfillments;
    }

    function canFulfillPhysically(uint256 childId) public view returns (bool) {
        if (_childTokens[childId].maxPhysicalFulfillments == 0) return true;
        return
            _childTokens[childId].physicalFulfillments <
            _childTokens[childId].maxPhysicalFulfillments;
    }

    function _fulfillPhysically(uint256 childId) internal {
        if (!canFulfillPhysically(childId)) {
            revert FGOErrors.MaxSupplyReached();
        }

        _childTokens[childId].physicalFulfillments++;
        emit PhysicalFulfillmentCompleted(childId, msg.sender);
    }

    function fulfillPhysically(uint256 childId) external {
        if (!accessControl.isAuthorizedMarket(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _fulfillPhysically(childId);
    }


    function _createChildrenBatch(
        uint256[] memory prices,
        uint256[] memory versions,
        uint256[] memory maxPhysicalFulfillments,
        uint256[] memory minPaymentValues,
        FGOLibrary.ChildType childType,
        FGOLibrary.ChildAvailability[] memory availabilities,
        bool[] memory isImmutableFlags,
        string[] memory uris,
        address[][] memory acceptedCurrencies,
        address[][] memory acceptedMarkets
    ) internal returns (uint256[] memory) {
        if (
            prices.length != versions.length ||
            versions.length != maxPhysicalFulfillments.length ||
            maxPhysicalFulfillments.length != minPaymentValues.length ||
            minPaymentValues.length != isImmutableFlags.length ||
            isImmutableFlags.length != availabilities.length ||
            availabilities.length != uris.length ||
            uris.length != acceptedCurrencies.length ||
            acceptedCurrencies.length != acceptedMarkets.length
        ) {
            revert FGOErrors.InvalidAmount();
        }

        uint256 batchSize = uris.length;
        uint256[] memory childIds = new uint256[](batchSize);
        uint256 startId = _supply + 1;
        
        _supply += batchSize;

        for (uint256 i = 0; i < batchSize; i++) {
            uint256 childId = startId + i;
            childIds[i] = childId;
            
            _childTokens[childId] = FGOLibrary.ChildMetadata({
                uri: uris[i],
                price: prices[i],
                childType: childType,
                version: versions[i],
                maxPhysicalFulfillments: maxPhysicalFulfillments[i],
                physicalFulfillments: 0,
                acceptedCurrencies: acceptedCurrencies[i],
                minPaymentValue: minPaymentValues[i],
                acceptedMarkets: acceptedMarkets[i],
                status: FGOLibrary.ChildStatus.ACTIVE,
                uriVersion: 1,
                usageCount: 0,
                uriHistory: new FGOLibrary.URIVersion[](0),
                isImmutable: isImmutableFlags[i],
                creator: msg.sender,
                availability: availabilities[i]
            });

            _childTokens[childId].uriHistory.push(
                FGOLibrary.URIVersion({
                    uri: uris[i],
                    version: 1,
                    timestamp: block.timestamp,
                    updateReason: "Initial creation"
                })
            );

            emit ChildCreated(childId);
        }

        emit BulkChildrenCreated(startId, batchSize, msg.sender);
        return childIds;
    }

    function _updateChildrenBatch(
        uint256[] memory childIds,
        uint256[] memory prices,
        uint256[] memory versions,
        uint256[] memory maxPhysicalFulfillments,
        uint256[] memory minPaymentValues,
        FGOLibrary.ChildAvailability[] memory availabilities,
        bool[] memory makeImmutableFlags,
        string[] memory childUris,
        string[] memory updateReasons,
        address[][] memory acceptedCurrencies,
        address[][] memory acceptedMarkets
    ) internal {
        if (
            childIds.length != prices.length ||
            prices.length != versions.length ||
            versions.length != maxPhysicalFulfillments.length ||
            maxPhysicalFulfillments.length != minPaymentValues.length ||
            minPaymentValues.length != makeImmutableFlags.length ||
            makeImmutableFlags.length != availabilities.length ||
            availabilities.length != childUris.length ||
            childUris.length != updateReasons.length ||
            updateReasons.length != acceptedCurrencies.length ||
            acceptedCurrencies.length != acceptedMarkets.length
        ) {
            revert FGOErrors.InvalidAmount();
        }

        for (uint256 i = 0; i < childIds.length; i++) {
            if (_childTokens[childIds[i]].creator != msg.sender) {
                revert FGOErrors.AddressInvalid();
            }
            _updateChildMetadata(
                childIds[i],
                prices[i],
                versions[i],
                maxPhysicalFulfillments[i],
                minPaymentValues[i],
                availabilities[i],
                makeImmutableFlags[i],
                childUris[i],
                updateReasons[i],
                acceptedCurrencies[i],
                acceptedMarkets[i]
            );
        }
    }

    function getPhysicalRights(
        address owner,
        uint256 childId
    ) public view returns (uint256) {
        return physicalRights[owner][childId];
    }

    function hasPhysicalRights(
        address owner,
        uint256 childId,
        uint256 amount
    ) public view returns (bool) {
        return physicalRights[owner][childId] >= amount;
    }

    function getChildAcceptedCurrencies(
        uint256 childId
    ) public view returns (address[] memory) {
        return _childTokens[childId].acceptedCurrencies;
    }

    function getChildMinPaymentValue(
        uint256 childId
    ) public view returns (uint256) {
        return _childTokens[childId].minPaymentValue;
    }

    function childAcceptsCurrency(
        uint256 childId,
        address currency
    ) public view returns (bool) {
        address[] memory acceptedCurrencies = _childTokens[childId]
            .acceptedCurrencies;

        if (acceptedCurrencies.length == 0) {
            return true;
        }

        for (uint256 i = 0; i < acceptedCurrencies.length; i++) {
            if (acceptedCurrencies[i] == currency) {
                return true;
            }
        }

        return false;
    }

    function getChildAcceptedMarkets(
        uint256 childId
    ) public view returns (address[] memory) {
        return _childTokens[childId].acceptedMarkets;
    }

    function childAcceptsMarket(
        uint256 childId,
        address market
    ) public view returns (bool) {
        address[] memory acceptedMarkets = _childTokens[childId]
            .acceptedMarkets;

        if (acceptedMarkets.length == 0) {
            return true;
        }

        for (uint256 i = 0; i < acceptedMarkets.length; i++) {
            if (acceptedMarkets[i] == market) {
                return true;
            }
        }

        return false;
    }

    function getChildStatus(
        uint256 childId
    ) public view returns (FGOLibrary.ChildStatus) {
        return _childTokens[childId].status;
    }

    function getChildURIVersion(uint256 childId) public view returns (uint256) {
        return _childTokens[childId].uriVersion;
    }

    function getChildUsageCount(uint256 childId) public view returns (uint256) {
        return _childTokens[childId].usageCount;
    }

    function getChildAvailability(uint256 childId) public view returns (FGOLibrary.ChildAvailability) {
        return _childTokens[childId].availability;
    }

    function getChildURIHistory(
        uint256 childId
    ) public view returns (FGOLibrary.URIVersion[] memory) {
        return _childTokens[childId].uriHistory;
    }

    function isChildActive(uint256 childId) public view returns (bool) {
        return _childTokens[childId].status == FGOLibrary.ChildStatus.ACTIVE;
    }

    function canDeleteChild(uint256 childId) public view returns (bool) {
        return
            childExists(childId) &&
            _childSupply[childId] == 0 &&
            _childTokens[childId].usageCount == 0;
    }

    function updateChildURI(
        uint256 childId,
        string memory newURI,
        string memory updateReason
    ) external onlyChildCreator(childId) {
        _updateChildURI(childId, newURI, updateReason);
    }

    function disableChild(
        uint256 childId
    ) external onlyChildCreator(childId) {
        _disableChild(childId);
    }

    function enableChild(
        uint256 childId
    ) external onlyChildCreator(childId) {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }

        _childTokens[childId].status = FGOLibrary.ChildStatus.ACTIVE;
        emit ChildEnabled(childId);
    }

    function getChildCreator(uint256 childId) public view returns (address) {
        return _childTokens[childId].creator;
    }

    function setAccessControl(address accessControlAddress) external onlyAdmin {
        accessControl = FGOAccessControl(accessControlAddress);
    }

    function deleteChild(uint256 childId) external virtual;

    function _getChildType() internal pure virtual returns (FGOLibrary.ChildType);
    function _emitChildCreated(uint256 childId) internal virtual;
    function _emitChildMetadataUpdated(uint256 childId) internal virtual;

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
    ) external virtual onlyAdminOrSupplier returns (uint256) {
        uint256 childId = _createChild(
            price,
            version,
            maxPhysicalFulfillments,
            minPaymentValue,
            _getChildType(),
            availability,
            isImmutable,
            childUri,
            acceptedCurrencies,
            acceptedMarkets
        );
        _emitChildCreated(childId);
        return childId;
    }

    function updateChildMetadata(
        uint256 childId,
        uint256 price,
        uint256 version,
        uint256 maxPhysicalFulfillments,
        uint256 minPaymentValue,
        FGOLibrary.ChildAvailability availability,
        bool makeImmutable,
        string memory childUri,
        string memory updateReason,
        address[] memory acceptedCurrencies,
        address[] memory acceptedMarkets
    ) external virtual onlyChildCreator(childId) {
        _updateChildMetadata(
            childId,
            price,
            version,
            maxPhysicalFulfillments,
            minPaymentValue,
            availability,
            makeImmutable,
            childUri,
            updateReason,
            acceptedCurrencies,
            acceptedMarkets
        );
        _emitChildMetadataUpdated(childId);
    }

    function createChildrenBatch(
        uint256[] memory prices,
        uint256[] memory versions,
        uint256[] memory maxPhysicalFulfillments,
        uint256[] memory minPaymentValues,
        bool[] memory isImmutableFlags,
        FGOLibrary.ChildAvailability[] memory availabilities,
        string[] memory uris,
        address[][] memory acceptedCurrencies,
        address[][] memory acceptedMarkets
    ) external virtual onlyAdminOrSupplier returns (uint256[] memory) {
        uint256[] memory childIds = _createChildrenBatch(
            prices,
            versions,
            maxPhysicalFulfillments,
            minPaymentValues,
            _getChildType(),
            availabilities,
            isImmutableFlags,
            uris,
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
        uint256[] memory maxPhysicalFulfillments,
        uint256[] memory minPaymentValues,
        bool[] memory makeImmutableFlags,
        FGOLibrary.ChildAvailability[] memory availabilities,
        string[] memory childUris,
        string[] memory updateReasons,
        address[][] memory acceptedCurrencies,
        address[][] memory acceptedMarkets
    ) external virtual {
        _updateChildrenBatch(
            childIds,
            prices,
            versions,
            maxPhysicalFulfillments,
            minPaymentValues,
            availabilities,
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
}
