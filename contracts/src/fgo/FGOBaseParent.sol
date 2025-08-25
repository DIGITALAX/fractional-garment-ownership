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
        uint256 amount,
        bool isPhysical,
        address indexed to,
        address indexed market
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
        string memory _scm,
        string memory _name,
        string memory _symbol,
        string memory _parentURI
    ) ERC721(_name, _symbol) {
        infraId = _infraId;
        scm = _scm;
        accessControl = FGOAccessControl(_accessControl);
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

        _supply++;

        _createParentBaseWithId(_supply, params);
        _setAuthorizedMarkets(_supply, params.authorizedMarkets);

        uint256 length = params.childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildReference memory childRef = params.childReferences[
                i
            ];

            try
                IFGOChild(childRef.childContract).requestParentApproval(
                    childRef.childId,
                    _supply,
                    childRef.amount
                )
            {} catch {
                revert FGOErrors.ChildNotAuthorized();
            }

            unchecked {
                ++i;
            }
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

        _validateChildApprovals(
            parent.childReferences,
            reservedParentId,
            parent.maxPhysicalEditions
        );

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
                revert FGOErrors.EditionLimitTooLow();
            }
            if (params.authorizedMarkets.length >= MAX_AUTHORIZED_ADDRESSES) {
                revert FGOErrors.BatchTooLarge();
            }

            if (_supply == type(uint256).max) {
                revert FGOErrors.MaxSupplyReached();
            }

            _validateChildReferences(params.childReferences);
            _validateFulfillmentWorkflow(params.workflow);

            _supply++;

            _createParentBaseWithId(_supply, params);
            _setAuthorizedMarkets(_supply, params.authorizedMarkets);

            uint256 length = params.childReferences.length;
            for (uint256 i = 0; i < length; ) {
                FGOLibrary.ChildReference memory childRef = params
                    .childReferences[i];

                try
                    IFGOChild(childRef.childContract).requestParentApproval(
                        childRef.childId,
                        _supply,
                        childRef.amount
                    )
                {} catch {
                    revert FGOErrors.ChildNotAuthorized();
                }

                unchecked {
                    ++i;
                }
            }

            reservedIds[j] = _supply;
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
                revert FGOErrors.ReservationNotActive();
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

            _validateChildApprovals(
                parent.childReferences,
                reservedParentId,
                parent.maxPhysicalEditions
            );

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
        bool isPhysical,
        address to,
        address market
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

        bool isAuthorizedMarket = parent.digitalMarketsOpenToAll ||
            parent.physicalMarketsOpenToAll ||
            _authorizedMarkets[parentId][msg.sender];
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

        emit ParentMinted(parentId, amount, isPhysical, to, market);
        
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
            revert FGOErrors.ReservationNotActive();
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
            revert FGOErrors.ReservationNotActive();
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
            revert FGOErrors.ReservationNotActive();
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
            revert FGOErrors.ReservationNotActive();
        }

        FGOLibrary.MarketApprovalRequest storage request = _marketRequests[
            designId
        ][msg.sender];
        request.market = msg.sender;
        request.designId = designId;
        request.timestamp = block.timestamp;
        request.isPending = true;

        emit MarketApprovalRequested(designId, msg.sender);
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
        address market
    ) external view returns (bool) {
        FGOLibrary.ParentMetadata storage design = _parents[designId];
        return
            design.digitalMarketsOpenToAll ||
            design.physicalMarketsOpenToAll ||
            _authorizedMarkets[designId][market];
    }

    function canPurchase(
        uint256 designId,
        bool isPhysical,
        address market
    ) external view returns (bool) {
        FGOLibrary.ParentMetadata storage design = _parents[designId];

        if (design.status != FGOLibrary.Status.ACTIVE) {
            return false;
        }

        bool parentApproves = design.digitalMarketsOpenToAll ||
            design.physicalMarketsOpenToAll ||
            _authorizedMarkets[designId][market];
        if (!parentApproves) {
            return false;
        }

        uint256 referencesLength = design.childReferences.length;
        for (uint256 i = 0; i < referencesLength; ) {
            FGOLibrary.ChildReference memory childRef = design.childReferences[
                i
            ];

            try
                IFGOChild(childRef.childContract).isChildActive(
                    childRef.childId
                )
            returns (bool childActive) {
                if (!childActive) {
                    revert FGOErrors.ChildInactiveOrCallFailed();
                }
            } catch {
                revert FGOErrors.ChildInactiveOrCallFailed();
            }

            try
                IFGOChild(childRef.childContract).approvesParent(
                    childRef.childId,
                    designId,
                    address(this)
                )
            returns (bool childApprovesParent) {
                if (!childApprovesParent) {
                    revert FGOErrors.ChildParentApprovalFailed();
                }
            } catch {
                revert FGOErrors.ChildParentApprovalFailed();
            }

            try
                IFGOChild(childRef.childContract).approvesMarket(
                    childRef.childId,
                    market
                )
            returns (bool childApprovesMarket) {
                if (!childApprovesMarket) {
                    revert FGOErrors.ChildMarketApprovalFailed();
                }
            } catch {
                revert FGOErrors.ChildMarketApprovalFailed();
            }
            unchecked {
                ++i;
            }
        }

        if (isPhysical) {
            if (
                design.maxPhysicalEditions > 0 &&
                design.currentPhysicalEditions >= design.maxPhysicalEditions
            ) {
                return false;
            }
        } else {
            if (
                design.maxDigitalEditions > 0 &&
                design.currentDigitalEditions >= design.maxDigitalEditions
            ) {
                return false;
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

        delete _parents[designId];
        address[] memory authorizedMarkets = design.authorizedMarkets;
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
            revert FGOErrors.ReservationNotActive();
        }

        FGOLibrary.ParentMetadata storage design = _parents[designId];
        if (design.status != FGOLibrary.Status.ACTIVE) {
            revert FGOErrors.EditionLimitTooLow();
        }

        bool marketAuthorized = design.digitalMarketsOpenToAll ||
            design.physicalMarketsOpenToAll ||
            _authorizedMarkets[designId][msg.sender];
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
        return designId <= _supply && designId > 0 && _parents[designId].designer != address(0);
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

    function _validateChildApprovals(
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 parentId,
        uint256 maxPhysicalEditions
    ) internal view {
        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];

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

            try
                IFGOChild(childRef.childContract).approvesParent(
                    childRef.childId,
                    parentId,
                    address(this)
                )
            returns (bool childApproves) {
                if (!childApproves) {
                    revert FGOErrors.ChildNotAuthorized();
                }
            } catch {
                revert FGOErrors.ChildNotAuthorized();
            }

            if (maxPhysicalEditions > 0) {
                uint256 totalPhysicalDemand = childRef.amount *
                    maxPhysicalEditions;

                try
                    IFGOChild(childRef.childContract).getParentApprovedAmount(
                        childRef.childId,
                        parentId,
                        address(this)
                    )
                returns (uint256 approvedAmount) {
                    if (totalPhysicalDemand > approvedAmount) {
                        revert FGOErrors.InsufficientRights();
                    }
                } catch {
                    revert FGOErrors.ChildContractCallFailed();
                }

                try
                    IFGOChild(childRef.childContract).getChildMetadata(
                        childRef.childId
                    )
                returns (FGOLibrary.ChildMetadata memory childMeta) {
                    if (
                        childMeta.maxPhysicalFulfillments > 0 &&
                        totalPhysicalDemand > childMeta.maxPhysicalFulfillments
                    ) {
                        revert FGOErrors.InsufficientRights();
                    }
                } catch {
                    revert FGOErrors.ChildMetadataCallFailed();
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
    
    function validatePriceCoversfulfillerCosts(
        uint256 designId,
        address fulfillersContract
    ) external view {
        if (!designExists(designId)) {
            revert FGOErrors.DesignDoesNotExist();
        }
        
        FGOLibrary.ParentMetadata memory parent = _parents[designId];
        
        _validatePriceForSteps(
            parent.workflow.digitalSteps,
            parent.digitalPrice,
            fulfillersContract
        );
        _validatePriceForSteps(
            parent.workflow.physicalSteps,
            parent.physicalPrice,
            fulfillersContract
        );
    }
    
    function _validatePriceCoversfulfillerCosts(
        FGOLibrary.CreateParentParams memory params,
        address fulfillersContract
    ) internal view {
        _validatePriceForSteps(
            params.workflow.digitalSteps,
            params.digitalPrice,
            fulfillersContract
        );
        _validatePriceForSteps(
            params.workflow.physicalSteps,
            params.physicalPrice,
            fulfillersContract
        );
    }
    
    function _validatePriceForSteps(
        FGOLibrary.FulfillmentStep[] memory steps,
        uint256 price,
        address fulfillersContract
    ) internal view {
        if (steps.length == 0) return;
        
        uint256 totalFulfillerCosts = 0;
        
        for (uint256 i = 0; i < steps.length; ) {
            address primaryPerformer = steps[i].primaryPerformer;
            
            if (primaryPerformer != address(0)) {
                uint256 fulfillerId = IFGOFulfillers(fulfillersContract)
                    .getFulfillerIdByAddress(primaryPerformer);
                    
                if (fulfillerId != 0) {
                    FGOLibrary.FulfillerProfile memory profile = IFGOFulfillers(fulfillersContract)
                        .getFulfillerProfile(fulfillerId);
                        
                    uint256 fulfillerPayment = profile.basePrice + 
                        ((price * profile.vigBasisPoints) / 10000);
                        
                    totalFulfillerCosts += fulfillerPayment;
                }
            }
            
            unchecked { ++i; }
        }
        
        if (totalFulfillerCosts > price) {
            revert FGOErrors.InsufficientPayment();
        }
    }
}
