// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./FGOAccessControl.sol";
import "./FGOLibrary.sol";
import "./FGOErrors.sol";
import "../interfaces/IFGOContracts.sol";

abstract contract FGOBaseChild is ERC1155, ReentrancyGuard {
    uint256 internal _childSupply;
    uint256 public constant MAX_AUTHORIZED_ADDRESSES = 50;
    uint256 public childType;
    bytes32 public infraId;
    string public scm;
    string public name;
    string public symbol;
    FGOAccessControl public accessControl;

    mapping(uint256 => FGOLibrary.ChildMetadata) internal _children;
    mapping(address => mapping(uint256 => FGOLibrary.PhysicalRights))
        internal physicalRights;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256)))
        internal _authorizedParents;
    mapping(uint256 => mapping(address => bool)) internal _authorizedMarkets;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256)))
        internal _authorizedTemplates;
    mapping(uint256 => mapping(address => mapping(uint256 => FGOLibrary.ParentApprovalRequest)))
        internal _parentRequests;
    mapping(uint256 => mapping(address => FGOLibrary.ChildMarketApprovalRequest))
        internal _marketRequests;
    mapping(uint256 => mapping(address => mapping(uint256 => FGOLibrary.TemplateApprovalRequest)))
        internal _templateRequests;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256)))
        internal _activeUsageRelationships;

    event ChildCreated(uint256 indexed childId, address indexed supplier);
    event ChildUpdated(uint256 indexed childId);
    event ChildDeleted(uint256 indexed childId);
    event ChildDisabled(uint256 indexed childId);
    event ChildEnabled(uint256 indexed childId);
    event ParentApproved(
        uint256 indexed childId,
        uint256 indexed parentId,
        uint256 approvedAmount,
        address indexed parentContract
    );
    event ParentRevoked(
        uint256 indexed childId,
        uint256 indexed parentId,
        address indexed parentContract
    );
    event MarketApproved(uint256 indexed childId, address indexed market);
    event MarketRevoked(uint256 indexed childId, address indexed market);
    event ParentApprovalRequested(
        uint256 indexed childId,
        uint256 indexed parentId,
        uint256 requestedAmount,
        address indexed parentContract
    );
    event ParentApprovalRejected(
        uint256 indexed childId,
        uint256 indexed parentId,
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
        uint256 requestedAmount,
        address indexed templateContract
    );
    event TemplateApprovalRejected(
        uint256 indexed childId,
        uint256 indexed templateId,
        address indexed templateContract
    );
    event TemplateApproved(
        uint256 indexed childId,
        uint256 indexed templateId,
        uint256 approvedAmount,
        address indexed templateContract
    );
    event TemplateRevoked(
        uint256 indexed childId,
        uint256 indexed templateId,
        address indexed templateContract
    );
    event ChildMinted(
        uint256 indexed childId,
        uint256 indexed amount,
        address indexed to,
        address market,
        bool isPhysical
    );
    event ChildUsageIncremented(uint256 indexed childId, uint256 newUsageCount);
    event ChildUsageDecremented(uint256 indexed childId, uint256 newUsageCount);

    modifier onlySupplier() {
        if (!accessControl.canCreateChildren(msg.sender)) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    modifier onlyChildOwner(uint256 childId) {
        if (_children[childId].supplier != msg.sender) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    constructor(
        uint256 _childType,
        bytes32 _infraId,
        address _accessControl,
        string memory _scm,
        string memory _name,
        string memory _symbol
    ) ERC1155("") {
        accessControl = FGOAccessControl(_accessControl);
        scm = _scm;
        childType = _childType;
        infraId = _infraId;
        name = _name;
        symbol = _symbol;
    }

    function createChild(
        FGOLibrary.CreateChildParams memory params
    ) external virtual onlySupplier returns (uint256) {
        return _createChild(params);
    }

    function _createChild(
        FGOLibrary.CreateChildParams memory params
    ) internal returns (uint256) {
        _childSupply++;

        FGOLibrary.ChildMetadata storage child = _children[_childSupply];

        child.digitalPrice = params.digitalPrice;
        child.physicalPrice = params.physicalPrice;
        child.version = params.version;
        child.maxPhysicalEditions = params.maxPhysicalEditions;
        child.uriVersion = 1;
        child.isTemplate = false;
        child.supplier = msg.sender;
        child.status = FGOLibrary.Status.ACTIVE;
        child.availability = params.availability;
        child.isImmutable = params.isImmutable;
        child.digitalMarketsOpenToAll = params.digitalMarketsOpenToAll;
        child.physicalMarketsOpenToAll = params.physicalMarketsOpenToAll;
        child.digitalReferencesOpenToAll = params.digitalReferencesOpenToAll;
        child.physicalReferencesOpenToAll = params.physicalReferencesOpenToAll;
        child.standaloneAllowed = params.standaloneAllowed;
        child.uri = params.childUri;

        _setAuthorizedMarkets(_childSupply, params.authorizedMarkets);

        emit ChildCreated(_childSupply, msg.sender);

        return _childSupply;
    }

    function updateChild(
        FGOLibrary.UpdateChildParams memory params
    ) external virtual onlyChildOwner(params.childId) {
        _updateChild(params);
    }

    function _updateChild(FGOLibrary.UpdateChildParams memory params) internal {
        FGOLibrary.ChildMetadata storage child = _children[params.childId];

        child.digitalPrice = params.digitalPrice;
        child.physicalPrice = params.physicalPrice;

        if (
            params.maxPhysicalEditions > 0 &&
            params.maxPhysicalEditions < child.currentPhysicalEditions
        ) {
            revert FGOErrors.SupplyLimitTooLow();
        }

        child.maxPhysicalEditions = params.maxPhysicalEditions;
        child.digitalMarketsOpenToAll = params.digitalMarketsOpenToAll;
        child.physicalMarketsOpenToAll = params.physicalMarketsOpenToAll;

        if (!child.isImmutable) {
            child.uri = params.childUri;
            child.uriVersion++;
            child.version = params.version;
            child.availability = params.availability;
            child.standaloneAllowed = params.standaloneAllowed;
        }

        address[] memory oldMarkets = child.authorizedMarkets;
        if (params.authorizedMarkets.length >= MAX_AUTHORIZED_ADDRESSES) {
            revert FGOErrors.BatchTooLarge();
        }

        child.authorizedMarkets = params.authorizedMarkets;

        _clearAuthorizedMarkets(params.childId, oldMarkets);
        _setAuthorizedMarkets(params.childId, params.authorizedMarkets);

        if (params.makeImmutable) {
            child.isImmutable = true;
        }

        emit ChildUpdated(params.childId);
    }

    function approveParent(
        uint256 childId,
        uint256 parentId,
        uint256 approvedAmount,
        address parentContract
    ) external onlyChildOwner(childId) {
        if (!childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }
        if (approvedAmount == 0) {
            revert FGOErrors.ZeroValue();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.status != FGOLibrary.Status.ACTIVE) {
            revert FGOErrors.ChildInactive();
        }

        _authorizedParents[childId][parentContract][parentId] = approvedAmount;

        emit ParentApproved(childId, parentId, approvedAmount, parentContract);
    }

    function revokeParent(
        uint256 childId,
        uint256 parentId,
        address parentContract
    ) external onlyChildOwner(childId) {
        if (!childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        bool hadExplicitAuth = _authorizedParents[childId][parentContract][
            parentId
        ] > 0;

        if (hadExplicitAuth) {
            _authorizedParents[childId][parentContract][parentId] = 0;
        }

        _decrementChildUsage(childId, parentId, parentContract);

        emit ParentRevoked(childId, parentId, parentContract);
    }

    function approveMarket(
        uint256 childId,
        address market
    ) external onlyChildOwner(childId) {
        if (!childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.status != FGOLibrary.Status.ACTIVE) {
            revert FGOErrors.ChildInactive();
        }

        if (_authorizedMarkets[childId][market]) {
            return;
        }

        if (child.authorizedMarkets.length >= MAX_AUTHORIZED_ADDRESSES) {
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
            revert FGOErrors.ChildDoesNotExist();
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
            revert FGOErrors.ChildDoesNotExist();
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

    function requestParentApproval(
        uint256 childId,
        uint256 parentId,
        uint256 requestedAmount
    ) external virtual {
        if (!childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        FGOLibrary.ParentApprovalRequest storage request = _parentRequests[
            childId
        ][msg.sender][parentId];
        request.parentContract = msg.sender;
        request.childId = childId;
        request.parentId = parentId;
        request.requestedAmount = requestedAmount;
        request.timestamp = block.timestamp;
        request.isPending = true;

        emit ParentApprovalRequested(
            childId,
            parentId,
            requestedAmount,
            msg.sender
        );
    }

    function requestTemplateApproval(
        uint256 childId,
        uint256 templateId,
        uint256 requestedAmount
    ) external virtual {
        if (!childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        FGOLibrary.TemplateApprovalRequest storage request = _templateRequests[
            childId
        ][msg.sender][templateId];
        request.templateContract = msg.sender;
        request.childId = childId;
        request.templateId = templateId;
        request.requestedAmount = requestedAmount;
        request.timestamp = block.timestamp;
        request.isPending = true;

        emit TemplateApprovalRequested(
            childId,
            templateId,
            requestedAmount,
            msg.sender
        );
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
        if (child.authorizedMarkets.length >= MAX_AUTHORIZED_ADDRESSES) {
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
        uint256 approvedAmount,
        address parentContract
    ) external onlyChildOwner(childId) {
        FGOLibrary.ParentApprovalRequest storage request = _parentRequests[
            childId
        ][parentContract][parentId];
        if (!request.isPending) {
            revert FGOErrors.NoPendingRequest();
        }
        if (approvedAmount == 0) {
            revert FGOErrors.ZeroValue();
        }

        if (_authorizedParents[childId][parentContract][parentId] > 0) {
            request.isPending = false;
            return;
        }

        _authorizedParents[childId][parentContract][parentId] = approvedAmount;
        request.isPending = false;

        emit ParentApproved(childId, parentId, approvedAmount, parentContract);
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
        emit ParentApprovalRejected(childId, parentId, parentContract);
    }

    function approveTemplateRequest(
        uint256 childId,
        uint256 templateId,
        uint256 approvedAmount,
        address templateContract
    ) external onlyChildOwner(childId) {
        FGOLibrary.TemplateApprovalRequest storage request = _templateRequests[
            childId
        ][templateContract][templateId];
        if (!request.isPending) {
            revert FGOErrors.NoPendingRequest();
        }
        if (approvedAmount == 0) {
            revert FGOErrors.ZeroValue();
        }

        if (_authorizedTemplates[childId][templateContract][templateId] > 0) {
            request.isPending = false;
            return;
        }

        _authorizedTemplates[childId][templateContract][
            templateId
        ] = approvedAmount;
        request.isPending = false;

        emit TemplateApproved(
            childId,
            templateId,
            approvedAmount,
            templateContract
        );
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
        uint256 approvedAmount,
        address templateContract
    ) external onlyChildOwner(childId) {
        if (!childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }
        if (approvedAmount == 0) {
            revert FGOErrors.ZeroValue();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.status != FGOLibrary.Status.ACTIVE) {
            revert FGOErrors.ChildInactive();
        }

        _authorizedTemplates[childId][templateContract][
            templateId
        ] = approvedAmount;

        emit TemplateApproved(
            childId,
            templateId,
            approvedAmount,
            templateContract
        );
    }

    function revokeTemplate(
        uint256 childId,
        uint256 templateId,
        address templateContract
    ) external onlyChildOwner(childId) {
        if (!childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        bool hadExplicitAuth = _authorizedTemplates[childId][templateContract][
            templateId
        ] > 0;

        if (hadExplicitAuth) {
            _authorizedTemplates[childId][templateContract][templateId] = 0;
        }

        _decrementChildUsage(childId, templateId, templateContract);

        emit TemplateRevoked(childId, templateId, templateContract);
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
        address parentContract,
        bool isPhysical
    ) external view returns (bool) {
        FGOLibrary.ChildMetadata storage child = _children[childId];

        if (_authorizedParents[childId][parentContract][parentId] > 0) {
            return true;
        }

        if (isPhysical && child.physicalReferencesOpenToAll) {
            return true;
        }

        if (!isPhysical && child.digitalReferencesOpenToAll) {
            return true;
        }

        return false;
    }

    function getParentApprovedAmount(
        uint256 childId,
        uint256 parentId,
        address parentContract
    ) external view returns (uint256) {
        return _authorizedParents[childId][parentContract][parentId];
    }

    function approvesMarket(
        uint256 childId,
        address market,
        bool isPhysical
    ) external view returns (bool) {
        FGOLibrary.ChildMetadata storage child = _children[childId];

        if (_authorizedMarkets[childId][market]) {
            return true;
        }

        if (isPhysical && child.physicalMarketsOpenToAll) {
            return true;
        }

        if (!isPhysical && child.digitalMarketsOpenToAll) {
            return true;
        }

        return false;
    }

    function approvesTemplate(
        uint256 childId,
        uint256 templateId,
        address templateContract,
        bool isPhysical
    ) external view returns (bool) {
        FGOLibrary.ChildMetadata storage child = _children[childId];

        if (_authorizedTemplates[childId][templateContract][templateId] > 0) {
            return true;
        }

        if (isPhysical && child.physicalReferencesOpenToAll) {
            return true;
        }

        if (!isPhysical && child.digitalReferencesOpenToAll) {
            return true;
        }

        return false;
    }

    function getTemplateApprovedAmount(
        uint256 childId,
        uint256 templateId,
        address templateContract
    ) external view returns (uint256) {
        return _authorizedTemplates[childId][templateContract][templateId];
    }

    function mint(
        uint256 childId,
        uint256 amount,
        address to,
        bool isPhysical,
        bool isStandalone,
        bool reserveRights
    ) external virtual nonReentrant {
        if (to == address(0)) {
            revert FGOErrors.Unauthorized();
        }
        if (amount == 0) {
            revert FGOErrors.ZeroValue();
        }
        if (!childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.status != FGOLibrary.Status.ACTIVE) {
            revert FGOErrors.ChildInactive();
        }

        bool isAuthorizedMarket = _authorizedMarkets[childId][msg.sender];

        if (!isAuthorizedMarket) {
            if (isPhysical && child.physicalMarketsOpenToAll) {
                isAuthorizedMarket = true;
            } else if (!isPhysical && child.digitalMarketsOpenToAll) {
                isAuthorizedMarket = true;
            }
        }

        if (!isAuthorizedMarket) {
            revert FGOErrors.MarketNotAuthorized();
        }

        if (isStandalone && !child.standaloneAllowed) {
            revert FGOErrors.StandaloneNotAllowed();
        }

        if (isPhysical) {
            if (child.availability == FGOLibrary.Availability.DIGITAL_ONLY) {
                return;
            }

            uint256 currentRights = physicalRights[to][childId]
                .guaranteedAmount;

            if (currentRights > type(uint256).max - amount) {
                revert FGOErrors.MaxSupplyReached();
            }
            uint256 newRightsTotal = currentRights + amount;

            if (child.currentPhysicalEditions > type(uint256).max - amount) {
                revert FGOErrors.MaxSupplyReached();
            }
            uint256 newFulfillments = child.currentPhysicalEditions + amount;

            if (
                child.maxPhysicalEditions > 0 &&
                newFulfillments > child.maxPhysicalEditions
            ) {
                revert FGOErrors.MaxSupplyReached();
            }

            child.currentPhysicalEditions = newFulfillments;

            if (!reserveRights) {
                if (
                    _children[childId].supplyCount > type(uint256).max - amount
                ) {
                    revert FGOErrors.MaxSupplyReached();
                }
                _mint(to, childId, amount, "");
                _children[childId].supplyCount += amount;
            } else {
                physicalRights[to][childId].guaranteedAmount = newRightsTotal;
                physicalRights[to][childId].purchaseMarket = msg.sender;
            }
        } else {
            if (child.availability == FGOLibrary.Availability.PHYSICAL_ONLY) {
                return;
            }

            if (_children[childId].supplyCount > type(uint256).max - amount) {
                revert FGOErrors.MaxSupplyReached();
            }

            _mint(to, childId, amount, "");
            _children[childId].supplyCount += amount;
        }

        emit ChildMinted(childId, amount, to, msg.sender, isPhysical);
    }

    function fulfillPhysicalTokens(
        uint256 childId,
        uint256 amount,
        address buyer
    ) external {
        if (buyer == address(0)) {
            revert FGOErrors.Unauthorized();
        }
        if (amount == 0) {
            revert FGOErrors.ZeroValue();
        }
        if (!childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        FGOLibrary.PhysicalRights storage rights = physicalRights[buyer][
            childId
        ];

        if (IFGOMarket(rights.purchaseMarket).fulfillment() != msg.sender) {
            revert FGOErrors.Unauthorized();
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

    function incrementChildUsage(
        uint256 childId,
        uint256 entityId,
        uint256 amount,
        bool isTemplate
    ) external {
        if (!childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        if (isTemplate) {
            FGOLibrary.ChildMetadata memory metadata = IFGOChild(msg.sender)
                .getChildMetadata(entityId);
            if (metadata.status != FGOLibrary.Status.ACTIVE) {
                revert FGOErrors.Unauthorized();
            }
        } else {
            FGOLibrary.ParentMetadata memory metadata = IFGOParent(msg.sender)
                .getDesignTemplate(entityId);

            if (metadata.status != FGOLibrary.Status.ACTIVE) {
                revert FGOErrors.Unauthorized();
            }
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];

        bool isAuthorized = false;
        if (_authorizedParents[childId][msg.sender][entityId] > 0) {
            isAuthorized = true;
        } else if (_authorizedTemplates[childId][msg.sender][entityId] > 0) {
            isAuthorized = true;
        } else {
            bool canAutoApprove = false;
            if (child.availability == FGOLibrary.Availability.DIGITAL_ONLY) {
                canAutoApprove = child.digitalReferencesOpenToAll;
            } else if (
                child.availability == FGOLibrary.Availability.PHYSICAL_ONLY
            ) {
                canAutoApprove = child.physicalReferencesOpenToAll;
            } else {
                canAutoApprove =
                    child.digitalReferencesOpenToAll &&
                    child.physicalReferencesOpenToAll;
            }
            isAuthorized = canAutoApprove;
        }

        if (!isAuthorized) {
            revert FGOErrors.Unauthorized();
        }

        _activeUsageRelationships[childId][msg.sender][entityId] += amount;
        child.usageCount += amount;
        emit ChildUsageIncremented(childId, child.usageCount);
    }

    function decrementChildUsage(uint256 childId, uint256 entityId) external {
        _decrementChildUsage(childId, entityId, msg.sender);
    }

    function _decrementChildUsage(
        uint256 childId,
        uint256 entityId,
        address contractAddress
    ) internal {
        if (!childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

      
        uint256 activeAmount = _activeUsageRelationships[childId][
            contractAddress
        ][entityId];
        if (activeAmount == 0) {
            revert FGOErrors.Unauthorized();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];

        _activeUsageRelationships[childId][contractAddress][entityId] = 0;
        if (child.usageCount >= activeAmount) {
            child.usageCount -= activeAmount;
            emit ChildUsageDecremented(childId, child.usageCount);
        }
    }

    function _setAuthorizedMarkets(
        uint256 childId,
        address[] memory markets
    ) internal {
        uint256 length = markets.length;
        if (length > MAX_AUTHORIZED_ADDRESSES) {
            revert FGOErrors.BatchTooLarge();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];

        for (uint256 i = 0; i < length; ) {
            _authorizedMarkets[childId][markets[i]] = true;
            child.authorizedMarkets.push(markets[i]);
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
        return _children[childId].status == FGOLibrary.Status.ACTIVE;
    }

    function deleteChild(
        uint256 childId
    ) external virtual onlyChildOwner(childId) {
        if (_children[childId].supplyCount > 0) {
            revert FGOErrors.HasSupply();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.usageCount > 0) {
            revert FGOErrors.HasUsage();
        }

        address[] memory authorizedMarkets = child.authorizedMarkets;
        uint256 marketsLength = authorizedMarkets.length;
        for (uint256 i = 0; i < marketsLength; ) {
            delete _authorizedMarkets[childId][authorizedMarkets[i]];
            delete _marketRequests[childId][authorizedMarkets[i]];
            unchecked {
                ++i;
            }
        }

        delete _children[childId];
        emit ChildDeleted(childId);
    }

    function disableChild(uint256 childId) external onlyChildOwner(childId) {
        if (!childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }
        FGOLibrary.ChildMetadata storage child = _children[childId];
        child.status = FGOLibrary.Status.DISABLED;
        emit ChildDisabled(childId);
    }

    function enableChild(uint256 childId) external onlyChildOwner(childId) {
        if (!childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }
        FGOLibrary.ChildMetadata storage child = _children[childId];
        child.status = FGOLibrary.Status.ACTIVE;
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
        if (len == 0 || len > 20) {
            revert FGOErrors.BatchTooLarge();
        }
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
        uint256 length = params.length;
        if (length == 0 || length > 20) {
            revert FGOErrors.BatchTooLarge();
        }
        for (uint256 i = 0; i < length; ) {
            if (_children[params[i].childId].supplier != msg.sender) {
                revert FGOErrors.Unauthorized();
            }
            _updateChild(params[i]);
            unchecked {
                ++i;
            }
        }
    }

    function setAccessControl(address _accessControl) external onlyAdmin {
        accessControl = FGOAccessControl(_accessControl);
    }

    function getStandaloneAllowed(
        uint256 childId
    ) external view returns (bool) {
        return _children[childId].standaloneAllowed;
    }

    function getPhysicalRights(
        address buyer,
        uint256 childId
    ) external view returns (uint256 guaranteedAmount, address purchaseMarket) {
        FGOLibrary.PhysicalRights storage rights = physicalRights[buyer][
            childId
        ];
        return (rights.guaranteedAmount, rights.purchaseMarket);
    }

    function canPurchase(
        uint256 childId,
        uint256 amount,
        bool isPhysical,
        address market
    ) external view virtual returns (bool) {
        FGOLibrary.ChildMetadata storage child = _children[childId];

        if (child.status != FGOLibrary.Status.ACTIVE) {
            return false;
        }

        if (!child.standaloneAllowed) {
            return false;
        }

        bool childApproves = _authorizedMarkets[childId][market];

        if (!childApproves) {
            if (isPhysical && child.physicalMarketsOpenToAll) {
                childApproves = true;
            } else if (!isPhysical && child.digitalMarketsOpenToAll) {
                childApproves = true;
            }
        }

        if (!childApproves) {
            return false;
        }

        if (
            isPhysical &&
            child.availability == FGOLibrary.Availability.DIGITAL_ONLY
        ) {
            return false;
        }
        if (
            !isPhysical &&
            child.availability == FGOLibrary.Availability.PHYSICAL_ONLY
        ) {
            return false;
        }

        if (isPhysical) {
            if (
                child.maxPhysicalEditions > 0 &&
                child.currentPhysicalEditions + amount >
                child.maxPhysicalEditions
            ) {
                return false;
            }
        }

        return true;
    }
}
