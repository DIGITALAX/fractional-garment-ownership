// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./FGOAccessControl.sol";
import "./FGOLibrary.sol";
import "./FGOErrors.sol";
import "../interfaces/IFGOContracts.sol";

abstract contract FGOBaseParent is ERC721Enumerable, ReentrancyGuard {
    uint256 private _supply;
    uint256 private _tokenIdCounter;
    uint256 public constant MAX_AUTHORIZED_ADDRESSES = 50;
    bytes32 public infraId;
    FGOAccessControl public accessControl;
    address public fulfillers;
    string public parentURI;
    string public scm;

    mapping(uint256 => FGOLibrary.ParentMetadata) internal _parents;
    mapping(uint256 => uint256) internal _tokenToDesign;
    mapping(uint256 => mapping(address => bool)) internal _authorizedMarkets;
    mapping(uint256 => mapping(address => FGOLibrary.MarketApprovalRequest))
        private _marketRequests;

    event ParentReserved(uint256 indexed designId, address indexed designer);
    event ParentCreated(uint256 indexed designId, address indexed designer);
    event ParentMinted(
        uint256 indexed parentId,
        uint256 indexed amount,
        address indexed to,
        address market,
        bool isPhysical
    );
    event ParentUpdated(uint256 indexed designId);
    event ParentDisabled(uint256 indexed designId);
    event ParentEnabled(uint256 indexed designId);
    event ParentDeleted(uint256 indexed designId);
    event MarketApproved(uint256 indexed designId, address indexed market);
    event MarketRevoked(uint256 indexed designId, address indexed market);
    event MarketApprovalRequested(
        uint256 indexed designId,
        address indexed market
    );
    event MarketApprovalRejected(
        uint256 indexed designId,
        address indexed market
    );

    modifier onlyDesigner() {
        if (!accessControl.canCreateParents(msg.sender)) {
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

    modifier onlyDesignOwner(uint256 designId) {
        if (_parents[designId].designer != msg.sender) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    constructor(
        bytes32 _infraId,
        address _accessControl,
        address _fulfillers,
        string memory _scm,
        string memory _name,
        string memory _symbol,
        string memory _parentURI
    ) ERC721(_name, _symbol) {
        infraId = _infraId;
        scm = _scm;
        accessControl = FGOAccessControl(_accessControl);
        fulfillers = (_fulfillers);
        parentURI = _parentURI;
    }

    function reserveParent(
        FGOLibrary.CreateParentParams memory params
    ) external virtual onlyDesigner returns (uint256) {
        if (params.childReferences.length == 0) {
            revert FGOErrors.EmptyChildReferences();
        }
        if (params.childReferences.length > 100) {
            revert FGOErrors.BatchTooLarge();
        }
        if (bytes(params.uri).length == 0) {
            revert FGOErrors.EmptyURI();
        }
        if (params.authorizedMarkets.length >= MAX_AUTHORIZED_ADDRESSES) {
            revert FGOErrors.BatchTooLarge();
        }

        if (_supply == type(uint256).max) {
            revert FGOErrors.MaxSupplyReached();
        }

        _validateChildReferences(params.childReferences);
        _validateFulfillmentWorkflow(params.workflow);
        _validatePriceCoversfulfillerCosts(params);

        _supply++;

        _createParentBaseWithId(_supply, params);
        _setAuthorizedMarkets(_supply, params.authorizedMarkets);

        bool canAutoActivate = false;
        if (params.availability == FGOLibrary.Availability.PHYSICAL_ONLY) {
            canAutoActivate = _validateChildReferencesRecursive(
                params.childReferences,
                _supply,
                address(0),
                true,
                params.maxPhysicalEditions > 0 ? params.maxPhysicalEditions : 1,
                true
            );
        } else if (
            params.availability == FGOLibrary.Availability.DIGITAL_ONLY
        ) {
            canAutoActivate = _validateChildReferencesRecursive(
                params.childReferences,
                _supply,
                address(0),
                false,
                params.maxDigitalEditions > 0 ? params.maxDigitalEditions : 1,
                true
            );
        } else {
            canAutoActivate =
                _validateChildReferencesRecursive(
                    params.childReferences,
                    _supply,
                    address(0),
                    true,
                    params.maxPhysicalEditions > 0
                        ? params.maxPhysicalEditions
                        : 1,
                    true
                ) &&
                _validateChildReferencesRecursive(
                    params.childReferences,
                    _supply,
                    address(0),
                    false,
                    params.maxDigitalEditions > 0
                        ? params.maxDigitalEditions
                        : 1,
                    true
                );
        }

        if (canAutoActivate) {
            FGOLibrary.ParentMetadata storage parent = _parents[_supply];
            _incrementChildUsageCounts(parent.childReferences);

            parent.status = FGOLibrary.Status.ACTIVE;

            emit ParentCreated(_supply, msg.sender);
        } else {
            _requestNestedParentApprovals(params.childReferences, _supply);
        }

        emit ParentReserved(_supply, msg.sender);
        return _supply;
    }

    function createParent(
        uint256 reservedParentId
    ) external virtual onlyDesigner {
        if (!designExists(reservedParentId)) {
            revert FGOErrors.DesignDoesNotExist();
        }

        FGOLibrary.ParentMetadata storage parent = _parents[reservedParentId];

        if (parent.designer != msg.sender) {
            revert FGOErrors.Unauthorized();
        }
        if (parent.status != FGOLibrary.Status.RESERVED) {
            revert FGOErrors.ReservationNotActive();
        }

        if (parent.availability == FGOLibrary.Availability.PHYSICAL_ONLY) {
            if (
                !_validateChildReferencesRecursive(
                    parent.childReferences,
                    reservedParentId,
                    address(0),
                    true,
                    parent.maxPhysicalEditions > 0
                        ? parent.maxPhysicalEditions
                        : 1,
                    true
                )
            ) {
                revert FGOErrors.ChildNotAuthorized();
            }
        } else if (
            parent.availability == FGOLibrary.Availability.DIGITAL_ONLY
        ) {
            if (
                !_validateChildReferencesRecursive(
                    parent.childReferences,
                    reservedParentId,
                    address(0),
                    false,
                    parent.maxDigitalEditions > 0
                        ? parent.maxDigitalEditions
                        : 1,
                    true
                )
            ) {
                revert FGOErrors.ChildNotAuthorized();
            }
        } else {
            if (
                !_validateChildReferencesRecursive(
                    parent.childReferences,
                    reservedParentId,
                    address(0),
                    true,
                    parent.maxPhysicalEditions > 0
                        ? parent.maxPhysicalEditions
                        : 1,
                    true
                ) ||
                !_validateChildReferencesRecursive(
                    parent.childReferences,
                    reservedParentId,
                    address(0),
                    false,
                    parent.maxDigitalEditions > 0
                        ? parent.maxDigitalEditions
                        : 1,
                    true
                )
            ) {
                revert FGOErrors.ChildNotAuthorized();
            }
        }

        _incrementChildUsageCounts(parent.childReferences);

        parent.status = FGOLibrary.Status.ACTIVE;

        emit ParentCreated(reservedParentId, msg.sender);
    }

    function reserveParentBatch(
        FGOLibrary.CreateParentParams[] memory paramsArray
    ) external virtual onlyDesigner returns (uint256[] memory) {
        uint256 len = paramsArray.length;
        if (len == 0 || len > 20) {
            revert FGOErrors.BatchTooLarge();
        }

        uint256[] memory reservedIds = new uint256[](len);

        for (uint256 j = 0; j < len; ) {
            FGOLibrary.CreateParentParams memory params = paramsArray[j];

            if (params.childReferences.length == 0) {
                revert FGOErrors.EditionLimitTooLow();
            }
            if (params.childReferences.length > 100) {
                revert FGOErrors.BatchTooLarge();
            }
            if (bytes(params.uri).length == 0) {
                revert FGOErrors.EmptyURI();
            }
            if (params.authorizedMarkets.length >= MAX_AUTHORIZED_ADDRESSES) {
                revert FGOErrors.BatchTooLarge();
            }

            if (_supply == type(uint256).max) {
                revert FGOErrors.MaxSupplyReached();
            }

            _validateChildReferences(params.childReferences);
            _validateFulfillmentWorkflow(params.workflow);
            _validatePriceCoversfulfillerCosts(params);

            _supply++;

            _createParentBaseWithId(_supply, params);
            _setAuthorizedMarkets(_supply, params.authorizedMarkets);

            reservedIds[j] = _supply;

            bool canAutoActivate = false;
            if (params.availability == FGOLibrary.Availability.PHYSICAL_ONLY) {
                canAutoActivate = _validateChildReferencesRecursive(
                    params.childReferences,
                    _supply,
                    address(0),
                    true,
                    params.maxPhysicalEditions > 0
                        ? params.maxPhysicalEditions
                        : 1,
                    true
                );
            } else if (
                params.availability == FGOLibrary.Availability.DIGITAL_ONLY
            ) {
                canAutoActivate = _validateChildReferencesRecursive(
                    params.childReferences,
                    _supply,
                    address(0),
                    false,
                    params.maxDigitalEditions > 0
                        ? params.maxDigitalEditions
                        : 1,
                    true
                );
            } else {
                canAutoActivate =
                    _validateChildReferencesRecursive(
                        params.childReferences,
                        _supply,
                        address(0),
                        true,
                        params.maxPhysicalEditions > 0
                            ? params.maxPhysicalEditions
                            : 1,
                        true
                    ) &&
                    _validateChildReferencesRecursive(
                        params.childReferences,
                        _supply,
                        address(0),
                        false,
                        params.maxDigitalEditions > 0
                            ? params.maxDigitalEditions
                            : 1,
                        true
                    );
            }

            if (canAutoActivate) {
                FGOLibrary.ParentMetadata storage parent = _parents[_supply];
                _incrementChildUsageCounts(parent.childReferences);
                parent.status = FGOLibrary.Status.ACTIVE;
                emit ParentCreated(_supply, msg.sender);
            } else {
                _requestNestedParentApprovals(params.childReferences, _supply);
            }

            emit ParentReserved(_supply, msg.sender);
            unchecked {
                ++j;
            }
        }

        return reservedIds;
    }

    function createParentBatch(
        uint256[] memory reservedParentIds
    ) external virtual onlyDesigner nonReentrant {
        uint256 len = reservedParentIds.length;
        if (len == 0 || len > 20) {
            revert FGOErrors.BatchTooLarge();
        }

        uint256[] memory createdIds = new uint256[](len);

        for (uint256 j = 0; j < len; ) {
            uint256 reservedParentId = reservedParentIds[j];

            if (!designExists(reservedParentId)) {
                revert FGOErrors.DesignDoesNotExist();
            }

            FGOLibrary.ParentMetadata storage parent = _parents[
                reservedParentId
            ];

            if (parent.designer != msg.sender) {
                revert FGOErrors.Unauthorized();
            }
            if (parent.status != FGOLibrary.Status.RESERVED) {
                revert FGOErrors.ReservationNotActive();
            }
            if (parent.availability == FGOLibrary.Availability.PHYSICAL_ONLY) {
                if (
                    !_validateChildReferencesRecursive(
                        parent.childReferences,
                        reservedParentId,
                        address(0),
                        true,
                        parent.maxPhysicalEditions > 0
                            ? parent.maxPhysicalEditions
                            : 1,
                        true
                    )
                ) {
                    revert FGOErrors.ChildNotAuthorized();
                }
            } else if (
                parent.availability == FGOLibrary.Availability.DIGITAL_ONLY
            ) {
                if (
                    !_validateChildReferencesRecursive(
                        parent.childReferences,
                        reservedParentId,
                        address(0),
                        false,
                        parent.maxDigitalEditions > 0
                            ? parent.maxDigitalEditions
                            : 1,
                        true
                    )
                ) {
                    revert FGOErrors.ChildNotAuthorized();
                }
            } else {
                if (
                    !_validateChildReferencesRecursive(
                        parent.childReferences,
                        reservedParentId,
                        address(0),
                        true,
                        parent.maxPhysicalEditions > 0
                            ? parent.maxPhysicalEditions
                            : 1,
                        true
                    ) ||
                    !_validateChildReferencesRecursive(
                        parent.childReferences,
                        reservedParentId,
                        address(0),
                        false,
                        parent.maxDigitalEditions > 0
                            ? parent.maxDigitalEditions
                            : 1,
                        true
                    )
                ) {
                    revert FGOErrors.ChildNotAuthorized();
                }
            }

            _incrementChildUsageCounts(parent.childReferences);

            parent.status = FGOLibrary.Status.ACTIVE;

            createdIds[j] = reservedParentId;
            emit ParentCreated(reservedParentId, msg.sender);
            unchecked {
                ++j;
            }
        }
    }

    function mint(
        uint256 parentId,
        uint256 amount,
        address to,
        bool isPhysical
    ) external virtual nonReentrant returns (uint256[] memory) {
        if (to == address(0)) {
            revert FGOErrors.Unauthorized();
        }
        if (amount == 0) {
            revert FGOErrors.ZeroValue();
        }
        if (!designExists(parentId)) {
            revert FGOErrors.DesignDoesNotExist();
        }

        FGOLibrary.ParentMetadata storage parent = _parents[parentId];
        if (parent.status != FGOLibrary.Status.ACTIVE) {
            revert FGOErrors.ParentInactive();
        }

        bool isAuthorizedMarket = _authorizedMarkets[parentId][msg.sender];

        if (!isAuthorizedMarket) {
            if (isPhysical && parent.physicalMarketsOpenToAll) {
                isAuthorizedMarket = true;
            } else if (!isPhysical && parent.digitalMarketsOpenToAll) {
                isAuthorizedMarket = true;
            }
        }

        if (!isAuthorizedMarket) {
            revert FGOErrors.MarketNotAuthorized();
        }

        if (isPhysical) {
            if (parent.availability == FGOLibrary.Availability.DIGITAL_ONLY) {
                revert FGOErrors.PhysicalMintingNotAuthorized();
            }

            if (parent.currentPhysicalEditions > type(uint256).max - amount) {
                revert FGOErrors.MaxSupplyReached();
            }
            uint256 newPhysicalEditions = parent.currentPhysicalEditions +
                amount;

            if (
                parent.maxPhysicalEditions > 0 &&
                newPhysicalEditions > parent.maxPhysicalEditions
            ) {
                revert FGOErrors.MaxSupplyReached();
            }

            parent.currentPhysicalEditions = newPhysicalEditions;
        } else {
            if (parent.availability == FGOLibrary.Availability.PHYSICAL_ONLY) {
                revert FGOErrors.DigitalMintingNotAuthorized();
            }

            if (parent.currentDigitalEditions > type(uint256).max - amount) {
                revert FGOErrors.MaxSupplyReached();
            }
            uint256 newDigitalEditions = parent.currentDigitalEditions + amount;

            if (
                parent.maxDigitalEditions > 0 &&
                newDigitalEditions > parent.maxDigitalEditions
            ) {
                revert FGOErrors.MaxSupplyReached();
            }

            parent.currentDigitalEditions = newDigitalEditions;
        }

        uint256[] memory tokenIds = new uint256[](amount);
        for (uint256 i = 0; i < amount; ) {
            _tokenIdCounter++;
            _mint(to, _tokenIdCounter);
            _tokenToDesign[_tokenIdCounter] = parentId;
            tokenIds[i] = _tokenIdCounter;
            parent.tokenIds.push(_tokenIdCounter);
            unchecked {
                ++i;
            }
        }

        if (parent.totalPurchases > type(uint256).max - amount) {
            revert FGOErrors.MaxSupplyReached();
        }
        parent.totalPurchases += amount;

        emit ParentMinted(parentId, amount, to, msg.sender, isPhysical);

        return tokenIds;
    }

    function updateParent(
        FGOLibrary.UpdateParentParams memory params
    ) external virtual onlyDesignOwner(params.designId) {
        _updateParentInternal(params);
    }

    function _updateParentInternal(
        FGOLibrary.UpdateParentParams memory params
    ) internal {
        if (!designExists(params.designId)) {
            revert FGOErrors.DesignDoesNotExist();
        }

        FGOLibrary.ParentMetadata storage design = _parents[params.designId];
        if (design.totalPurchases > 0) {
            revert FGOErrors.HasPurchases();
        }

        if (
            params.maxDigitalEditions > 0 &&
            params.maxDigitalEditions < design.currentDigitalEditions
        ) {
            revert FGOErrors.EditionLimitTooLow();
        }
        if (
            params.maxPhysicalEditions > 0 &&
            params.maxPhysicalEditions < design.currentPhysicalEditions
        ) {
            revert FGOErrors.EditionLimitTooLow();
        }

        design.digitalPrice = params.digitalPrice;
        design.physicalPrice = params.physicalPrice;
        design.maxDigitalEditions = params.maxDigitalEditions;
        design.maxPhysicalEditions = params.maxPhysicalEditions;
        design.digitalMarketsOpenToAll = params.digitalMarketsOpenToAll;
        design.physicalMarketsOpenToAll = params.physicalMarketsOpenToAll;

        if (params.authorizedMarkets.length >= MAX_AUTHORIZED_ADDRESSES) {
            revert FGOErrors.BatchTooLarge();
        }

        address[] memory oldMarkets = design.authorizedMarkets;
        design.authorizedMarkets = params.authorizedMarkets;

        _clearAuthorizedMarkets(params.designId, oldMarkets);
        _setAuthorizedMarkets(params.designId, params.authorizedMarkets);

        emit ParentUpdated(params.designId);
    }

    function approveMarket(
        uint256 designId,
        address market
    ) external onlyDesignOwner(designId) {
        if (!designExists(designId)) {
            revert FGOErrors.DesignDoesNotExist();
        }

        FGOLibrary.ParentMetadata storage design = _parents[designId];
        if (design.status != FGOLibrary.Status.ACTIVE) {
            revert FGOErrors.ReservationNotActive();
        }

        if (_authorizedMarkets[designId][market]) {
            return;
        }

        _addAuthorizedMarket(designId, market);

        emit MarketApproved(designId, market);
    }

    function revokeMarket(
        uint256 designId,
        address market
    ) external onlyDesignOwner(designId) {
        if (!designExists(designId)) {
            revert FGOErrors.DesignDoesNotExist();
        }

        if (!_authorizedMarkets[designId][market]) {
            return;
        }

        _authorizedMarkets[designId][market] = false;

        FGOLibrary.ParentMetadata storage design = _parents[designId];
        uint256 marketsLength = design.authorizedMarkets.length;
        for (uint256 i = 0; i < marketsLength; ) {
            if (design.authorizedMarkets[i] == market) {
                design.authorizedMarkets[i] = design.authorizedMarkets[
                    marketsLength - 1
                ];
                design.authorizedMarkets.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }

        emit MarketRevoked(designId, market);
    }

    function requestMarketApproval(uint256 designId) external {
        if (!designExists(designId)) {
            revert FGOErrors.DesignDoesNotExist();
        }

        FGOLibrary.MarketApprovalRequest storage request = _marketRequests[
            designId
        ][msg.sender];
        request.market = msg.sender;
        request.designId = designId;
        request.timestamp = block.timestamp;
        request.isPending = true;

        FGOLibrary.ParentMetadata storage parent = _parents[designId];
        _requestNestedMarketApprovals(parent.childReferences, msg.sender);

        emit MarketApprovalRequested(designId, msg.sender);
    }

    function _requestNestedMarketApprovals(
        FGOLibrary.ChildReference[] memory childReferences,
        address market
    ) internal {
        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];

            try
                IFGOChild(childRef.childContract).requestMarketApproval(
                    childRef.childId
                )
            {} catch {}

            try
                IFGOChild(childRef.childContract).getChildMetadata(
                    childRef.childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                if (child.isTemplate) {
                    try
                        IFGOTemplate(childRef.childContract)
                            .getTemplatePlacements(childRef.childId)
                    returns (
                        FGOLibrary.ChildReference[] memory templatePlacements
                    ) {
                        _requestNestedMarketApprovals(
                            templatePlacements,
                            market
                        );
                    } catch {}
                }
            } catch {}

            unchecked {
                ++i;
            }
        }
    }

    function _requestNestedParentApprovals(
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 parentId
    ) internal {
        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];

            try
                IFGOChild(childRef.childContract).requestParentApproval(
                    childRef.childId,
                    parentId,
                    childRef.amount
                )
            {} catch {
                revert FGOErrors.ChildNotAuthorized();
            }

            try
                IFGOChild(childRef.childContract).getChildMetadata(
                    childRef.childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                if (child.isTemplate) {
                    try
                        IFGOTemplate(childRef.childContract)
                            .getTemplatePlacements(childRef.childId)
                    returns (
                        FGOLibrary.ChildReference[] memory templatePlacements
                    ) {
                        _requestNestedParentApprovals(
                            templatePlacements,
                            parentId
                        );
                    } catch {}
                }
            } catch {}

            unchecked {
                ++i;
            }
        }
    }

    function approveMarketRequest(
        uint256 designId,
        address market
    ) external onlyDesignOwner(designId) {
        FGOLibrary.MarketApprovalRequest storage request = _marketRequests[
            designId
        ][market];
        if (!request.isPending) {
            revert FGOErrors.NoPendingRequest();
        }

        if (_authorizedMarkets[designId][market]) {
            request.isPending = false;
            return;
        }

        _addAuthorizedMarket(designId, market);
        request.isPending = false;

        emit MarketApproved(designId, market);
    }

    function rejectMarketRequest(
        uint256 designId,
        address market
    ) external onlyDesignOwner(designId) {
        FGOLibrary.MarketApprovalRequest storage request = _marketRequests[
            designId
        ][market];
        if (!request.isPending) {
            revert FGOErrors.NoPendingRequest();
        }

        request.isPending = false;
        emit MarketApprovalRejected(designId, market);
    }

    function getMarketRequest(
        uint256 designId,
        address market
    ) external view returns (FGOLibrary.MarketApprovalRequest memory) {
        return _marketRequests[designId][market];
    }

    function approvesMarket(
        uint256 designId,
        address market,
        bool isPhysical
    ) external view returns (bool) {
        FGOLibrary.ParentMetadata storage design = _parents[designId];

        if (_authorizedMarkets[designId][market]) {
            return true;
        }

        if (isPhysical && design.physicalMarketsOpenToAll) {
            return true;
        }

        if (!isPhysical && design.digitalMarketsOpenToAll) {
            return true;
        }

        return false;
    }

    function canPurchase(
        uint256 designId,
        uint256 amount,
        bool isPhysical,
        address market
    ) external view returns (bool) {
        FGOLibrary.ParentMetadata storage design = _parents[designId];

        if (design.status != FGOLibrary.Status.ACTIVE) {
            return false;
        }

        bool parentApproves = _authorizedMarkets[designId][market];

        if (!parentApproves) {
            if (isPhysical && design.physicalMarketsOpenToAll) {
                parentApproves = true;
            } else if (!isPhysical && design.digitalMarketsOpenToAll) {
                parentApproves = true;
            }
        }

        if (!parentApproves) {
            return false;
        }

        if (
            isPhysical &&
            design.availability == FGOLibrary.Availability.DIGITAL_ONLY
        ) {
            return false;
        }
        if (
            !isPhysical &&
            design.availability == FGOLibrary.Availability.PHYSICAL_ONLY
        ) {
            return false;
        }

        if (isPhysical) {
            if (
                design.maxPhysicalEditions > 0 &&
                design.currentPhysicalEditions + amount > design.maxPhysicalEditions
            ) {
                return false;
            }
        } else {
            if (
                design.maxDigitalEditions > 0 &&
                design.currentDigitalEditions + amount > design.maxDigitalEditions
            ) {
                return false;
            }
        }

        return
            _validateChildReferencesRecursive(
                design.childReferences,
                designId,
                market,
                isPhysical,
                amount,
                false
            );
    }

    function _validateChildReferencesRecursive(
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 parentDesignId,
        address market,
        bool isPhysical,
        uint256 parentAmount,
        bool skipMarketChecks
    ) internal view returns (bool) {
        uint256 referencesLength = childReferences.length;
        for (uint256 i = 0; i < referencesLength; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];

            try
                IFGOChild(childRef.childContract).isChildActive(
                    childRef.childId
                )
            returns (bool childActive) {
                if (!childActive) {
                    return false;
                }
            } catch {
                return false;
            }

            try
                IFGOChild(childRef.childContract).approvesParent(
                    childRef.childId,
                    parentDesignId,
                    address(this),
                    isPhysical
                )
            returns (bool childApprovesParent) {
                if (!childApprovesParent) {
                    return false;
                }
            } catch {
                return false;
            }

            if (!skipMarketChecks && market != address(0)) {
                try
                    IFGOChild(childRef.childContract).approvesMarket(
                        childRef.childId,
                        market,
                        isPhysical
                    )
                returns (bool childApprovesMarket) {
                    if (!childApprovesMarket) {
                        return false;
                    }
                } catch {
                    return false;
                }
            }

            uint256 totalAmount = childRef.amount * parentAmount;
            try
                IFGOChild(childRef.childContract).getChildMetadata(
                    childRef.childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                FGOLibrary.ParentMetadata storage parent = _parents[parentDesignId];
                
                if (parent.availability != FGOLibrary.Availability.BOTH) {
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
                }

                if (isPhysical && child.maxPhysicalEditions > 0) {
                    if (
                        child.currentPhysicalEditions + totalAmount >
                        child.maxPhysicalEditions
                    ) {
                        return false;
                    }
                }

                if (child.isTemplate) {
                    try
                        IFGOChild(childRef.childContract).approvesParent(
                            childRef.childId,
                            parentDesignId,
                            address(this),
                            isPhysical
                        )
                    returns (bool templateApprovesParent) {
                        if (!templateApprovesParent) {
                            return false;
                        }
                    } catch {
                        return false;
                    }

                    if (isPhysical && child.maxPhysicalEditions > 0) {
                        if (
                            child.currentPhysicalEditions + totalAmount >
                            child.maxPhysicalEditions
                        ) {
                            return false;
                        }
                    }

                    try
                        IFGOTemplate(childRef.childContract)
                            .getTemplatePlacements(childRef.childId)
                    returns (
                        FGOLibrary.ChildReference[] memory templatePlacements
                    ) {
                        if (
                            !_validateChildReferencesRecursive(
                                templatePlacements,
                                parentDesignId,
                                market,
                                isPhysical,
                                totalAmount,
                                skipMarketChecks
                            )
                        ) {
                            return false;
                        }
                    } catch {
                        return false;
                    }
                }
            } catch {
                return false;
            }

            unchecked {
                ++i;
            }
        }

        return true;
    }

    function isParentActive(
        uint256 designId
    ) external view virtual returns (bool) {
        if (!designExists(designId)) {
            return false;
        }
        FGOLibrary.ParentMetadata storage design = _parents[designId];
        return design.status == FGOLibrary.Status.ACTIVE;
    }

    function disableParent(
        uint256 designId
    ) external virtual onlyDesignOwner(designId) {
        FGOLibrary.ParentMetadata storage design = _parents[designId];
        design.status = FGOLibrary.Status.DISABLED;
        emit ParentDisabled(designId);
    }

    function enableParent(
        uint256 designId
    ) external virtual onlyDesignOwner(designId) {
        FGOLibrary.ParentMetadata storage design = _parents[designId];
        design.status = FGOLibrary.Status.ACTIVE;
        emit ParentEnabled(designId);
    }

    function deleteParent(
        uint256 designId
    ) external virtual onlyDesignOwner(designId) {
        FGOLibrary.ParentMetadata storage design = _parents[designId];

        if (design.totalPurchases > 0) {
            revert FGOErrors.HasPurchases();
        }

        _decrementChildUsageCounts(design.childReferences);
        address[] memory authorizedMarkets = design.authorizedMarkets;

        delete _parents[designId];
        uint256 marketsLength = authorizedMarkets.length;
        for (uint256 i = 0; i < marketsLength; ) {
            delete _authorizedMarkets[designId][authorizedMarkets[i]];
            delete _marketRequests[designId][authorizedMarkets[i]];
            unchecked {
                ++i;
            }
        }
        emit ParentDeleted(designId);
    }

    function incrementPurchases(uint256 designId, bool isPhysical) external {
        if (!designExists(designId)) {
            revert FGOErrors.DesignDoesNotExist();
        }

        FGOLibrary.ParentMetadata storage design = _parents[designId];
        if (design.status != FGOLibrary.Status.ACTIVE) {
            revert FGOErrors.ParentInactive();
        }

        bool marketAuthorized = _authorizedMarkets[designId][msg.sender];

        if (!marketAuthorized) {
            if (isPhysical && design.physicalMarketsOpenToAll) {
                marketAuthorized = true;
            } else if (!isPhysical && design.digitalMarketsOpenToAll) {
                marketAuthorized = true;
            }
        }

        if (!marketAuthorized) {
            revert FGOErrors.MarketNotAuthorized();
        }

        if (design.totalPurchases == type(uint256).max) {
            revert FGOErrors.MaxSupplyReached();
        }
        design.totalPurchases++;

        if (isPhysical) {
            if (
                design.maxPhysicalEditions > 0 &&
                design.currentPhysicalEditions >= design.maxPhysicalEditions
            ) {
                revert FGOErrors.MaxSupplyReached();
            }
            if (design.currentPhysicalEditions == type(uint256).max) {
                revert FGOErrors.MaxSupplyReached();
            }
            design.currentPhysicalEditions++;
        } else {
            if (
                design.maxDigitalEditions > 0 &&
                design.currentDigitalEditions >= design.maxDigitalEditions
            ) {
                revert FGOErrors.MaxSupplyReached();
            }
            if (design.currentDigitalEditions == type(uint256).max) {
                revert FGOErrors.MaxSupplyReached();
            }
            design.currentDigitalEditions++;
        }
    }

    function _setAuthorizedMarkets(
        uint256 designId,
        address[] memory markets
    ) internal {
        uint256 length = markets.length;
        for (uint256 i = 0; i < length; ) {
            _authorizedMarkets[designId][markets[i]] = true;
            unchecked {
                ++i;
            }
        }
    }

    function _clearAuthorizedMarkets(
        uint256 designId,
        address[] memory markets
    ) internal {
        uint256 length = markets.length;
        for (uint256 i = 0; i < length; ) {
            _authorizedMarkets[designId][markets[i]] = false;
            unchecked {
                ++i;
            }
        }
    }

    function setAccessControl(address _accessControl) external onlyAdmin {
        accessControl = FGOAccessControl(_accessControl);
    }

    function setFulfillers(address _fulfillers) external onlyAdmin {
        fulfillers = (_fulfillers);
    }

    function getDesignTemplate(
        uint256 designId
    ) external view returns (FGOLibrary.ParentMetadata memory) {
        return _parents[designId];
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) {
            revert FGOErrors.TokenDoesNotExist();
        }
        uint256 designId = _tokenToDesign[tokenId];
        FGOLibrary.ParentMetadata storage design = _parents[designId];
        return design.uri;
    }

    function updateParentsBatch(
        FGOLibrary.UpdateParentParams[] memory params
    ) external nonReentrant {
        if (params.length > 20) {
            revert FGOErrors.BatchTooLarge();
        }

        uint256 length = params.length;
        for (uint256 i = 0; i < length; ) {
            if (
                !designExists(params[i].designId) ||
                _parents[params[i].designId].designer != msg.sender
            ) {
                revert FGOErrors.Unauthorized();
            }
            _updateParentInternal(params[i]);
            unchecked {
                ++i;
            }
        }
    }

    function designExists(uint256 designId) public view returns (bool) {
        return
            designId <= _supply &&
            designId > 0 &&
            _parents[designId].designer != address(0);
    }

    function _incrementChildUsageCounts(
        FGOLibrary.ChildReference[] memory childReferences
    ) internal {
        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            try
                IFGOChild(childReferences[i].childContract).incrementChildUsage(
                    childReferences[i].childId
                )
            {} catch {
                revert FGOErrors.ChildUsageUpdateFailed();
            }
            unchecked {
                ++i;
            }
        }
    }

    function _decrementChildUsageCounts(
        FGOLibrary.ChildReference[] memory childReferences
    ) internal {
        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            try
                IFGOChild(childReferences[i].childContract).decrementChildUsage(
                    childReferences[i].childId
                )
            {} catch {
                revert FGOErrors.ChildUsageUpdateFailed();
            }
            unchecked {
                ++i;
            }
        }
    }

    function getSupply() public view returns (uint256) {
        return _supply;
    }

    function getTokenCount() public view returns (uint256) {
        return _tokenIdCounter;
    }

    function getDesignFromToken(uint256 tokenId) public view returns (uint256) {
        return _tokenToDesign[tokenId];
    }

    function _validateChildReferences(
        FGOLibrary.ChildReference[] memory childReferences
    ) internal view {
        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];

            if (childRef.childContract == address(0)) {
                revert FGOErrors.Unauthorized();
            }
            if (childRef.amount == 0) {
                revert FGOErrors.EditionLimitTooLow();
            }

            try
                IFGOChild(childRef.childContract).isChildActive(
                    childRef.childId
                )
            returns (bool childActive) {
                if (!childActive) {
                    revert FGOErrors.ChildNotAuthorized();
                }
            } catch {
                revert FGOErrors.ChildNotAuthorized();
            }

            unchecked {
                ++i;
            }
        }
    }

    function _createParentBaseWithId(
        uint256 parentId,
        FGOLibrary.CreateParentParams memory params
    ) internal {
        _parents[parentId] = FGOLibrary.ParentMetadata({
            childReferences: params.childReferences,
            uri: params.uri,
            digitalPrice: params.digitalPrice,
            physicalPrice: params.physicalPrice,
            printType: params.printType,
            availability: params.availability,
            workflow: params.workflow,
            designer: msg.sender,
            digitalMarketsOpenToAll: params.digitalMarketsOpenToAll,
            physicalMarketsOpenToAll: params.physicalMarketsOpenToAll,
            authorizedMarkets: params.authorizedMarkets,
            tokenIds: new uint256[](0),
            status: FGOLibrary.Status.RESERVED,
            totalPurchases: 0,
            maxDigitalEditions: params.maxDigitalEditions,
            maxPhysicalEditions: params.maxPhysicalEditions,
            currentDigitalEditions: 0,
            currentPhysicalEditions: 0
        });
    }

    function _addAuthorizedMarket(uint256 designId, address market) internal {
        FGOLibrary.ParentMetadata storage design = _parents[designId];

        if (design.authorizedMarkets.length >= MAX_AUTHORIZED_ADDRESSES) {
            revert FGOErrors.BatchTooLarge();
        }

        _authorizedMarkets[designId][market] = true;
        design.authorizedMarkets.push(market);
    }

    function getReservationData(
        uint256 reservedParentId
    ) external view returns (FGOLibrary.ParentMetadata memory) {
        return _parents[reservedParentId];
    }

    function isReservationActive(
        uint256 reservedParentId
    ) external view returns (bool) {
        return
            designExists(reservedParentId) &&
            _parents[reservedParentId].status == FGOLibrary.Status.RESERVED;
    }

    function _validateFulfillmentWorkflow(
        FGOLibrary.FulfillmentWorkflow memory workflow
    ) internal view {
        _validateStepsArray(workflow.digitalSteps);
        _validateStepsArray(workflow.physicalSteps);
    }

    function _validateStepsArray(
        FGOLibrary.FulfillmentStep[] memory steps
    ) internal view {
        uint256 stepsLength = steps.length;

        if (stepsLength == 0) {
            return;
        }

        for (uint256 i = 0; i < stepsLength; ) {
            FGOLibrary.FulfillmentStep memory step = steps[i];

            if (step.primaryPerformer != address(0)) {
                if (!accessControl.isFulfiller(step.primaryPerformer)) {
                    revert FGOErrors.Unauthorized();
                }
            }

            uint256 subPerformersLength = step.subPerformers.length;
            for (uint256 j = 0; j < subPerformersLength; ) {
                if (step.subPerformers[j].performer != address(0)) {
                    if (
                        !accessControl.isFulfiller(
                            step.subPerformers[j].performer
                        )
                    ) {
                        revert FGOErrors.Unauthorized();
                    }
                }
                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    function _validatePriceCoversfulfillerCosts(
        FGOLibrary.CreateParentParams memory params
    ) internal view {
        _validatePriceForSteps(
            params.workflow.digitalSteps,
            params.digitalPrice
        );
        _validatePriceForSteps(
            params.workflow.physicalSteps,
            params.physicalPrice
        );
    }

    function _validatePriceForSteps(
        FGOLibrary.FulfillmentStep[] memory steps,
        uint256 price
    ) internal view {
        if (steps.length == 0) return;

        uint256 totalFulfillerCosts = 0;

        for (uint256 j = 0; j < steps.length; ) {
            address primaryPerformer = steps[j].primaryPerformer;

            if (primaryPerformer != address(0)) {
                uint256 fulfillerId = IFGOFulfillers(fulfillers)
                    .getFulfillerIdByAddress(primaryPerformer);

                if (fulfillerId != 0) {
                    FGOLibrary.FulfillerProfile memory profile = IFGOFulfillers(
                        fulfillers
                    ).getFulfillerProfile(fulfillerId);

                    uint256 fulfillerPayment = profile.basePrice +
                        ((price * profile.vigBasisPoints) / 10000);

                    totalFulfillerCosts += fulfillerPayment;
                }
            }

            unchecked {
                ++j;
            }
        }

        if (totalFulfillerCosts > price) {
            revert FGOErrors.InsufficientPayment();
        }
    }
}
