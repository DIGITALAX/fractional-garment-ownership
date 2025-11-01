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
    address public supplyCoordination;
    address public futuresCoordination;
    address public factory;
    FGOAccessControl public accessControl;

    mapping(uint256 => FGOLibrary.ChildMetadata) internal _children;
    mapping(address => mapping(uint256 => mapping(uint256 => mapping(address => FGOLibrary.PhysicalRights))))
        internal _physicalRights;
    mapping(uint256 => mapping(uint256 => mapping(address => address[])))
        internal _physicalRightsHolders;
    mapping(uint256 => mapping(uint256 => mapping(address => mapping(address => bool))))
        internal _isPhysicalRightsHolder;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256)))
        internal _authorizedParentsPhysical;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256)))
        internal _authorizedParentsDigital;
    mapping(uint256 => mapping(address => uint256)) internal _authorizedMarkets;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256)))
        internal _authorizedTemplatesPhysical;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256)))
        internal _authorizedTemplatesDigital;
    mapping(uint256 => mapping(address => mapping(uint256 => mapping(bool => FGOLibrary.ParentApprovalRequest))))
        internal _parentRequests;
    mapping(uint256 => mapping(address => FGOLibrary.ChildMarketApprovalRequest))
        internal _marketRequests;
    mapping(uint256 => mapping(address => mapping(uint256 => mapping(bool => FGOLibrary.TemplateApprovalRequest))))
        internal _templateRequests;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256)))
        internal _activeUsageRelationships;
    mapping(uint256 => mapping(bytes32 => uint256))
        private _reservedSupplyByRequest;

    event ChildCreated(uint256 indexed childId, address indexed supplier);
    event SupplyReserved(
        uint256 indexed childId,
        bytes32 indexed requestId,
        uint256 amount
    );
    event SupplyReservationReleased(
        uint256 indexed childId,
        bytes32 indexed requestId,
        uint256 amount
    );
    event ChildUpdated(uint256 indexed childId);
    event ChildDeleted(uint256 indexed childId);
    event ChildDisabled(uint256 indexed childId);
    event ChildEnabled(uint256 indexed childId);
    event ParentApproved(
        uint256 indexed childId,
        uint256 indexed parentId,
        uint256 approvedAmount,
        address indexed parentContract,
        bool isPhysical
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
        address indexed parentContract,
        bool isPhysical
    );
    event ParentApprovalRejected(
        uint256 indexed childId,
        uint256 indexed parentId,
        address indexed parentContract,
        bool isPhysical
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
        address indexed templateContract,
        bool isPhysical
    );
    event TemplateApprovalRejected(
        uint256 indexed childId,
        uint256 indexed templateId,
        address indexed templateContract,
        bool isPhysical
    );
    event TemplateApproved(
        uint256 indexed childId,
        uint256 indexed templateId,
        uint256 approvedAmount,
        address indexed templateContract,
        bool isPhysical
    );
    event TemplateRevoked(
        uint256 indexed childId,
        uint256 indexed templateId,
        address indexed templateContract
    );
    event ChildMinted(
        uint256 indexed childId,
        uint256 indexed orderId,
        uint256 indexed amount,
        address to,
        address market,
        bool isPhysical
    );
    event ChildUsageIncremented(uint256 indexed childId, uint256 newUsageCount);
    event ChildUsageDecremented(uint256 indexed childId, uint256 newUsageCount);
    event PhysicalRightsTransferred(
        uint256 childId,
        uint256 orderId,
        uint256 amount,
        address sender,
        address receiver,
        address market
    );

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

    modifier onlySupplyCoordination() {
        if (
            msg.sender != supplyCoordination &&
            !IFGOFactory(factory).isValidParent(msg.sender)
        ) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    modifier onlyFuturesCoordination() {
        if (msg.sender != futuresCoordination) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    constructor(
        uint256 _childType,
        bytes32 _infraId,
        address _accessControl,
        address _supplyCoordination,
        address _futuresCoordination,
        address _factory,
        string memory _scm,
        string memory _name,
        string memory _symbol
    ) ERC1155("") {
        accessControl = FGOAccessControl(_accessControl);
        futuresCoordination = _futuresCoordination;
        supplyCoordination = _supplyCoordination;
        factory = _factory;
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

        if (
            params.availability == FGOLibrary.Availability.DIGITAL_ONLY ||
            params.availability == FGOLibrary.Availability.BOTH
        ) {
            child.digitalPrice = params.digitalPrice;
        }

        if (
            params.availability == FGOLibrary.Availability.PHYSICAL_ONLY ||
            params.availability == FGOLibrary.Availability.BOTH
        ) {
            child.physicalPrice = params.physicalPrice;
            child.maxPhysicalEditions = params.maxPhysicalEditions;
        }

        child.digitalMarketsOpenToAll = params.digitalMarketsOpenToAll;
        child.physicalMarketsOpenToAll = params.physicalMarketsOpenToAll;

        child.digitalReferencesOpenToAll = params.digitalReferencesOpenToAll;
        child.physicalReferencesOpenToAll = params.physicalReferencesOpenToAll;

        child.version = params.version;

        child.uriVersion = 1;
        child.isTemplate = false;
        child.supplier = msg.sender;
        child.status = FGOLibrary.Status.ACTIVE;
        child.availability = params.availability;
        child.isImmutable = params.isImmutable;
        child.standaloneAllowed = params.standaloneAllowed;
        child.uri = params.childUri;
        child.futures = params.futures;

        if (params.futures.isFutures) {
            if (params.availability == FGOLibrary.Availability.BOTH) {
                revert FGOErrors.InvalidAvailability();
            }

            uint256 amount = 0;
            uint256 pricePerUnit = 0;
            if (params.availability == FGOLibrary.Availability.PHYSICAL_ONLY) {
                if (
                    child.maxPhysicalEditions == 0 || child.physicalPrice == 0
                ) {
                    revert FGOErrors.ZeroValue();
                }
                amount = child.maxPhysicalEditions;
                pricePerUnit = child.physicalPrice;
            } else {
                if (
                    child.futures.maxDigitalEditions == 0 ||
                    child.digitalPrice == 0
                ) {
                    revert FGOErrors.ZeroValue();
                }
                amount = child.futures.maxDigitalEditions;
                pricePerUnit = child.digitalPrice;
            }

            IFGOFuturesCoordination(futuresCoordination).createFuturesPosition(
                msg.sender,
                _childSupply,
                amount,
                pricePerUnit,
                child.futures.deadline,
                child.futures.settlementRewardBPS
            );
        }

        _setAuthorizedMarkets(_childSupply, params.authorizedMarkets);

        emit ChildCreated(_childSupply, msg.sender);
        emit URI(params.childUri, _childSupply);

        return _childSupply;
    }

    function updateChild(
        FGOLibrary.UpdateChildParams memory params
    ) external virtual onlyChildOwner(params.childId) {
        _updateChild(params);
    }

    function _updateChild(FGOLibrary.UpdateChildParams memory params) internal {
        FGOLibrary.ChildMetadata storage child = _children[params.childId];

        if (child.futures.isFutures) {
            revert FGOErrors.Unauthorized();
        }

        if (
            child.availability == FGOLibrary.Availability.PHYSICAL_ONLY ||
            child.availability == FGOLibrary.Availability.BOTH
        ) {
            if (
                params.maxPhysicalEditions > 0 &&
                params.maxPhysicalEditions < child.currentPhysicalEditions
            ) {
                revert FGOErrors.SupplyLimitTooLow();
            }

            child.maxPhysicalEditions = params.maxPhysicalEditions;
            child.physicalPrice = params.physicalPrice;
        }

        if (
            child.availability == FGOLibrary.Availability.DIGITAL_ONLY ||
            child.availability == FGOLibrary.Availability.BOTH
        ) {
            child.digitalPrice = params.digitalPrice;
        }

        if (!child.isImmutable) {
            child.uri = params.childUri;
            child.uriVersion++;
            child.version = params.version;
            child.standaloneAllowed = params.standaloneAllowed;
            emit URI(params.childUri, params.childId);
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
        address parentContract,
        bool isPhysical
    ) external {
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        if (
            msg.sender != _children[childId].supplier &&
            msg.sender != address(supplyCoordination)
        ) {
            revert FGOErrors.Unauthorized();
        }

        if (approvedAmount == 0) {
            revert FGOErrors.ZeroValue();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.status != FGOLibrary.Status.ACTIVE) {
            revert FGOErrors.ChildInactive();
        }

        if (isPhysical) {
            _authorizedParentsPhysical[childId][parentContract][
                parentId
            ] = approvedAmount;
        } else {
            _authorizedParentsDigital[childId][parentContract][
                parentId
            ] = approvedAmount;
        }

        emit ParentApproved(
            childId,
            parentId,
            approvedAmount,
            parentContract,
            isPhysical
        );
    }

    function revokeParent(
        uint256 childId,
        uint256 parentId,
        address parentContract
    ) external onlyChildOwner(childId) {
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        bool hadExplicitAuth = _authorizedParentsPhysical[childId][
            parentContract
        ][parentId] >
            0 ||
            _authorizedParentsDigital[childId][parentContract][parentId] > 0;

        if (hadExplicitAuth) {
            _authorizedParentsPhysical[childId][parentContract][parentId] = 0;
            _authorizedParentsDigital[childId][parentContract][parentId] = 0;
        }

        _decrementChildUsage(childId, parentId, parentContract);

        emit ParentRevoked(childId, parentId, parentContract);
    }

    function approveMarket(
        uint256 childId,
        address market
    ) external onlyChildOwner(childId) {
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.status != FGOLibrary.Status.ACTIVE) {
            revert FGOErrors.ChildInactive();
        }

        if (_authorizedMarkets[childId][market] > 0) {
            return;
        }

        if (child.authorizedMarkets.length >= MAX_AUTHORIZED_ADDRESSES) {
            revert FGOErrors.BatchTooLarge();
        }

        _authorizedMarkets[childId][market] = 1;
        child.authorizedMarkets.push(market);

        emit MarketApproved(childId, market);
    }

    function revokeMarket(
        uint256 childId,
        address market
    ) external onlyChildOwner(childId) {
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        if (_authorizedMarkets[childId][market] == 0) {
            return;
        }

        _authorizedMarkets[childId][market] = 0;

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
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        FGOLibrary.ChildMarketApprovalRequest storage request = _marketRequests[
            childId
        ][msg.sender];

        if (_authorizedMarkets[childId][msg.sender] > 0 || request.isPending) {
            return;
        }

        request.market = msg.sender;
        request.childId = childId;
        request.timestamp = block.timestamp;
        request.isPending = true;

        emit MarketApprovalRequested(childId, msg.sender);
    }

    function requestParentApproval(
        uint256 childId,
        uint256 parentId,
        uint256 requestedAmount,
        bool isPhysical
    ) external virtual {
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.futures.isFutures) {
            revert FGOErrors.Unauthorized();
        }

        FGOLibrary.ParentApprovalRequest storage request = _parentRequests[
            childId
        ][msg.sender][parentId][isPhysical];

        uint256 existingApproval = isPhysical
            ? _authorizedParentsPhysical[childId][msg.sender][parentId]
            : _authorizedParentsDigital[childId][msg.sender][parentId];

        if (existingApproval > 0 || request.isPending) {
            return;
        }

        request.parentContract = msg.sender;
        request.childId = childId;
        request.parentId = parentId;
        request.requestedAmount = requestedAmount;
        request.timestamp = block.timestamp;
        request.isPending = true;
        request.isPhysical = isPhysical;

        emit ParentApprovalRequested(
            childId,
            parentId,
            requestedAmount,
            msg.sender,
            isPhysical
        );
    }

    function requestTemplateApproval(
        uint256 childId,
        uint256 templateId,
        uint256 requestedAmount,
        bool isPhysical
    ) external virtual {
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.futures.isFutures) {
            revert FGOErrors.Unauthorized();
        }

        FGOLibrary.TemplateApprovalRequest storage request = _templateRequests[
            childId
        ][msg.sender][templateId][isPhysical];

        uint256 existingApproval = isPhysical
            ? _authorizedTemplatesPhysical[childId][msg.sender][templateId]
            : _authorizedTemplatesDigital[childId][msg.sender][templateId];

        if (existingApproval > 0 || request.isPending) {
            return;
        }

        request.templateContract = msg.sender;
        request.childId = childId;
        request.templateId = templateId;
        request.requestedAmount = requestedAmount;
        request.timestamp = block.timestamp;
        request.isPending = true;
        request.isPhysical = isPhysical;

        emit TemplateApprovalRequested(
            childId,
            templateId,
            requestedAmount,
            msg.sender,
            isPhysical
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

        if (_authorizedMarkets[childId][market] > 0) {
            request.isPending = false;
            return;
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.authorizedMarkets.length >= MAX_AUTHORIZED_ADDRESSES) {
            revert FGOErrors.BatchTooLarge();
        }

        _authorizedMarkets[childId][market] = 1;
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
        address parentContract,
        bool isPhysical
    ) external onlyChildOwner(childId) {
        FGOLibrary.ParentApprovalRequest storage request = _parentRequests[
            childId
        ][parentContract][parentId][isPhysical];
        if (!request.isPending) {
            revert FGOErrors.NoPendingRequest();
        }
        if (approvedAmount == 0) {
            revert FGOErrors.ZeroValue();
        }

        bool alreadyApproved = isPhysical
            ? _authorizedParentsPhysical[childId][parentContract][parentId] > 0
            : _authorizedParentsDigital[childId][parentContract][parentId] > 0;

        if (alreadyApproved) {
            request.isPending = false;
            return;
        }

        if (isPhysical) {
            _authorizedParentsPhysical[childId][parentContract][
                parentId
            ] = approvedAmount;
        } else {
            _authorizedParentsDigital[childId][parentContract][
                parentId
            ] = approvedAmount;
        }
        request.isPending = false;

        emit ParentApproved(
            childId,
            parentId,
            approvedAmount,
            parentContract,
            isPhysical
        );
    }

    function rejectParentRequest(
        uint256 childId,
        uint256 parentId,
        address parentContract,
        bool isPhysical
    ) external onlyChildOwner(childId) {
        FGOLibrary.ParentApprovalRequest storage request = _parentRequests[
            childId
        ][parentContract][parentId][isPhysical];
        if (!request.isPending) {
            revert FGOErrors.NoPendingRequest();
        }

        request.isPending = false;
        emit ParentApprovalRejected(
            childId,
            parentId,
            parentContract,
            isPhysical
        );
    }

    function approveTemplateRequest(
        uint256 childId,
        uint256 templateId,
        uint256 approvedAmount,
        address templateContract,
        bool isPhysical
    ) external onlyChildOwner(childId) {
        FGOLibrary.TemplateApprovalRequest storage request = _templateRequests[
            childId
        ][templateContract][templateId][isPhysical];
        if (!request.isPending) {
            revert FGOErrors.NoPendingRequest();
        }
        if (approvedAmount == 0) {
            revert FGOErrors.ZeroValue();
        }

        bool alreadyApproved = isPhysical
            ? _authorizedTemplatesPhysical[childId][templateContract][
                templateId
            ] > 0
            : _authorizedTemplatesDigital[childId][templateContract][
                templateId
            ] > 0;

        if (alreadyApproved) {
            request.isPending = false;
            return;
        }

        if (isPhysical) {
            _authorizedTemplatesPhysical[childId][templateContract][
                templateId
            ] = approvedAmount;
        } else {
            _authorizedTemplatesDigital[childId][templateContract][
                templateId
            ] = approvedAmount;
        }
        request.isPending = false;

        emit TemplateApproved(
            childId,
            templateId,
            approvedAmount,
            templateContract,
            isPhysical
        );
    }

    function rejectTemplateRequest(
        uint256 childId,
        uint256 templateId,
        address templateContract,
        bool isPhysical
    ) external onlyChildOwner(childId) {
        FGOLibrary.TemplateApprovalRequest storage request = _templateRequests[
            childId
        ][templateContract][templateId][isPhysical];
        if (!request.isPending) {
            revert FGOErrors.NoPendingRequest();
        }

        request.isPending = false;
        emit TemplateApprovalRejected(
            childId,
            templateId,
            templateContract,
            isPhysical
        );
    }

    function approveTemplate(
        uint256 childId,
        uint256 templateId,
        uint256 approvedAmount,
        address templateContract,
        bool isPhysical
    ) external onlyChildOwner(childId) {
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }
        if (approvedAmount == 0) {
            revert FGOErrors.ZeroValue();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.status != FGOLibrary.Status.ACTIVE) {
            revert FGOErrors.ChildInactive();
        }

        if (isPhysical) {
            _authorizedTemplatesPhysical[childId][templateContract][
                templateId
            ] = approvedAmount;
        } else {
            _authorizedTemplatesDigital[childId][templateContract][
                templateId
            ] = approvedAmount;
        }

        emit TemplateApproved(
            childId,
            templateId,
            approvedAmount,
            templateContract,
            isPhysical
        );
    }

    function revokeTemplate(
        uint256 childId,
        uint256 templateId,
        address templateContract
    ) external onlyChildOwner(childId) {
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        bool hadExplicitAuth = _authorizedTemplatesPhysical[childId][
            templateContract
        ][templateId] >
            0 ||
            _authorizedTemplatesDigital[childId][templateContract][templateId] >
            0;

        if (hadExplicitAuth) {
            _authorizedTemplatesPhysical[childId][templateContract][
                templateId
            ] = 0;
            _authorizedTemplatesDigital[childId][templateContract][
                templateId
            ] = 0;
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
        address parentContract,
        bool isPhysical
    ) external view returns (FGOLibrary.ParentApprovalRequest memory) {
        return _parentRequests[childId][parentContract][parentId][isPhysical];
    }

    function getTemplateRequest(
        uint256 childId,
        uint256 templateId,
        address templateContract,
        bool isPhysical
    ) external view returns (FGOLibrary.TemplateApprovalRequest memory) {
        return
            _templateRequests[childId][templateContract][templateId][
                isPhysical
            ];
    }

    function approvesParent(
        uint256 childId,
        uint256 parentId,
        address parentContract,
        bool isPhysical
    ) external view returns (bool) {
        FGOLibrary.ChildMetadata storage child = _children[childId];

        uint256 approved = isPhysical
            ? _authorizedParentsPhysical[childId][parentContract][parentId]
            : _authorizedParentsDigital[childId][parentContract][parentId];

        if (approved > 0) {
            return true;
        }

        if (isPhysical && child.physicalReferencesOpenToAll) {
            return true;
        }

        if (!isPhysical && child.digitalReferencesOpenToAll) {
            return true;
        }

        if (child.futures.isFutures) {
            return true;
        }

        return false;
    }

    function getParentApprovedAmount(
        uint256 childId,
        uint256 parentId,
        address parentContract,
        bool isPhysical
    ) external view returns (uint256) {
        return
            isPhysical
                ? _authorizedParentsPhysical[childId][parentContract][parentId]
                : _authorizedParentsDigital[childId][parentContract][parentId];
    }

    function approvesMarket(
        uint256 childId,
        address market,
        bool isPhysical
    ) external view returns (bool) {
        FGOLibrary.ChildMetadata storage child = _children[childId];

        if (_authorizedMarkets[childId][market] > 0) {
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

        uint256 approved = isPhysical
            ? _authorizedTemplatesPhysical[childId][templateContract][
                templateId
            ]
            : _authorizedTemplatesDigital[childId][templateContract][
                templateId
            ];

        if (approved > 0) {
            return true;
        }

        if (isPhysical && child.physicalReferencesOpenToAll) {
            return true;
        }

        if (!isPhysical && child.digitalReferencesOpenToAll) {
            return true;
        }

        if (child.futures.isFutures) {
            return true;
        }

        return false;
    }

    function getTemplateApprovedAmount(
        uint256 childId,
        uint256 templateId,
        address templateContract,
        bool isPhysical
    ) external view returns (uint256) {
        return
            isPhysical
                ? _authorizedTemplatesPhysical[childId][templateContract][
                    templateId
                ]
                : _authorizedTemplatesDigital[childId][templateContract][
                    templateId
                ];
    }

    function mint(
        uint256 childId,
        uint256 amount,
        uint256 orderId,
        uint256 estimatedDeliveryDuration,
        address to,
        bool isPhysical,
        bool isStandalone,
        bool reserveRights,
        uint256 prepaidAvailable
    ) external virtual nonReentrant {
        if (to == address(0)) {
            revert FGOErrors.Unauthorized();
        }
        if (amount == 0) {
            revert FGOErrors.ZeroValue();
        }
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];
        if (child.status != FGOLibrary.Status.ACTIVE) {
            revert FGOErrors.ChildInactive();
        }

        bool isAuthorizedMarket = _authorizedMarkets[childId][msg.sender] > 0;

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

            uint256 currentRights = _physicalRights[to][childId][orderId][
                msg.sender
            ].guaranteedAmount;

            if (currentRights > type(uint256).max - amount) {
                revert FGOErrors.MaxSupplyReached();
            }
            uint256 newRightsTotal = currentRights + amount;

            uint256 prepaidUsed = prepaidAvailable > amount
                ? amount
                : prepaidAvailable;
            uint256 nonPrepaidAmount = amount - prepaidUsed;

            if (
                child.currentPhysicalEditions >
                type(uint256).max - nonPrepaidAmount
            ) {
                revert FGOErrors.MaxSupplyReached();
            }
            uint256 newFulfillments = child.currentPhysicalEditions +
                nonPrepaidAmount;

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
                _physicalRights[to][childId][orderId][msg.sender]
                    .guaranteedAmount = newRightsTotal;
                _physicalRights[to][childId][orderId][msg.sender]
                    .purchaseMarket = msg.sender;
                _physicalRights[to][childId][orderId][msg.sender]
                    .estimatedDeliveryDuration = estimatedDeliveryDuration;

                if (
                    !_isPhysicalRightsHolder[childId][orderId][msg.sender][to]
                ) {
                    _physicalRightsHolders[childId][orderId][msg.sender].push(
                        to
                    );
                    _isPhysicalRightsHolder[childId][orderId][msg.sender][
                        to
                    ] = true;
                }
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

        emit ChildMinted(childId, orderId, amount, to, msg.sender, isPhysical);
    }

    function fulfillPhysicalTokens(
        uint256 childId,
        uint256 orderId,
        uint256 amount,
        address buyer,
        address marketContract
    ) external {
        if (buyer == address(0)) {
            revert FGOErrors.Unauthorized();
        }
        if (amount == 0) {
            revert FGOErrors.ZeroValue();
        }
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        FGOLibrary.PhysicalRights storage rights = _physicalRights[buyer][
            childId
        ][orderId][marketContract];

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

        if (rights.guaranteedAmount == 0) {
            _removePhysicalRightsHolder(
                childId,
                orderId,
                buyer,
                marketContract
            );
        }
    }

    function incrementChildUsage(
        uint256 childId,
        uint256 entityId,
        uint256 amount,
        uint256 maxPhysicalEditions,
        uint256 maxDigitalEditions,
        bool isTemplate
    ) external {
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        if (isTemplate) {
            if (!IFGOFactory(factory).isValidChild(msg.sender)) {
                revert FGOErrors.Unauthorized();
            }
            FGOLibrary.ChildMetadata memory metadata = IFGOChild(msg.sender)
                .getChildMetadata(entityId);
            if (metadata.status != FGOLibrary.Status.ACTIVE) {
                revert FGOErrors.Unauthorized();
            }
        } else {
            if (!IFGOFactory(factory).isValidParent(msg.sender)) {
                revert FGOErrors.Unauthorized();
            }
            FGOLibrary.ParentMetadata memory metadata = IFGOParent(msg.sender)
                .getDesignTemplate(entityId);

            if (metadata.status != FGOLibrary.Status.ACTIVE) {
                revert FGOErrors.Unauthorized();
            }
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];

        bool isAuthorized = false;

        if (child.futures.isFutures) {
            isAuthorized = true;
        } else if (
            _authorizedParentsPhysical[childId][msg.sender][entityId] > 0 ||
            _authorizedParentsDigital[childId][msg.sender][entityId] > 0
        ) {
            isAuthorized = true;
        } else if (
            _authorizedTemplatesPhysical[childId][msg.sender][entityId] > 0 ||
            _authorizedTemplatesDigital[childId][msg.sender][entityId] > 0
        ) {
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

        uint256 reservation;
        if (child.availability == FGOLibrary.Availability.DIGITAL_ONLY) {
            reservation = maxDigitalEditions > 0
                ? amount * maxDigitalEditions
                : type(uint256).max;
        } else if (
            child.availability == FGOLibrary.Availability.PHYSICAL_ONLY
        ) {
            reservation = maxPhysicalEditions > 0
                ? amount * maxPhysicalEditions
                : type(uint256).max;
        } else {
            reservation = maxPhysicalEditions > 0
                ? amount * maxPhysicalEditions
                : type(uint256).max;
        }

        _activeUsageRelationships[childId][msg.sender][entityId] += reservation;
        child.usageCount += reservation;
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
        if (!_childExists(childId)) {
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
            _authorizedMarkets[childId][markets[i]] = 1;
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
            _authorizedMarkets[childId][markets[i]] = 0;
            unchecked {
                ++i;
            }
        }
    }

    function childExists(uint256 childId) external view returns (bool) {
        return _childExists(childId);
    }

    function _childExists(uint256 childId) internal view returns (bool) {
        return _children[childId].supplier != address(0);
    }

    function isChildActive(uint256 childId) external view returns (bool) {
        if (!_childExists(childId)) {
            return false;
        }
        FGOLibrary.Status status = _children[childId].status;
        return status == FGOLibrary.Status.ACTIVE;
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
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }
        FGOLibrary.ChildMetadata storage child = _children[childId];

        if (
            child.totalReservedSupply > 0 ||
            child.totalPrepaidUsed < child.totalPrepaidAmount
        ) {
            revert FGOErrors.Unauthorized();
        }

        child.status = FGOLibrary.Status.DISABLED;
        emit ChildDisabled(childId);
    }

    function enableChild(uint256 childId) external onlyChildOwner(childId) {
        if (!_childExists(childId)) {
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

    function setSupplyCoordination(
        address _supplyCoordination
    ) external onlyAdmin {
        supplyCoordination = _supplyCoordination;
    }

    function setFuturesCoordination(
        address _futuresCoordination
    ) external onlyAdmin {
        futuresCoordination = _futuresCoordination;
    }

    function incrementTotalPrepaidAmount(
        uint256 childId,
        uint256 amount
    ) external onlySupplyCoordination {
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }
        _children[childId].totalPrepaidAmount += amount;
    }

    function incrementTotalPrepaidUsed(
        uint256 childId,
        uint256 amount
    ) external {
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }
        if (!IFGOFactory(factory).isValidParent(msg.sender)) {
            revert FGOErrors.Unauthorized();
        }
        _children[childId].totalPrepaidUsed += amount;
    }

    function getStandaloneAllowed(
        uint256 childId
    ) external view returns (bool) {
        return _children[childId].standaloneAllowed;
    }

    function getPhysicalRights(
        uint256 childId,
        uint256 orderId,
        address buyer,
        address marketContract
    ) external view returns (FGOLibrary.PhysicalRights memory) {
        return _physicalRights[buyer][childId][orderId][marketContract];
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

        bool childApproves = _authorizedMarkets[childId][market] > 0;

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

    function transferPhysicalRights(
        uint256 childId,
        uint256 orderId,
        uint256 amount,
        address to,
        address marketContract
    ) external {
        FGOLibrary.PhysicalRights storage senderRights = _physicalRights[
            msg.sender
        ][childId][orderId][marketContract];
        FGOLibrary.PhysicalRights storage receiverRights = _physicalRights[to][
            childId
        ][orderId][marketContract];
        if (senderRights.guaranteedAmount < amount) {
            revert FGOErrors.NoPhysicalRights();
        }

        senderRights.guaranteedAmount -= amount;
        receiverRights.guaranteedAmount += amount;

        if (receiverRights.purchaseMarket == address(0)) {
            receiverRights.purchaseMarket = senderRights.purchaseMarket;
        }

        if (!_isPhysicalRightsHolder[childId][orderId][marketContract][to]) {
            _physicalRightsHolders[childId][orderId][marketContract].push(to);
            _isPhysicalRightsHolder[childId][orderId][marketContract][
                to
            ] = true;
        }

        if (senderRights.guaranteedAmount == 0) {
            _removePhysicalRightsHolder(
                childId,
                orderId,
                msg.sender,
                marketContract
            );
        }

        emit PhysicalRightsTransferred(
            childId,
            orderId,
            amount,
            msg.sender,
            to,
            marketContract
        );
    }

    function _removePhysicalRightsHolder(
        uint256 childId,
        uint256 orderId,
        address holder,
        address marketContract
    ) internal {
        _isPhysicalRightsHolder[childId][orderId][marketContract][
            holder
        ] = false;
        address[] storage holders = _physicalRightsHolders[childId][orderId][
            marketContract
        ];
        for (uint256 i = 0; i < holders.length; ) {
            if (holders[i] == holder) {
                holders[i] = holders[holders.length - 1];
                holders.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    function getPhysicalRightsHolders(
        uint256 childId,
        uint256 orderId,
        address marketContract
    ) external view returns (address[] memory) {
        return _physicalRightsHolders[childId][orderId][marketContract];
    }

    function getIsPhysicalRightsHolder(
        uint256 childId,
        uint256 orderId,
        address to,
        address marketContract
    ) external view returns (bool) {
        return _isPhysicalRightsHolder[childId][orderId][marketContract][to];
    }

    function reserveSupplyForRequest(
        uint256 childId,
        bytes32 requestId,
        uint256 amount,
        bool isPhysical
    ) external onlySupplyCoordination {
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }
        if (amount == 0) {
            revert FGOErrors.ZeroValue();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];

        if (_reservedSupplyByRequest[childId][requestId] > 0) {
            revert FGOErrors.AlreadyReserved();
        }

        if (isPhysical && child.maxPhysicalEditions > 0) {
            uint256 usedPhysicalSupply = child.currentPhysicalEditions +
                child.totalReservedSupply;
            if (usedPhysicalSupply + amount > child.maxPhysicalEditions) {
                revert FGOErrors.InsufficientSupply();
            }
        }

        _reservedSupplyByRequest[childId][requestId] = amount;
        child.totalReservedSupply += amount;

        emit SupplyReserved(childId, requestId, amount);
    }

    function releaseReservedSupply(
        uint256 childId,
        bytes32 requestId
    ) external {
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        if (
            msg.sender != _children[childId].supplier &&
            msg.sender != address(supplyCoordination)
        ) {
            revert FGOErrors.Unauthorized();
        }

        uint256 reservedAmount = _reservedSupplyByRequest[childId][requestId];
        if (reservedAmount == 0) {
            revert FGOErrors.NoReservation();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];

        _reservedSupplyByRequest[childId][requestId] = 0;
        child.totalReservedSupply -= reservedAmount;

        emit SupplyReservationReleased(childId, requestId, reservedAmount);
    }

    function consumeReservedSupply(
        uint256 childId,
        bytes32 requestId,
        bool isPhysical
    ) external onlySupplyCoordination {
        if (!_childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        uint256 reservedAmount = _reservedSupplyByRequest[childId][requestId];
        if (reservedAmount == 0) {
            revert FGOErrors.NoReservation();
        }

        FGOLibrary.ChildMetadata storage child = _children[childId];

        _reservedSupplyByRequest[childId][requestId] = 0;
        child.totalReservedSupply -= reservedAmount;

        if (isPhysical) {
            child.currentPhysicalEditions += reservedAmount;
        }
    }

    function getReservedSupplyByRequest(
        uint256 childId,
        bytes32 requestId
    ) external view returns (uint256) {
        return _reservedSupplyByRequest[childId][requestId];
    }

    function getActiveUsageRelationship(
        uint256 childId,
        address contractAddress,
        uint256 entityId
    ) external view returns (uint256) {
        return _activeUsageRelationships[childId][contractAddress][entityId];
    }

    function isMarketAuthorized(
        uint256 childId,
        address market
    ) external view returns (bool) {
        return _authorizedMarkets[childId][market] > 0;
    }

    function uri(uint256 id) public view override returns (string memory) {
        if (!_childExists(id)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        return _children[id].uri;
    }
}
