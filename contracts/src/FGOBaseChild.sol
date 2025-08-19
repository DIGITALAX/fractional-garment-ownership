// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./FGOAccessControl.sol";
import "./FGOLibrary.sol";
import "./FGOErrors.sol";

abstract contract FGOBaseChild is ERC1155, ReentrancyGuard {
    uint256 internal _childSupply;
    uint256 public constant MAX_AUTHORIZED_ADDRESSES = 50;
    uint256 public childType;
    string public smu;
    string public name;
    string public symbol;
    FGOAccessControl public accessControl;

    mapping(uint256 => FGOLibrary.ChildMetadata) internal _children;
    mapping(address => mapping(uint256 => FGOLibrary.PhysicalRights))
        private physicalRights;
    mapping(uint256 => mapping(address => mapping(uint256 => bool)))
        internal _authorizedParents;
    mapping(uint256 => mapping(address => bool)) internal _authorizedMarkets;
    mapping(uint256 => mapping(address => mapping(uint256 => bool)))
        internal _authorizedTemplates;
    mapping(uint256 => mapping(address => mapping(uint256 => FGOLibrary.ParentApprovalRequest)))
        private _parentRequests;
    mapping(uint256 => mapping(address => FGOLibrary.ChildMarketApprovalRequest))
        private _marketRequests;
    mapping(uint256 => mapping(address => mapping(uint256 => FGOLibrary.TemplateApprovalRequest)))
        private _templateRequests;

    event ChildCreated(uint256 indexed childId, address indexed supplier);
    event ChildUpdated(uint256 indexed childId);
    event ChildDeleted(uint256 indexed childId);
    event ChildDisabled(uint256 indexed childId);
    event ChildEnabled(uint256 indexed childId);
    event ParentApproved(
        uint256 indexed childId,
        address indexed parentContract
    );
    event ParentRevoked(
        uint256 indexed childId,
        address indexed parentContract
    );
    event MarketApproved(uint256 indexed childId, address indexed market);
    event MarketRevoked(uint256 indexed childId, address indexed market);
    event ParentApprovalRequested(
        uint256 indexed childId,
        address indexed parentContract
    );
    event ParentApprovalRejected(
        uint256 indexed childId,
        address indexed parentContract
    );
    event MarketApprovalRequested(
        uint256 indexed childId,
        address indexed market
    );
    event MarketApprovalRejected(
        uint256 indexed childId,
        address indexed market
    );
    event TemplateApprovalRequested(
        uint256 indexed childId,
        uint256 indexed templateId,
        address indexed templateContract
    );
    event TemplateApprovalRejected(
        uint256 indexed childId,
        uint256 indexed templateId,
        address indexed templateContract
    );
    event TemplateApproved(
        uint256 indexed childId,
        address indexed templateContract
    );
    event TemplateRevoked(
        uint256 indexed childId,
        address indexed templateContract
    );

    modifier onlySupplier() {
        if (!accessControl.canCreateChildren(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    modifier onlyChildOwner(uint256 childId) {
        if (_children[childId].supplier != msg.sender) {
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

    constructor(
        uint256 _childType,
        address _accessControl,
        string memory _smu,
        string memory _name,
        string memory _symbol
    ) ERC1155("") {
        accessControl = FGOAccessControl(_accessControl);
        smu = _smu;
        childType = _childType;
        name = _name;
        symbol = _symbol;
    }

    function createChild(
        FGOLibrary.CreateChildParams memory params
    ) external virtual onlySupplier returns (uint256) {
        uint256 childId = _createChild(params);

        emit ChildCreated(_childSupply, msg.sender);

        return childId;
    }

    function _createChild(
        FGOLibrary.CreateChildParams memory params
    ) internal returns (uint256) {
        _childSupply++;

        FGOLibrary.ChildMetadata storage child = _children[_childSupply];

        child.digitalPrice = params.digitalPrice;
        child.physicalPrice = params.physicalPrice;
        child.version = params.version;
        child.maxPhysicalFulfillments = params.maxPhysicalFulfillments;
        child.physicalFulfillments = 0;
        child.uriVersion = 1;
        child.usageCount = 0;
        child.supplyCount = 0;
        child.supplier = msg.sender;
        child.preferredPayoutCurrency = params.preferredPayoutCurrency !=
            address(0)
            ? params.preferredPayoutCurrency
            : accessControl.PAYMENT_TOKEN();
        child.status = FGOLibrary.ActiveStatus.ACTIVE;
        child.availability = params.availability;
        child.isImmutable = params.isImmutable;
        child.digitalOpenToAll = params.digitalOpenToAll;
        child.physicalOpenToAll = params.physicalOpenToAll;
        child.digitalReferencesOpenToAll = params.digitalReferencesOpenToAll;
        child.physicalReferencesOpenToAll = params.physicalReferencesOpenToAll;
        child.uri = params.childUri;

        _setAuthorizedMarkets(_childSupply, params.authorizedMarkets);

        return _childSupply;
    }

    function updateChild(
        FGOLibrary.UpdateChildParams memory params
    ) external virtual onlyChildOwner(params.childId) {
        _updateChild(params);
        emit ChildUpdated(params.childId);
    }

    function _updateChild(FGOLibrary.UpdateChildParams memory params) internal {
        FGOLibrary.ChildMetadata storage child = _children[params.childId];

        child.digitalPrice = params.digitalPrice;
        child.physicalPrice = params.physicalPrice;
        child.maxPhysicalFulfillments = params.maxPhysicalFulfillments;
        child.preferredPayoutCurrency = params.preferredPayoutCurrency !=
            address(0)
            ? params.preferredPayoutCurrency
            : accessControl.PAYMENT_TOKEN();
        child.digitalOpenToAll = params.digitalOpenToAll;
        child.physicalOpenToAll = params.physicalOpenToAll;

        if (!child.isImmutable) {
            child.uri = params.childUri;
            child.uriVersion++;
            child.version = params.version;
            child.availability = params.availability;
        }

        address[] memory oldMarkets = child.authorizedMarkets;
        if (params.authorizedMarkets.length > MAX_AUTHORIZED_ADDRESSES) {
            revert FGOErrors.BatchTooLarge();
        }

        child.authorizedMarkets = params.authorizedMarkets;

        _clearAuthorizedMarkets(params.childId, oldMarkets);
        _setAuthorizedMarkets(params.childId, params.authorizedMarkets);

        if (params.makeImmutable) {
            child.isImmutable = true;
        }
    }

    function approveParent(
        uint256 childId,
        uint256 parentId,
        address parentContract
    ) external onlyChildOwner(childId) {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.status != FGOLibrary.ActiveStatus.ACTIVE) {
            revert FGOErrors.InvalidAmount();
        }

        if (_authorizedParents[childId][parentContract][parentId]) {
            return;
        }

        _authorizedParents[childId][parentContract][parentId] = true;

        emit ParentApproved(childId, parentContract);
    }

    function revokeParent(
        uint256 childId,
        uint256 parentId,
        address parentContract
    ) external onlyChildOwner(childId) {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }

        if (!_authorizedParents[childId][parentContract][parentId]) {
            return;
        }

        _authorizedParents[childId][parentContract][parentId] = false;

        emit ParentRevoked(childId, parentContract);
    }

    function approveMarket(
        uint256 childId,
        address market
    ) external onlyChildOwner(childId) {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.status != FGOLibrary.ActiveStatus.ACTIVE) {
            revert FGOErrors.InvalidAmount();
        }

        if (_authorizedMarkets[childId][market]) {
            return;
        }

        if (child.authorizedMarkets.length > MAX_AUTHORIZED_ADDRESSES) {
            revert FGOErrors.BatchTooLarge();
        }

        _authorizedMarkets[childId][market] = true;
        child.authorizedMarkets.push(market);

        emit MarketApproved(childId, market);
    }

    function revokeMarket(
        uint256 childId,
        address market
    ) external onlyChildOwner(childId) {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }

        if (!_authorizedMarkets[childId][market]) {
            return;
        }

        _authorizedMarkets[childId][market] = false;

        FGOLibrary.ChildMetadata storage child = _children[childId];
        uint256 marketsLength = child.authorizedMarkets.length;
        for (uint256 i = 0; i < marketsLength; ) {
            if (child.authorizedMarkets[i] == market) {
                child.authorizedMarkets[i] = child.authorizedMarkets[
                    marketsLength - 1
                ];
                child.authorizedMarkets.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }

        emit MarketRevoked(childId, market);
    }

    function requestMarketApproval(uint256 childId) external {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }

        FGOLibrary.ChildMarketApprovalRequest storage request = _marketRequests[
            childId
        ][msg.sender];
        request.market = msg.sender;
        request.childId = childId;
        request.timestamp = block.timestamp;
        request.isPending = true;

        emit MarketApprovalRequested(childId, msg.sender);
    }

    function requestParentApproval(uint256 childId, uint256 parentId) external {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }

        FGOLibrary.ParentApprovalRequest storage request = _parentRequests[
            childId
        ][msg.sender][parentId];
        request.parentContract = msg.sender;
        request.childId = childId;
        request.parentId = parentId;
        request.timestamp = block.timestamp;
        request.isPending = true;

        emit ParentApprovalRequested(childId, msg.sender);
    }

    function requestTemplateApproval(
        uint256 childId,
        uint256 templateId
    ) external {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }

        FGOLibrary.TemplateApprovalRequest storage request = _templateRequests[
            childId
        ][msg.sender][templateId];
        request.templateContract = msg.sender;
        request.childId = childId;
        request.templateId = templateId;
        request.timestamp = block.timestamp;
        request.isPending = true;

        emit TemplateApprovalRequested(childId, templateId, msg.sender);
    }

    function approveMarketRequest(
        uint256 childId,
        address market
    ) external onlyChildOwner(childId) {
        FGOLibrary.ChildMarketApprovalRequest storage request = _marketRequests[
            childId
        ][market];
        if (!request.isPending) {
            revert FGOErrors.NoPendingRequest();
        }

        if (_authorizedMarkets[childId][market]) {
            request.isPending = false;
            return;
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.authorizedMarkets.length > MAX_AUTHORIZED_ADDRESSES) {
            revert FGOErrors.BatchTooLarge();
        }

        _authorizedMarkets[childId][market] = true;
        request.isPending = false;
        child.authorizedMarkets.push(market);

        emit MarketApproved(childId, market);
    }

    function rejectMarketRequest(
        uint256 childId,
        address market
    ) external onlyChildOwner(childId) {
        FGOLibrary.ChildMarketApprovalRequest storage request = _marketRequests[
            childId
        ][market];
        if (!request.isPending) {
            revert FGOErrors.NoPendingRequest();
        }

        request.isPending = false;
        emit MarketApprovalRejected(childId, market);
    }

    function approveParentRequest(
        uint256 childId,
        uint256 parentId,
        address parentContract
    ) external onlyChildOwner(childId) {
        FGOLibrary.ParentApprovalRequest storage request = _parentRequests[
            childId
        ][parentContract][parentId];
        if (!request.isPending) {
            revert FGOErrors.NoPendingRequest();
        }

        if (_authorizedParents[childId][parentContract][parentId]) {
            request.isPending = false;
            return;
        }

        _authorizedParents[childId][parentContract][parentId] = true;
        request.isPending = false;

        emit ParentApproved(childId, parentContract);
    }

    function rejectParentRequest(
        uint256 childId,
        uint256 parentId,
        address parentContract
    ) external onlyChildOwner(childId) {
        FGOLibrary.ParentApprovalRequest storage request = _parentRequests[
            childId
        ][parentContract][parentId];
        if (!request.isPending) {
            revert FGOErrors.NoPendingRequest();
        }

        request.isPending = false;
        emit ParentApprovalRejected(childId, parentContract);
    }

    function approveTemplateRequest(
        uint256 childId,
        uint256 templateId,
        address templateContract
    ) external onlyChildOwner(childId) {
        FGOLibrary.TemplateApprovalRequest storage request = _templateRequests[
            childId
        ][templateContract][templateId];
        if (!request.isPending) {
            revert FGOErrors.NoPendingRequest();
        }

        if (_authorizedTemplates[childId][templateContract][templateId]) {
            request.isPending = false;
            return;
        }

        _authorizedTemplates[childId][templateContract][templateId] = true;
        request.isPending = false;

        emit TemplateApproved(childId, templateContract);
    }

    function rejectTemplateRequest(
        uint256 childId,
        uint256 templateId,
        address templateContract
    ) external onlyChildOwner(childId) {
        FGOLibrary.TemplateApprovalRequest storage request = _templateRequests[
            childId
        ][templateContract][templateId];
        if (!request.isPending) {
            revert FGOErrors.NoPendingRequest();
        }

        request.isPending = false;
        emit TemplateApprovalRejected(childId, templateId, templateContract);
    }

    function approveTemplate(
        uint256 childId,
        uint256 templateId,
        address templateContract
    ) external onlyChildOwner(childId) {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.status != FGOLibrary.ActiveStatus.ACTIVE) {
            revert FGOErrors.InvalidAmount();
        }

        if (_authorizedTemplates[childId][templateContract][templateId]) {
            return;
        }

        _authorizedTemplates[childId][templateContract][templateId] = true;

        emit TemplateApproved(childId, templateContract);
    }

    function revokeTemplate(
        uint256 childId,
        uint256 templateId,
        address templateContract
    ) external onlyChildOwner(childId) {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }

        if (!_authorizedTemplates[childId][templateContract][templateId]) {
            return;
        }

        _authorizedTemplates[childId][templateContract][templateId] = false;

        emit TemplateRevoked(childId, templateContract);
    }

    function getMarketRequest(
        uint256 childId,
        address market
    ) external view returns (FGOLibrary.ChildMarketApprovalRequest memory) {
        return _marketRequests[childId][market];
    }

    function getParentRequest(
        uint256 childId,
        uint256 parentId,
        address parentContract
    ) external view returns (FGOLibrary.ParentApprovalRequest memory) {
        return _parentRequests[childId][parentContract][parentId];
    }

    function getTemplateRequest(
        uint256 childId,
        uint256 templateId,
        address templateContract
    ) external view returns (FGOLibrary.TemplateApprovalRequest memory) {
        return _templateRequests[childId][templateContract][templateId];
    }

    function approvesParent(
        uint256 childId,
        uint256 parentId,
        address parentContract
    ) external view returns (bool) {
        return _authorizedParents[childId][parentContract][parentId];
    }

    function approvesMarket(
        uint256 childId,
        address market
    ) external view returns (bool) {
        FGOLibrary.ChildMetadata storage child = _children[childId];
        return
            child.digitalOpenToAll ||
            child.physicalOpenToAll ||
            _authorizedMarkets[childId][market];
    }

    function approvesTemplate(
        uint256 childId,
        uint256 templateId,
        address templateContract
    ) external view returns (bool) {
        return _authorizedTemplates[childId][templateContract][templateId];
    }

    function mint(
        uint256 childId,
        uint256 amount,
        bool isPhysical,
        address to,
        address market
    ) external virtual nonReentrant {
        if (to == address(0)) {
            revert FGOErrors.AddressInvalid();
        }
        if (amount == 0) {
            revert FGOErrors.InvalidAmount();
        }
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.status != FGOLibrary.ActiveStatus.ACTIVE) {
            revert FGOErrors.InvalidAmount();
        }

        bool isSupplier = accessControl.isSupplier(msg.sender);

        bool isAuthorizedMarket = child.digitalOpenToAll ||
            child.physicalOpenToAll ||
            _authorizedMarkets[childId][msg.sender];
        if (!isAuthorizedMarket && !isSupplier) {
            revert FGOErrors.MarketNotAuthorized();
        }

        if (isPhysical) {
            if (child.availability == FGOLibrary.Availability.DIGITAL_ONLY) {
                revert FGOErrors.PhysicalMintingNotAuthorized();
            }

            uint256 currentRights = physicalRights[to][childId]
                .guaranteedAmount;

            if (currentRights > type(uint256).max - amount) {
                revert FGOErrors.MaxSupplyReached();
            }
            uint256 newRightsTotal = currentRights + amount;

            if (child.physicalFulfillments > type(uint256).max - amount) {
                revert FGOErrors.MaxSupplyReached();
            }
            uint256 newFulfillments = child.physicalFulfillments + amount;

            if (
                child.maxPhysicalFulfillments > 0 &&
                newFulfillments > child.maxPhysicalFulfillments
            ) {
                revert FGOErrors.MaxSupplyReached();
            }

            physicalRights[to][childId].guaranteedAmount = newRightsTotal;
            physicalRights[to][childId].purchaseMarket = market;
            child.physicalFulfillments = newFulfillments;
        } else {
            if (child.availability == FGOLibrary.Availability.PHYSICAL_ONLY) {
                revert FGOErrors.DigitalMintingNotAuthorized();
            }

            if (_children[childId].supplyCount > type(uint256).max - amount) {
                revert FGOErrors.MaxSupplyReached();
            }

            _mint(to, childId, amount, "");
            _children[childId].supplyCount += amount;
        }
    }

    function fulfillPhysicalTokens(
        uint256 childId,
        uint256 amount,
        address buyer
    ) external {
        if (buyer == address(0)) {
            revert FGOErrors.AddressInvalid();
        }
        if (amount == 0) {
            revert FGOErrors.InvalidAmount();
        }
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }

        FGOLibrary.PhysicalRights storage rights = physicalRights[buyer][
            childId
        ];
        if (msg.sender != rights.purchaseMarket) {
            revert FGOErrors.OnlyPurchaseMarket();
        }
        if (rights.purchaseMarket == address(0)) {
            revert FGOErrors.AddressInvalid();
        }
        if (rights.guaranteedAmount < amount) {
            revert FGOErrors.InsufficientRights();
        }

        if (_children[childId].supplyCount > type(uint256).max - amount) {
            revert FGOErrors.MaxSupplyReached();
        }

        rights.guaranteedAmount -= amount;
        _mint(buyer, childId, amount, "");
        _children[childId].supplyCount += amount;
    }

    function _incrementUsageCount(uint256 childId) internal {
        _children[childId].usageCount++;
    }

    function _decrementUsageCount(uint256 childId) internal {
        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.usageCount > 0) {
            child.usageCount--;
        }
    }

    function incrementChildUsage(uint256 childId) external {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.status != FGOLibrary.ActiveStatus.ACTIVE) {
            revert FGOErrors.InvalidAmount();
        }

        _incrementUsageCount(childId);
    }

    function decrementChildUsage(uint256 childId) external {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }

        _decrementUsageCount(childId);
    }

    function _setAuthorizedMarkets(
        uint256 childId,
        address[] memory markets
    ) internal {
        uint256 length = markets.length;
        for (uint256 i = 0; i < length; ) {
            _authorizedMarkets[childId][markets[i]] = true;
            unchecked {
                ++i;
            }
        }
    }

    function _clearAuthorizedMarkets(
        uint256 childId,
        address[] memory markets
    ) internal {
        uint256 length = markets.length;
        for (uint256 i = 0; i < length; ) {
            _authorizedMarkets[childId][markets[i]] = false;
            unchecked {
                ++i;
            }
        }
    }

    function childExists(uint256 childId) public view returns (bool) {
        return _children[childId].supplier != address(0);
    }

    function isChildActive(uint256 childId) external view returns (bool) {
        if (!childExists(childId)) {
            return false;
        }
        return _children[childId].status == FGOLibrary.ActiveStatus.ACTIVE;
    }

    function deleteChild(
        uint256 childId
    ) external virtual onlyChildOwner(childId) {
        if (_children[childId].supplyCount > 0) {
            revert FGOErrors.InvalidAmount();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.usageCount > 0) {
            revert FGOErrors.InvalidAmount();
        }

        child.status = FGOLibrary.ActiveStatus.DELETED;
        emit ChildDeleted(childId);
    }

    function disableChild(uint256 childId) external onlyChildOwner(childId) {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }
        FGOLibrary.ChildMetadata storage child = _children[childId];
        child.status = FGOLibrary.ActiveStatus.DISABLED;
        emit ChildDisabled(childId);
    }

    function enableChild(uint256 childId) external onlyChildOwner(childId) {
        if (!childExists(childId)) {
            revert FGOErrors.InvalidChild();
        }
        FGOLibrary.ChildMetadata storage child = _children[childId];
        child.status = FGOLibrary.ActiveStatus.ACTIVE;
        emit ChildEnabled(childId);
    }

    function getChildMetadata(
        uint256 childId
    ) external view returns (FGOLibrary.ChildMetadata memory) {
        return _children[childId];
    }

    function createChildrenBatch(
        FGOLibrary.CreateChildParams[] memory params
    ) external virtual onlySupplier returns (uint256[] memory) {
        uint256 len = params.length;
        uint256[] memory childIds = new uint256[](len);

        for (uint256 i = 0; i < len; ) {
            childIds[i] = _createChild(params[i]);
            unchecked {
                ++i;
            }
        }

        return childIds;
    }

    function updateChildrenBatch(
        FGOLibrary.UpdateChildParams[] memory params
    ) external virtual {
        for (uint256 i = 0; i < params.length; i++) {
            if (_children[params[i].childId].supplier != msg.sender) {
                revert FGOErrors.AddressInvalid();
            }
            _updateChild(params[i]);
        }
    }

    function setAccessControl(address _accessControl) external onlyAdmin {
        accessControl = FGOAccessControl(_accessControl);
    }
}
