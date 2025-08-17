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
    mapping(address => mapping(uint256 => FGOLibrary.PhysicalRights)) private physicalRights;
    mapping(uint256 => mapping(address => bool)) internal _authorizedParents;
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
    event PhysicalParentAuthorized(uint256 indexed childId, address indexed parentContract);
    event PhysicalParentRevoked(uint256 indexed childId, address indexed parentContract);
    event PhysicalFulfillmentRequested(
        uint256 indexed childId,
        address indexed requester
    );
    event PhysicalFulfillmentCompleted(
        uint256 indexed childId,
        address indexed fulfiller
    );
    event NonGuaranteedOrderRejected(
        uint256 indexed childId,
        address indexed buyer,
        uint256 amount,
        string reason
    );
    event PhysicalRightsGranted(
        uint256 indexed childId,
        address indexed buyer,
        uint256 guaranteedAmount,
        uint256 nonGuaranteedAmount,
        address purchaseMarket
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
        FGOLibrary.CreateChildParams memory params,
        uint256 childType
    ) internal returns (uint256) {
        _supply++;

        _childTokens[_supply] = FGOLibrary.ChildMetadata({
            uri: params.childUri,
            price: params.price,
            childType: childType,
            version: params.version,
            maxPhysicalFulfillments: params.maxPhysicalFulfillments,
            physicalFulfillments: 0,
            preferredPayoutCurrency: params.preferredPayoutCurrency != address(0) ? params.preferredPayoutCurrency : accessControl.PAYMENT_TOKEN(),
            acceptedMarkets: params.acceptedMarkets,
            status: FGOLibrary.ChildStatus.ACTIVE,
            uriVersion: 1,
            usageCount: 0,
            uriHistory: new FGOLibrary.URIVersion[](0),
            isImmutable: params.isImmutable,
            creator: msg.sender,
            availability: params.availability
        });

        _childTokens[_supply].uriHistory.push(
            FGOLibrary.URIVersion({
                uri: params.childUri,
                version: 1,
                timestamp: block.timestamp,
                updateReason: "Initial creation"
            })
        );

        emit ChildCreated(_supply);
        return _supply;
    }

    function uri(uint256 id) public view override returns (string memory) {
        if (!childExists(id)) {
            revert FGOErrors.InvalidChild();
        }
        return _childTokens[id].uri;
    }

    function _updateChild(
        FGOLibrary.UpdateChildParams memory params
    ) internal {
        if (!childExists(params.childId)) {
            revert FGOErrors.InvalidChild();
        }

        _childTokens[params.childId].price = params.price;
        _childTokens[params.childId].preferredPayoutCurrency = params.preferredPayoutCurrency != address(0) ? params.preferredPayoutCurrency : accessControl.PAYMENT_TOKEN();
        _childTokens[params.childId].acceptedMarkets = params.acceptedMarkets;

        if (!_childTokens[params.childId].isImmutable) {
            _childTokens[params.childId].version = params.version;
            _childTokens[params.childId]
                .maxPhysicalFulfillments = params.maxPhysicalFulfillments;

            if (bytes(params.childUri).length > 0) {
                _updateChildURI(params.childId, params.childUri, params.updateReason);
            }

            if (params.makeImmutable) {
                _childTokens[params.childId].isImmutable = true;
            }
        }

        emit ChildMetadataUpdated(params.childId);
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
        uint256 physicalAmount,
        address parentContract,
        address purchaseMarket
    ) external virtual onlyAuthorizedMinter {
        if (bytes(_childTokens[childId].uri).length == 0) {
            revert FGOErrors.InvalidChild();
        }
        if (physicalAmount > 0 && parentContract != address(0) && !_authorizedParents[childId][parentContract]) {
            revert FGOErrors.AddressInvalid();
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
            bool isGuaranteed = childAcceptsMarket(childId, purchaseMarket);
            
            if (isGuaranteed) {
                physicalRights[to][childId].guaranteedAmount += physicalAmount;
            } else {
                physicalRights[to][childId].nonGuaranteedAmount += physicalAmount;
            }
            
            physicalRights[to][childId].purchaseMarket = purchaseMarket;
            
            emit PhysicalRightsGranted(
                childId,
                to,
                isGuaranteed ? physicalAmount : 0,
                isGuaranteed ? 0 : physicalAmount,
                purchaseMarket
            );
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
    ) public view returns (uint256) {
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
        FGOLibrary.CreateChildrenBatchParams memory params,
        uint256 childType
    ) internal returns (uint256[] memory) {
        if (
            params.prices.length != params.versions.length ||
            params.versions.length != params.maxPhysicalFulfillments.length ||
            params.maxPhysicalFulfillments.length != params.isImmutableFlags.length ||
            params.isImmutableFlags.length != params.availabilities.length ||
            params.availabilities.length != params.uris.length ||
            params.uris.length != params.preferredPayoutCurrencies.length ||
            params.preferredPayoutCurrencies.length != params.acceptedMarkets.length
        ) {
            revert FGOErrors.InvalidAmount();
        }

        uint256 batchSize = params.uris.length;
        uint256[] memory childIds = new uint256[](batchSize);
        uint256 startId = _supply + 1;
        
        _supply += batchSize;

        for (uint256 i = 0; i < batchSize; i++) {
            uint256 childId = startId + i;
            childIds[i] = childId;
            
            _childTokens[childId] = FGOLibrary.ChildMetadata({
                uri: params.uris[i],
                price: params.prices[i],
                childType: childType,
                version: params.versions[i],
                maxPhysicalFulfillments: params.maxPhysicalFulfillments[i],
                physicalFulfillments: 0,
                preferredPayoutCurrency: params.preferredPayoutCurrencies[i] != address(0) ? params.preferredPayoutCurrencies[i] : accessControl.PAYMENT_TOKEN(),
                acceptedMarkets: params.acceptedMarkets[i],
                status: FGOLibrary.ChildStatus.ACTIVE,
                uriVersion: 1,
                usageCount: 0,
                uriHistory: new FGOLibrary.URIVersion[](0),
                isImmutable: params.isImmutableFlags[i],
                creator: msg.sender,
                availability: params.availabilities[i]
            });

            _childTokens[childId].uriHistory.push(
                FGOLibrary.URIVersion({
                    uri: params.uris[i],
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
        FGOLibrary.UpdateChildrenBatchParams memory params
    ) internal {
        if (
            params.childIds.length != params.prices.length ||
            params.prices.length != params.versions.length ||
            params.versions.length != params.maxPhysicalFulfillments.length ||
            params.maxPhysicalFulfillments.length != params.makeImmutableFlags.length ||
            params.makeImmutableFlags.length != params.availabilities.length ||
            params.availabilities.length != params.childUris.length ||
            params.childUris.length != params.updateReasons.length ||
            params.updateReasons.length != params.preferredPayoutCurrencies.length ||
            params.preferredPayoutCurrencies.length != params.acceptedMarkets.length
        ) {
            revert FGOErrors.InvalidAmount();
        }

        for (uint256 i = 0; i < params.childIds.length; i++) {
            if (_childTokens[params.childIds[i]].creator != msg.sender) {
                revert FGOErrors.AddressInvalid();
            }
            
            FGOLibrary.UpdateChildParams memory updateParams = FGOLibrary.UpdateChildParams({
                childId: params.childIds[i],
                price: params.prices[i],
                version: params.versions[i],
                maxPhysicalFulfillments: params.maxPhysicalFulfillments[i],
                preferredPayoutCurrency: params.preferredPayoutCurrencies[i],
                availability: params.availabilities[i],
                makeImmutable: params.makeImmutableFlags[i],
                childUri: params.childUris[i],
                updateReason: params.updateReasons[i],
                acceptedMarkets: params.acceptedMarkets[i]
            });
            
            _updateChild(updateParams);
        }
    }

    function getPhysicalRights(
        address owner,
        uint256 childId
    ) public view returns (FGOLibrary.PhysicalRights memory) {
        return physicalRights[owner][childId];
    }

    function getTotalPhysicalRights(
        address owner,
        uint256 childId
    ) public view returns (uint256) {
        FGOLibrary.PhysicalRights memory rights = physicalRights[owner][childId];
        return rights.guaranteedAmount + rights.nonGuaranteedAmount;
    }

    function getGuaranteedPhysicalRights(
        address owner,
        uint256 childId
    ) public view returns (uint256) {
        return physicalRights[owner][childId].guaranteedAmount;
    }

    function getNonGuaranteedPhysicalRights(
        address owner,
        uint256 childId
    ) public view returns (uint256) {
        return physicalRights[owner][childId].nonGuaranteedAmount;
    }

    function hasPhysicalRights(
        address owner,
        uint256 childId,
        uint256 amount
    ) public view returns (bool) {
        return getTotalPhysicalRights(owner, childId) >= amount;
    }

    function hasGuaranteedPhysicalRights(
        address owner,
        uint256 childId,
        uint256 amount
    ) public view returns (bool) {
        return physicalRights[owner][childId].guaranteedAmount >= amount;
    }

    function getChildPreferredPayoutCurrency(
        uint256 childId
    ) public view returns (address) {
        return _childTokens[childId].preferredPayoutCurrency;
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

    function rejectNonGuaranteedOrder(
        uint256 childId,
        address buyer,
        uint256 amount,
        string memory reason
    ) external onlyChildCreator(childId) {
        if (physicalRights[buyer][childId].nonGuaranteedAmount < amount) {
            revert FGOErrors.InvalidAmount();
        }

        physicalRights[buyer][childId].nonGuaranteedAmount -= amount;
        
        emit NonGuaranteedOrderRejected(childId, buyer, amount, reason);
    }

    function authorizePhysicalParent(uint256 childId, address parentContract) external onlyChildCreator(childId) {
        if (parentContract == address(0)) {
            revert FGOErrors.AddressInvalid();
        }
        _authorizedParents[childId][parentContract] = true;
        emit PhysicalParentAuthorized(childId, parentContract);
    }

    function revokePhysicalParent(uint256 childId, address parentContract) external onlyChildCreator(childId) {
        _authorizedParents[childId][parentContract] = false;
        emit PhysicalParentRevoked(childId, parentContract);
    }

    function isPhysicalParentAuthorized(uint256 childId, address parentContract) external view returns (bool) {
        return _authorizedParents[childId][parentContract];
    }

    function authorizePhysicalParentsBatch(uint256 childId, address[] memory parentContracts) external onlyChildCreator(childId) {
        for (uint256 i = 0; i < parentContracts.length; i++) {
            if (parentContracts[i] != address(0)) {
                _authorizedParents[childId][parentContracts[i]] = true;
                emit PhysicalParentAuthorized(childId, parentContracts[i]);
            }
        }
    }

    function revokePhysicalParentsBatch(uint256 childId, address[] memory parentContracts) external onlyChildCreator(childId) {
        for (uint256 i = 0; i < parentContracts.length; i++) {
            _authorizedParents[childId][parentContracts[i]] = false;
            emit PhysicalParentRevoked(childId, parentContracts[i]);
        }
    }

    function deleteChild(uint256 childId) external virtual;

    function _getChildType() internal pure virtual returns (uint256);
    function _emitChildCreated(uint256 childId) internal virtual;
    function _emitChildMetadataUpdated(uint256 childId) internal virtual;

    function createChild(
        FGOLibrary.CreateChildParams memory params
    ) external virtual onlyAdminOrSupplier returns (uint256) {
        uint256 childId = _createChild(params, _getChildType());
        _emitChildCreated(childId);
        return childId;
    }

    function updateChild(
        FGOLibrary.UpdateChildParams memory params
    ) external virtual onlyChildCreator(params.childId) {
        _updateChild(params);
        _emitChildMetadataUpdated(params.childId);
    }

    function createChildrenBatch(
        FGOLibrary.CreateChildrenBatchParams memory params
    ) external virtual onlyAdminOrSupplier returns (uint256[] memory) {
        uint256[] memory childIds = _createChildrenBatch(params, _getChildType());
        
        for (uint256 i = 0; i < childIds.length; i++) {
            _emitChildCreated(childIds[i]);
        }
        
        return childIds;
    }

    function updateChildrenBatch(
        FGOLibrary.UpdateChildrenBatchParams memory params
    ) external virtual {
        _updateChildrenBatch(params);
        
        for (uint256 i = 0; i < params.childIds.length; i++) {
            _emitChildMetadataUpdated(params.childIds[i]);
        }
    }
}
