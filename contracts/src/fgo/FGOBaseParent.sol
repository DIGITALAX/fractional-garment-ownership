// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./FGOAccessControl.sol";
import "./FGOLibrary.sol";
import "./FGOErrors.sol";
import "../market/FGOSupplyCoordination.sol";
import "../interfaces/IFGOContracts.sol";

abstract contract FGOBaseParent is ERC721Enumerable, ReentrancyGuard {
    uint256 private _supply;
    uint256 private _tokenIdCounter;
    uint256 public constant MAX_AUTHORIZED_ADDRESSES = 50;
    bytes32 public infraId;
    FGOAccessControl public accessControl;
    FGOSupplyCoordination public supplyCoordination;
    address public fulfillers;
    address public futuresCoordination;
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

    modifier onlySupplyCoordination() {
        if (msg.sender != address(supplyCoordination)) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    constructor(
        bytes32 _infraId,
        address _accessControl,
        address _fulfillers,
        address _supplyCoordination,
        string memory _scm,
        string memory _name,
        string memory _symbol,
        string memory _parentURI
    ) ERC721(_name, _symbol) {
        infraId = _infraId;
        scm = _scm;
        accessControl = FGOAccessControl(_accessControl);
        supplyCoordination = FGOSupplyCoordination(_supplyCoordination);
        fulfillers = (_fulfillers);
        parentURI = _parentURI;
    }

    function reserveParent(
        FGOLibrary.CreateParentParams memory params
    ) external virtual onlyDesigner returns (uint256) {
        if (params.childReferences.length == 0 && params.supplyRequests.length == 0) {
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

        _validateChildReferences(params.childReferences, false);
        _validateFulfillmentWorkflow(params.workflow);
        _validatePriceCoversfulfillerCosts(
            params.digitalPrice,
            params.physicalPrice,
            params.workflow
        );

        _supply++;

        _createParentBaseWithId(_supply, params);
        _setAuthorizedMarkets(_supply, params.authorizedMarkets);

        if (
            params.availability == FGOLibrary.Availability.PHYSICAL_ONLY ||
            params.availability == FGOLibrary.Availability.BOTH
        ) {
            _validateUnlimitedPhysicalPropagation(
                params.maxPhysicalEditions,
                params.childReferences
            );
        }

        if (
            params.availability == FGOLibrary.Availability.DIGITAL_ONLY ||
            params.availability == FGOLibrary.Availability.BOTH
        ) {
            _validateUnlimitedDigitalPropagation(
                params.maxDigitalEditions,
                params.childReferences
            );
        }

        bool canAutoActivate = false;

        if (params.supplyRequests.length == 0 && params.childReferences.length > 0) {
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

                parent.status = FGOLibrary.Status.ACTIVE;
                _consumeFuturesCreditsForParent(_supply, params.childReferences, params.maxPhysicalEditions, params.maxDigitalEditions);
                _incrementUsageForChildren(_supply, params.childReferences);

                emit ParentCreated(_supply, msg.sender);
            } else {
                _requestNestedParentApprovals(params.childReferences, _supply, false);
            }
        } else if (params.supplyRequests.length > 0 && params.childReferences.length > 0) {
            _requestNestedParentApprovals(params.childReferences, _supply, false);
        }

        emit ParentReserved(_supply, msg.sender);
        return _supply;
    }

    function designExists(uint256 designId) public view virtual returns (bool) {
        return
            designId <= _supply &&
            designId > 0 &&
            _parents[designId].designer != address(0);
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

        _validateChildReferences(parent.childReferences, true);

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

        parent.status = FGOLibrary.Status.ACTIVE;
        _incrementUsageForChildren(reservedParentId, parent.childReferences);

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

            if (params.childReferences.length == 0 && params.supplyRequests.length == 0) {
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

            _validateChildReferences(params.childReferences, false);
            _validateFulfillmentWorkflow(params.workflow);
            _validatePriceCoversfulfillerCosts(
                params.digitalPrice,
                params.physicalPrice,
                params.workflow
            );

            _supply++;

            _createParentBaseWithId(_supply, params);
            _setAuthorizedMarkets(_supply, params.authorizedMarkets);

            if (
                params.availability == FGOLibrary.Availability.PHYSICAL_ONLY ||
                params.availability == FGOLibrary.Availability.BOTH
            ) {
                _validateUnlimitedPhysicalPropagation(
                    params.maxPhysicalEditions,
                    params.childReferences
                );
            }

            if (
                params.availability == FGOLibrary.Availability.DIGITAL_ONLY ||
                params.availability == FGOLibrary.Availability.BOTH
            ) {
                _validateUnlimitedDigitalPropagation(
                    params.maxDigitalEditions,
                    params.childReferences
                );
            }

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
                parent.status = FGOLibrary.Status.ACTIVE;
                _incrementUsageForChildren(_supply, params.childReferences);
                emit ParentCreated(_supply, msg.sender);
            } else {
                _requestNestedParentApprovals(params.childReferences, _supply, false);
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

            _validateChildReferences(parent.childReferences, true);
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

            parent.status = FGOLibrary.Status.ACTIVE;
            _incrementUsageForChildren(
                reservedParentId,
                parent.childReferences
            );

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

        if (
            design.availability == FGOLibrary.Availability.DIGITAL_ONLY ||
            design.availability == FGOLibrary.Availability.BOTH
        ) {
            params.digitalPrice = design.digitalPrice;
            params.maxDigitalEditions = design.maxDigitalEditions;
        }

        if (
            design.availability == FGOLibrary.Availability.PHYSICAL_ONLY ||
            design.availability == FGOLibrary.Availability.BOTH
        ) {
            params.physicalPrice = design.physicalPrice;
            params.maxPhysicalEditions = design.maxPhysicalEditions;
        }

        if (params.authorizedMarkets.length >= MAX_AUTHORIZED_ADDRESSES) {
            revert FGOErrors.BatchTooLarge();
        }

        address[] memory oldMarkets = design.authorizedMarkets;
        design.authorizedMarkets = params.authorizedMarkets;

        _validatePriceCoversfulfillerCosts(
            params.digitalPrice,
            params.physicalPrice,
            design.workflow
        );

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
        _requestNestedMarketApprovals(parent.childReferences, msg.sender, parent.maxPhysicalEditions, parent.maxDigitalEditions);

        emit MarketApprovalRequested(designId, msg.sender);
    }

    function _requestNestedMarketApprovals(
        FGOLibrary.ChildReference[] memory childReferences,
        address market,
        uint256 entityPhysicalEditions,
        uint256 entityDigitalEditions
    ) internal {
        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];

            FGOLibrary.ChildMetadata memory child;
            try
                IFGOChild(childRef.childContract).getChildMetadata(
                    childRef.childId
                )
            returns (FGOLibrary.ChildMetadata memory childMeta) {
                child = childMeta;
            } catch {
                revert FGOErrors.CatchBlock();
            }

            bool isPhysical = (child.availability == FGOLibrary.Availability.PHYSICAL_ONLY ||
                              child.availability == FGOLibrary.Availability.BOTH) &&
                             (child.maxPhysicalEditions > 0 || !child.futures.isFutures);

            uint256 totalDemand;
            if (isPhysical && entityPhysicalEditions > 0) {
                totalDemand = childRef.amount * entityPhysicalEditions;
            } else if (!isPhysical && entityDigitalEditions > 0) {
                totalDemand = childRef.amount * entityDigitalEditions;
            } else {
                totalDemand = type(uint256).max;
            }

            uint256 creditAmount = 0;
            if (child.futures.isFutures) {
                if (futuresCoordination != address(0)) {
                    creditAmount = IFGOFuturesCoordination(futuresCoordination).getFuturesCredits(
                        childRef.childContract,
                        childRef.childId,
                        msg.sender,
                        isPhysical
                    );
                }
            }

            uint256 totalCoverage = childRef.prepaidAmount + creditAmount;
            bool shouldRequestMarketApproval = totalDemand > totalCoverage;

            if (shouldRequestMarketApproval) {
                try
                    IFGOChild(childRef.childContract).requestMarketApproval(
                        childRef.childId
                    )
                {} catch {
                    revert FGOErrors.CatchBlock();
                }
            }

            if (child.isTemplate) {
                try
                    IFGOTemplate(childRef.childContract)
                        .getTemplatePlacements(childRef.childId)
                returns (
                    FGOLibrary.ChildReference[] memory templatePlacements
                ) {
                    _requestNestedMarketApprovals(
                        templatePlacements,
                        market,
                        child.maxPhysicalEditions,
                        child.maxDigitalEditions
                    );
                } catch {
                    revert FGOErrors.CatchBlock();
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    function _requestNestedParentApprovals(
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 parentId,
        bool isNested
    ) internal {
        FGOLibrary.ParentMetadata storage parentMetadata = _parents[parentId];

        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];

            FGOLibrary.ChildMetadata memory childMetadata;
            try
                IFGOChild(childRef.childContract).getChildMetadata(
                    childRef.childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                childMetadata = child;
            } catch {
                revert FGOErrors.ChildNotAuthorized();
            }

            bool needsPhysicalApproval = (parentMetadata.availability == FGOLibrary.Availability.PHYSICAL_ONLY ||
                                          parentMetadata.availability == FGOLibrary.Availability.BOTH) &&
                                         (childMetadata.availability == FGOLibrary.Availability.PHYSICAL_ONLY ||
                                          childMetadata.availability == FGOLibrary.Availability.BOTH);

            bool needsDigitalApproval = (parentMetadata.availability == FGOLibrary.Availability.DIGITAL_ONLY ||
                                         parentMetadata.availability == FGOLibrary.Availability.BOTH) &&
                                        (childMetadata.availability == FGOLibrary.Availability.DIGITAL_ONLY ||
                                         childMetadata.availability == FGOLibrary.Availability.BOTH);

            if (childMetadata.futures.isFutures) {
                if (isNested) {
                    unchecked {
                        ++i;
                    }
                    continue;
                }

                if (futuresCoordination == address(0)) {
                    revert FGOErrors.Unauthorized();
                }

                if (needsPhysicalApproval && parentMetadata.maxPhysicalEditions > 0) {
                    uint256 physicalAmount = childRef.amount * parentMetadata.maxPhysicalEditions;

                    uint256 designerCredits = IFGOFuturesCoordination(futuresCoordination).getFuturesCredits(
                        childRef.childContract,
                        childRef.childId,
                        msg.sender,
                        true
                    );

                    if (designerCredits < physicalAmount) {
                        revert FGOErrors.Unauthorized();
                    }

                    IFGOFuturesCoordination(futuresCoordination).consumeFuturesCredits(
                        childRef.childContract,
                        childRef.childId,
                        msg.sender,
                        physicalAmount,
                        true
                    );
                }

                if (needsDigitalApproval && parentMetadata.maxDigitalEditions > 0) {
                    uint256 digitalAmount = childRef.amount * parentMetadata.maxDigitalEditions;

                    uint256 designerCredits = IFGOFuturesCoordination(futuresCoordination).getFuturesCredits(
                        childRef.childContract,
                        childRef.childId,
                        msg.sender,
                        false
                    );

                    if (designerCredits < digitalAmount) {
                        revert FGOErrors.Unauthorized();
                    }

                    IFGOFuturesCoordination(futuresCoordination).consumeFuturesCredits(
                        childRef.childContract,
                        childRef.childId,
                        msg.sender,
                        digitalAmount,
                        false
                    );
                }
            } else {
                if (needsPhysicalApproval) {
                    uint256 totalPhysicalDemand = parentMetadata.maxPhysicalEditions > 0 ?
                        childRef.amount * parentMetadata.maxPhysicalEditions :
                        type(uint256).max;

                    uint256 physicalApprovalNeeded = totalPhysicalDemand > childRef.prepaidAmount
                        ? totalPhysicalDemand - childRef.prepaidAmount
                        : 0;

                    if (physicalApprovalNeeded > 0) {
                        try
                            IFGOChild(childRef.childContract).requestParentApproval(
                                childRef.childId,
                                parentId,
                                physicalApprovalNeeded,
                                true
                            )
                        {} catch {
                            revert FGOErrors.ChildNotAuthorized();
                        }
                    }
                }

                if (needsDigitalApproval) {
                    uint256 totalDigitalDemand = parentMetadata.maxDigitalEditions > 0 ?
                        childRef.amount * parentMetadata.maxDigitalEditions :
                        type(uint256).max;

                    uint256 digitalApprovalNeeded = totalDigitalDemand > childRef.prepaidAmount
                        ? totalDigitalDemand - childRef.prepaidAmount
                        : 0;

                    if (digitalApprovalNeeded > 0) {
                        try
                            IFGOChild(childRef.childContract).requestParentApproval(
                                childRef.childId,
                                parentId,
                                digitalApprovalNeeded,
                                false
                            )
                        {} catch {
                            revert FGOErrors.ChildNotAuthorized();
                        }
                    }
                }
            }

            if (childMetadata.isTemplate) {
                try
                    IFGOTemplate(childRef.childContract)
                        .getTemplatePlacements(childRef.childId)
                returns (
                    FGOLibrary.ChildReference[] memory templatePlacements
                ) {
                    _requestNestedParentApprovals(
                        templatePlacements,
                        parentId,
                        true
                    );
                } catch {
                    revert FGOErrors.CatchBlock();
                }
            }

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
                design.currentPhysicalEditions + amount >
                design.maxPhysicalEditions
            ) {
                return false;
            }
        } else {
            if (
                design.maxDigitalEditions > 0 &&
                design.currentDigitalEditions + amount >
                design.maxDigitalEditions
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
        if (
            !_validateTemplateApprovalsRecursive(
                childReferences,
                parentDesignId,
                isPhysical,
                parentAmount
            )
        ) {
            return false;
        }

        FGOLibrary.DemandEntry[] memory demands = new FGOLibrary.DemandEntry[](
            0
        );
        demands = _calculateCumulativeDemand(
            childReferences,
            parentAmount,
            demands
        );

        return
            _validateCumulativeDemandAndApprovals(
                demands,
                parentDesignId,
                market,
                isPhysical,
                skipMarketChecks
            );
    }

    function _validateTemplateApprovalsRecursive(
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 parentDesignId,
        bool isPhysical,
        uint256 parentAmount
    ) internal view returns (bool) {
        uint256 referencesLength = childReferences.length;
        for (uint256 i = 0; i < referencesLength; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];
            uint256 totalAmount = childRef.amount * parentAmount;

            try
                IFGOChild(childRef.childContract).getChildMetadata(
                    childRef.childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
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

                    try
                        IFGOTemplate(childRef.childContract)
                            .getTemplatePlacements(childRef.childId)
                    returns (
                        FGOLibrary.ChildReference[] memory templatePlacements
                    ) {
                        if (
                            !_validateTemplateApprovalsRecursive(
                                templatePlacements,
                                parentDesignId,
                                isPhysical,
                                totalAmount
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

    function _calculateCumulativeDemand(
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 parentAmount,
        FGOLibrary.DemandEntry[] memory demands
    ) internal view returns (FGOLibrary.DemandEntry[] memory) {
        uint256 referencesLength = childReferences.length;
        for (uint256 i = 0; i < referencesLength; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];
            uint256 totalAmount = childRef.amount * parentAmount;

            try
                IFGOChild(childRef.childContract).getChildMetadata(
                    childRef.childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                if (!child.isTemplate) {
                    demands = _addToDemands(
                        demands,
                        childRef.childContract,
                        childRef.childId,
                        totalAmount
                    );
                }
            } catch {
                demands = _addToDemands(
                    demands,
                    childRef.childContract,
                    childRef.childId,
                    totalAmount
                );
            }

            unchecked {
                ++i;
            }
        }
        return demands;
    }

    function _addToDemands(
        FGOLibrary.DemandEntry[] memory demands,
        address contractAddr,
        uint256 childId,
        uint256 amount
    ) internal pure returns (FGOLibrary.DemandEntry[] memory) {
        for (uint256 i = 0; i < demands.length; ) {
            if (
                demands[i].childContract == contractAddr &&
                demands[i].childId == childId
            ) {
                demands[i].cumulativeDemand += amount;
                return demands;
            }
            unchecked {
                ++i;
            }
        }

        FGOLibrary.DemandEntry[]
            memory newDemands = new FGOLibrary.DemandEntry[](
                demands.length + 1
            );
        for (uint256 i = 0; i < demands.length; ) {
            newDemands[i] = demands[i];
            unchecked {
                ++i;
            }
        }
        newDemands[demands.length] = FGOLibrary.DemandEntry({
            childContract: contractAddr,
            childId: childId,
            cumulativeDemand: amount
        });

        return newDemands;
    }

    function _validateCumulativeDemandAndApprovals(
        FGOLibrary.DemandEntry[] memory demands,
        uint256 parentDesignId,
        address market,
        bool isPhysical,
        bool skipMarketChecks
    ) internal view returns (bool) {
        FGOLibrary.ParentMetadata storage parent = _parents[parentDesignId];
        bool skipAvailabilityMismatches = parent.availability == FGOLibrary.Availability.BOTH;

        for (uint256 i = 0; i < demands.length; ) {
            FGOLibrary.DemandEntry memory demand = demands[i];

            try
                IFGOChild(demand.childContract).isChildActive(demand.childId)
            returns (bool childActive) {
                if (!childActive) {
                    return false;
                }
            } catch {
                return false;
            }

            uint256 approvedAmount = 0;
            bool hasOpenAccess = false;
            bool skipChild = false;

            try
                IFGOChild(demand.childContract).getChildMetadata(demand.childId)
            returns (FGOLibrary.ChildMetadata memory childMeta) {
                if (skipAvailabilityMismatches) {
                    if (isPhysical && childMeta.availability == FGOLibrary.Availability.DIGITAL_ONLY) {
                        skipChild = true;
                    } else if (!isPhysical && childMeta.availability == FGOLibrary.Availability.PHYSICAL_ONLY) {
                        skipChild = true;
                    }
                }

                if (!skipChild) {
                    if (isPhysical && childMeta.physicalReferencesOpenToAll) {
                        hasOpenAccess = true;
                    } else if (!isPhysical && childMeta.digitalReferencesOpenToAll) {
                        hasOpenAccess = true;
                    }
                }
            } catch {
                return false;
            }

            if (skipChild) {
                unchecked {
                    ++i;
                }
                continue;
            }

            if (!hasOpenAccess) {
                try
                    IFGOChild(demand.childContract).getParentApprovedAmount(
                        demand.childId,
                        parentDesignId,
                        address(this),
                        isPhysical
                    )
                returns (uint256 approved) {
                    approvedAmount = approved;
                } catch {
                    approvedAmount = 0;
                }

                uint256 futuresCredits = 0;
                if (futuresCoordination != address(0)) {
                    try
                        IFGOFuturesCoordination(futuresCoordination).getFuturesCredits(
                            demand.childContract,
                            demand.childId,
                            parent.designer,
                            isPhysical
                        )
                    returns (uint256 credits) {
                        futuresCredits = credits;
                    } catch {}
                }

                if (approvedAmount + futuresCredits < demand.cumulativeDemand) {
                    return false;
                }
            }

            if (!skipMarketChecks && market != address(0)) {
                bool skipMarketCheck = false;

                try
                    IFGOChild(demand.childContract).getChildMetadata(demand.childId)
                returns (FGOLibrary.ChildMetadata memory childMeta) {
                    if (childMeta.futures.isFutures) {
                        skipMarketCheck = true;
                    }
                } catch {}

                if (!skipMarketCheck) {
                    try
                        IFGOChild(demand.childContract).approvesMarket(
                            demand.childId,
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
            }

            try
                IFGOChild(demand.childContract).getChildMetadata(demand.childId)
            returns (FGOLibrary.ChildMetadata memory child) {
                if (parent.availability != FGOLibrary.Availability.BOTH) {
                    if (
                        isPhysical &&
                        child.availability ==
                        FGOLibrary.Availability.DIGITAL_ONLY
                    ) {
                        return false;
                    }
                    if (
                        !isPhysical &&
                        child.availability ==
                        FGOLibrary.Availability.PHYSICAL_ONLY
                    ) {
                        return false;
                    }
                }

                if (isPhysical && child.maxPhysicalEditions > 0) {
                    if (
                        child.currentPhysicalEditions +
                            child.totalReservedSupply +
                            child.usageCount +
                            demand.cumulativeDemand >
                        child.maxPhysicalEditions + child.totalPrepaidAmount
                    ) {
                        return false;
                    }
                }

                if (!isPhysical) {
                    if (child.futures.isFutures && child.futures.maxDigitalEditions > 0) {
                        if (child.isTemplate) {
                            uint256 maxDigitalForTemplate = 0;
                            try
                                IFGOChild(demand.childContract).getTemplateApprovedAmount(
                                    demand.childId,
                                    parentDesignId,
                                    address(this),
                                    false
                                )
                            returns (uint256 approved) {
                                maxDigitalForTemplate = approved;
                            } catch {
                                return false;
                            }

                            if (demand.cumulativeDemand > maxDigitalForTemplate) {
                                return false;
                            }
                        } else {
                            if (
                                child.currentDigitalEditions +
                                    demand.cumulativeDemand >
                                child.futures.maxDigitalEditions + child.totalPrepaidAmount
                            ) {
                                return false;
                            }
                        }
                    } else if (child.maxDigitalEditions > 0) {
                        if (
                            child.currentDigitalEditions +
                                demand.cumulativeDemand >
                            child.maxDigitalEditions + child.totalPrepaidAmount
                        ) {
                            return false;
                        }
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

        address[] memory authorizedMarkets = design.authorizedMarkets;

        if (design.status == FGOLibrary.Status.ACTIVE) {
            _decrementUsageForChildren(designId, design.childReferences);
        }

        if (design.supplyRequests.length > 0) {
            supplyCoordination.releaseAllSupplyForParent(designId, address(this));
        }

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

    function updateStatusFromSupply(
        uint256 designId
    ) external onlySupplyCoordination {
        if (!designExists(designId)) {
            revert FGOErrors.DesignDoesNotExist();
        }

        FGOLibrary.ParentMetadata storage design = _parents[designId];

        if (design.status != FGOLibrary.Status.SUPPLY_PENDING) {
            revert FGOErrors.InvalidStatus();
        }

        design.status = FGOLibrary.Status.RESERVED;
    }

    function updatePrepaidSupply(
        uint256 designId,
        address childContract,
        uint256 childId,
        uint256 perParentAmount,
        uint256 totalPrepaidAmount,
        string calldata placementURI
    ) external onlySupplyCoordination {
        if (!designExists(designId)) {
            revert FGOErrors.DesignDoesNotExist();
        }

        FGOLibrary.ParentMetadata storage parent = _parents[designId];
        bool found = false;

        for (uint256 i = 0; i < parent.childReferences.length; ) {
            if (
                parent.childReferences[i].childContract == childContract &&
                parent.childReferences[i].childId == childId
            ) {
                parent.childReferences[i].amount += perParentAmount;
                parent.childReferences[i].prepaidAmount += totalPrepaidAmount;
                found = true;
                break;
            }
            unchecked {
                ++i;
            }
        }

        if (!found) {
            parent.childReferences.push(FGOLibrary.ChildReference({
                childId: childId,
                childContract: childContract,
                amount: perParentAmount,
                prepaidAmount: totalPrepaidAmount,
                prepaidUsed: 0,
                placementURI: placementURI
            }));
        }

        IFGOChild(childContract).incrementTotalPrepaidAmount(childId, totalPrepaidAmount);
    }

    function getPrepaidAvailable(
        uint256 designId,
        address childContract,
        uint256 childId
    ) public view returns (uint256) {
        if (!designExists(designId)) {
            return 0;
        }

        FGOLibrary.ParentMetadata storage parent = _parents[designId];

        for (uint256 i = 0; i < parent.childReferences.length; ) {
            if (
                parent.childReferences[i].childContract == childContract &&
                parent.childReferences[i].childId == childId
            ) {
                return parent.childReferences[i].prepaidAmount - parent.childReferences[i].prepaidUsed;
            }
            unchecked {
                ++i;
            }
        }

        return 0;
    }

    function updatePrepaidUsed(
        uint256 designId,
        address childContract,
        uint256 childId,
        uint256 amountUsed
    ) external {
        if (!_authorizedMarkets[designId][msg.sender]) {
            revert FGOErrors.Unauthorized();
        }

        if (!designExists(designId)) {
            revert FGOErrors.DesignDoesNotExist();
        }

        FGOLibrary.ParentMetadata storage parent = _parents[designId];

        for (uint256 i = 0; i < parent.childReferences.length; ) {
            if (
                parent.childReferences[i].childContract == childContract &&
                parent.childReferences[i].childId == childId
            ) {
                parent.childReferences[i].prepaidUsed += amountUsed;
                break;
            }
            unchecked {
                ++i;
            }
        }
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

    function setSupplyCoordination(
        address _supplyCoordination
    ) external onlyAdmin {
        supplyCoordination = FGOSupplyCoordination(_supplyCoordination);
    }

    function setFulfillers(address _fulfillers) external onlyAdmin {
        fulfillers = (_fulfillers);
    }

    function setFuturesCoordination(address _futuresCoordination) external onlyAdmin {
        futuresCoordination = _futuresCoordination;
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

    function _consumeFuturesCreditsForParent(
        uint256 parentId,
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 maxPhysicalEditions,
        uint256 maxDigitalEditions
    ) internal {
        if (futuresCoordination == address(0)) {
            return;
        }

        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildMetadata memory childMetadata;
            try
                IFGOChild(childReferences[i].childContract).getChildMetadata(
                    childReferences[i].childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                childMetadata = child;
            } catch {
                unchecked {
                    ++i;
                }
                continue;
            }

            if (!childMetadata.futures.isFutures) {
                unchecked {
                    ++i;
                }
                continue;
            }

            FGOLibrary.ParentMetadata storage parent = _parents[parentId];

            bool needsPhysicalApproval = (parent.availability == FGOLibrary.Availability.PHYSICAL_ONLY ||
                                          parent.availability == FGOLibrary.Availability.BOTH) &&
                                         (childMetadata.availability == FGOLibrary.Availability.PHYSICAL_ONLY ||
                                          childMetadata.availability == FGOLibrary.Availability.BOTH);

            bool needsDigitalApproval = (parent.availability == FGOLibrary.Availability.DIGITAL_ONLY ||
                                         parent.availability == FGOLibrary.Availability.BOTH) &&
                                        (childMetadata.availability == FGOLibrary.Availability.DIGITAL_ONLY ||
                                         childMetadata.availability == FGOLibrary.Availability.BOTH);

            if (needsPhysicalApproval && maxPhysicalEditions > 0) {
                uint256 physicalAmount = childReferences[i].amount * maxPhysicalEditions;
                IFGOFuturesCoordination(futuresCoordination).consumeFuturesCredits(
                    childReferences[i].childContract,
                    childReferences[i].childId,
                    msg.sender,
                    physicalAmount,
                    true
                );
            }

            if (needsDigitalApproval && maxDigitalEditions > 0) {
                uint256 digitalAmount = childReferences[i].amount * maxDigitalEditions;
                IFGOFuturesCoordination(futuresCoordination).consumeFuturesCredits(
                    childReferences[i].childContract,
                    childReferences[i].childId,
                    msg.sender,
                    digitalAmount,
                    false
                );
            }

            unchecked {
                ++i;
            }
        }
    }

    function _incrementUsageForChildren(
        uint256 parentId,
        FGOLibrary.ChildReference[] memory childReferences
    ) internal {
        FGOLibrary.ParentMetadata memory parentMetadata = _parents[parentId];
        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            try
                IFGOChild(childReferences[i].childContract).incrementChildUsage(
                    childReferences[i].childId,
                    parentId,
                    childReferences[i].amount,
                    parentMetadata.maxPhysicalEditions,
                    parentMetadata.maxDigitalEditions,
                    false
                )
            {} catch {
                revert FGOErrors.CatchBlock();
            }
            unchecked {
                ++i;
            }
        }
    }

    function _decrementUsageForChildren(
        uint256 parentId,
        FGOLibrary.ChildReference[] memory childReferences
    ) internal {
        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            try
                IFGOChild(childReferences[i].childContract).decrementChildUsage(
                    childReferences[i].childId,
                    parentId
                )
            {} catch {
                revert FGOErrors.CatchBlock();
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
        FGOLibrary.ChildReference[] memory childReferences,
        bool requireActive
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

            if (requireActive) {
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
        FGOLibrary.Status initialStatus = FGOLibrary.Status.RESERVED;

        if (params.supplyRequests.length > 0) {
            initialStatus = FGOLibrary.Status.SUPPLY_PENDING;
        }

        for (uint256 i = 0; i < params.childReferences.length; ) {
            params.childReferences[i].prepaidUsed = 0;
            unchecked {
                ++i;
            }
        }

        _parents[parentId] = FGOLibrary.ParentMetadata({
            childReferences: params.childReferences,
            supplyRequests: params.supplyRequests,
            uri: params.uri,
            digitalPrice: params.availability ==
                FGOLibrary.Availability.PHYSICAL_ONLY
                ? 0
                : params.digitalPrice,
            physicalPrice: params.availability ==
                FGOLibrary.Availability.DIGITAL_ONLY
                ? 0
                : params.physicalPrice,
            printType: params.printType,
            availability: params.availability,
            workflow: params.workflow,
            designer: msg.sender,
            digitalMarketsOpenToAll: params.digitalMarketsOpenToAll,
            physicalMarketsOpenToAll: params.physicalMarketsOpenToAll,
            authorizedMarkets: params.authorizedMarkets,
            tokenIds: new uint256[](0),
            status: initialStatus,
            totalPurchases: 0,
            maxDigitalEditions: params.availability ==
                FGOLibrary.Availability.PHYSICAL_ONLY
                ? 0
                : params.maxDigitalEditions,
            maxPhysicalEditions: params.availability ==
                FGOLibrary.Availability.DIGITAL_ONLY
                ? 0
                : params.maxPhysicalEditions,
            currentDigitalEditions: 0,
            currentPhysicalEditions: 0
        });

        if (params.supplyRequests.length > 0) {
            for (uint256 i = 0; i < params.supplyRequests.length; ) {
                supplyCoordination.registerSupplyRequest(
                    parentId,
                    msg.sender,
                    i,
                    params.supplyRequests[i]
                );
                unchecked {
                    ++i;
                }
            }
        }
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

            unchecked {
                ++i;
            }
        }
    }

    function _validatePriceCoversfulfillerCosts(
        uint256 digitalPrice,
        uint256 physicalPrice,
        FGOLibrary.FulfillmentWorkflow memory workflow
    ) internal view {
        _validatePriceForSteps(workflow.digitalSteps, digitalPrice);
        _validatePriceForSteps(workflow.physicalSteps, physicalPrice);
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

    function _validateUnlimitedPhysicalPropagation(
        uint256 maxPhysicalEditions,
        FGOLibrary.ChildReference[] memory childReferences
    ) internal view {
        if (maxPhysicalEditions != 0) {
            return;
        }

        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildMetadata memory childMetadata;

            try
                IFGOChild(childReferences[i].childContract).getChildMetadata(
                    childReferences[i].childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                childMetadata = child;
            } catch {
                revert FGOErrors.ChildNotAuthorized();
            }

            if (
                childMetadata.availability == FGOLibrary.Availability.PHYSICAL_ONLY ||
                childMetadata.availability == FGOLibrary.Availability.BOTH
            ) {
                if (childMetadata.maxPhysicalEditions != 0) {
                    revert FGOErrors.Unauthorized();
                }

                if (childMetadata.isTemplate) {
                    try
                        IFGOTemplate(childReferences[i].childContract)
                            .getTemplatePlacements(childReferences[i].childId)
                    returns (
                        FGOLibrary.ChildReference[] memory templatePlacements
                    ) {
                        _validateUnlimitedPhysicalPropagation(
                            0,
                            templatePlacements
                        );
                    } catch {
                        revert FGOErrors.CatchBlock();
                    }
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    function _validateUnlimitedDigitalPropagation(
        uint256 maxDigitalEditions,
        FGOLibrary.ChildReference[] memory childReferences
    ) internal view {
        if (maxDigitalEditions != 0) {
            return;
        }

        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildMetadata memory childMetadata;

            try
                IFGOChild(childReferences[i].childContract).getChildMetadata(
                    childReferences[i].childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                childMetadata = child;
            } catch {
                revert FGOErrors.ChildNotAuthorized();
            }

            if (
                childMetadata.availability == FGOLibrary.Availability.DIGITAL_ONLY ||
                childMetadata.availability == FGOLibrary.Availability.BOTH
            ) {
                bool hasDigitalLimit = false;

                if (childMetadata.futures.isFutures && childMetadata.futures.maxDigitalEditions > 0) {
                    hasDigitalLimit = true;
                }

                if (childReferences[i].prepaidAmount > 0) {
                    hasDigitalLimit = true;
                }

                if (hasDigitalLimit) {
                    revert FGOErrors.Unauthorized();
                }

                if (childMetadata.isTemplate) {
                    try
                        IFGOTemplate(childReferences[i].childContract)
                            .getTemplatePlacements(childReferences[i].childId)
                    returns (
                        FGOLibrary.ChildReference[] memory templatePlacements
                    ) {
                        _validateUnlimitedDigitalPropagation(
                            0,
                            templatePlacements
                        );
                    } catch {
                        revert FGOErrors.CatchBlock();
                    }
                }
            }

            unchecked {
                ++i;
            }
        }
    }
}
