// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./FGOAccessControl.sol";
import "./FGOLibrary.sol";
import "./FGOErrors.sol";

interface IFGOChild {
    function approvesParent(
        uint256 childId,
        uint256 parentId,
        address parentContract
    ) external view returns (bool);

    function approvesMarket(
        uint256 childId,
        address market
    ) external view returns (bool);

    function incrementChildUsage(uint256 childId) external;

    function decrementChildUsage(uint256 childId) external;

    function isChildActive(uint256 childId) external view returns (bool);

    function requestParentApproval(uint256 childId, uint256 parentId) external;
}

abstract contract FGOBaseParent is ERC721Enumerable, ReentrancyGuard {
    uint256 private _supply;
    uint256 public constant MAX_AUTHORIZED_ADDRESSES = 50;
    string public parentURI;
    string public smu;
    FGOAccessControl public accessControl;

    mapping(uint256 => FGOLibrary.ParentMetadata) internal _parents;
    mapping(uint256 => mapping(address => bool)) internal _authorizedMarkets;
    mapping(uint256 => mapping(address => FGOLibrary.MarketApprovalRequest))
        private _marketRequests;
    mapping(uint256 => address) private _reservedBy;

    event ParentMinted(uint256 indexed designId, address indexed designer);
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

    modifier onlyDesignOwner(uint256 designId) {
        if (ownerOf(designId) != msg.sender) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    constructor(
        address _accessControl,
        string memory _smu,
        string memory _name,
        string memory _symbol,
        string memory _parentURI
    ) ERC721(_name, _symbol) {
        smu = _smu;
        accessControl = FGOAccessControl(_accessControl);
        parentURI = _parentURI;
    }

    function reserveParent(
        FGOLibrary.CreateParentParams memory params
    ) external virtual onlyDesigner returns (uint256) {
        if (params.childReferences.length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        if (params.childReferences.length > 100) {
            revert FGOErrors.BatchTooLarge();
        }
        if (bytes(params.uri).length == 0) {
            revert FGOErrors.InvalidAmount();
        }

        if (_supply == type(uint256).max) {
            revert FGOErrors.MaxSupplyReached();
        }
        _supply++;

        uint256 reservedParentId = _supply;

        _reservedBy[reservedParentId] = msg.sender;

        for (uint256 i = 0; i < params.childReferences.length; ) {
            FGOLibrary.ChildReference memory childRef = params.childReferences[
                i
            ];

            if (childRef.childContract == address(0)) {
                revert FGOErrors.AddressInvalid();
            }
            if (childRef.amount == 0) {
                revert FGOErrors.InvalidAmount();
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

            try
                IFGOChild(childRef.childContract).requestParentApproval(
                    childRef.childId,
                    reservedParentId
                )
            {} catch {
                revert FGOErrors.ChildNotAuthorized();
            }

            unchecked {
                ++i;
            }
        }

        return reservedParentId;
    }

    function createParent(
        uint256 reservedParentId,
        FGOLibrary.CreateParentParams memory params
    ) external virtual onlyDesigner returns (uint256) {
        if (reservedParentId == 0 || reservedParentId > _supply) {
            revert FGOErrors.InvalidAmount();
        }
        if (params.childReferences.length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        if (bytes(params.uri).length == 0) {
            revert FGOErrors.InvalidAmount();
        }

        if (_reservedBy[reservedParentId] != msg.sender) {
            revert FGOErrors.AddressInvalid();
        }

        for (uint256 i = 0; i < params.childReferences.length; ) {
            FGOLibrary.ChildReference memory childRef = params.childReferences[
                i
            ];

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
                    reservedParentId,
                    address(this)
                )
            returns (bool childApproves) {
                if (!childApproves) {
                    revert FGOErrors.ChildNotAuthorized();
                }
            } catch {
                revert FGOErrors.ChildNotAuthorized();
            }
            unchecked {
                ++i;
            }
        }

        _parents[reservedParentId] = FGOLibrary.ParentMetadata({
            childReferences: params.childReferences,
            uri: params.uri,
            digitalPrice: params.digitalPrice,
            physicalPrice: params.physicalPrice,
            printType: params.printType,
            availability: params.availability,
            workflow: params.workflow,
            preferredPayoutCurrency: params.preferredPayoutCurrency !=
                address(0)
                ? params.preferredPayoutCurrency
                : accessControl.PAYMENT_TOKEN(),
            digitalMarketsOpenToAll: params.digitalMarketsOpenToAll,
            physicalMarketsOpenToAll: params.physicalMarketsOpenToAll,
            authorizedMarkets: params.authorizedMarkets,
            status: FGOLibrary.ActiveStatus.ACTIVE,
            totalPurchases: 0,
            maxDigitalEditions: params.maxDigitalEditions,
            maxPhysicalEditions: params.maxPhysicalEditions,
            currentDigitalEditions: 0,
            currentPhysicalEditions: 0
        });

        if (params.authorizedMarkets.length > MAX_AUTHORIZED_ADDRESSES) {
            revert FGOErrors.BatchTooLarge();
        }

        _setAuthorizedMarkets(reservedParentId, params.authorizedMarkets);

        _mint(msg.sender, reservedParentId);

        _incrementChildUsageCounts(params.childReferences);

        delete _reservedBy[reservedParentId];

        emit ParentMinted(reservedParentId, msg.sender);

        return reservedParentId;
    }

    function reserveParentBatch(
        FGOLibrary.CreateParentParams[] memory paramsArray
    ) external virtual onlyDesigner returns (uint256[] memory) {
        uint256 len = paramsArray.length;
        if (len == 0) {
            revert FGOErrors.InvalidAmount();
        }
        if (len > 20) {
            revert FGOErrors.BatchTooLarge();
        }

        uint256[] memory reservedIds = new uint256[](len);

        for (uint256 j = 0; j < len; j++) {
            FGOLibrary.CreateParentParams memory params = paramsArray[j];

            if (params.childReferences.length == 0) {
                revert FGOErrors.InvalidAmount();
            }
            if (params.childReferences.length > 50) {
                revert FGOErrors.BatchTooLarge();
            }

            _supply++;
            _reservedBy[_supply] = msg.sender;

            for (uint256 i = 0; i < params.childReferences.length; ) {
                FGOLibrary.ChildReference memory childRef = params
                    .childReferences[i];

                if (childRef.childContract == address(0)) {
                    revert FGOErrors.AddressInvalid();
                }
                if (childRef.amount == 0) {
                    revert FGOErrors.InvalidAmount();
                }

                try
                    IFGOChild(childRef.childContract).isChildActive(
                        childRef.childId
                    )
                returns (bool isActive) {
                    if (!isActive) {
                        revert FGOErrors.ChildNotAuthorized();
                    }
                } catch {
                    revert FGOErrors.ChildNotAuthorized();
                }

                try
                    IFGOChild(childRef.childContract).requestParentApproval(
                        childRef.childId,
                        _supply
                    )
                {} catch {
                    revert FGOErrors.ChildNotAuthorized();
                }

                unchecked {
                    ++i;
                }
            }

            reservedIds[j] = _supply;
        }

        return reservedIds;
    }

    function createParentBatch(
        uint256[] memory reservedParentIds,
        FGOLibrary.CreateParentParams[] memory paramsArray
    ) external virtual onlyDesigner nonReentrant returns (uint256[] memory) {
        uint256 len = reservedParentIds.length;
        if (len == 0 || len != paramsArray.length) {
            revert FGOErrors.InvalidAmount();
        }
        if (len > 20) {
            revert FGOErrors.BatchTooLarge();
        }

        uint256[] memory createdIds = new uint256[](len);

        for (uint256 j = 0; j < len; j++) {
            uint256 reservedParentId = reservedParentIds[j];
            FGOLibrary.CreateParentParams memory params = paramsArray[j];

            if (reservedParentId == 0 || reservedParentId > _supply) {
                revert FGOErrors.InvalidAmount();
            }
            if (params.childReferences.length == 0) {
                revert FGOErrors.InvalidAmount();
            }

            if (_reservedBy[reservedParentId] != msg.sender) {
                revert FGOErrors.AddressInvalid();
            }

            for (uint256 i = 0; i < params.childReferences.length; ) {
                FGOLibrary.ChildReference memory childRef = params
                    .childReferences[i];

                try
                    IFGOChild(childRef.childContract).isChildActive(
                        childRef.childId
                    )
                returns (bool isActive) {
                    if (!isActive) {
                        revert FGOErrors.ChildNotAuthorized();
                    }
                } catch {
                    revert FGOErrors.ChildNotAuthorized();
                }

                try
                    IFGOChild(childRef.childContract).approvesParent(
                        childRef.childId,
                        reservedParentId,
                        address(this)
                    )
                returns (bool approved) {
                    if (!approved) {
                        revert FGOErrors.ChildNotAuthorized();
                    }
                } catch {
                    revert FGOErrors.ChildNotAuthorized();
                }

                unchecked {
                    ++i;
                }
            }

            _parents[reservedParentId] = FGOLibrary.ParentMetadata({
                childReferences: params.childReferences,
                uri: params.uri,
                digitalPrice: params.digitalPrice,
                physicalPrice: params.physicalPrice,
                printType: params.printType,
                availability: params.availability,
                workflow: params.workflow,
                preferredPayoutCurrency: params.preferredPayoutCurrency !=
                    address(0)
                    ? params.preferredPayoutCurrency
                    : accessControl.PAYMENT_TOKEN(),
                digitalMarketsOpenToAll: params.digitalMarketsOpenToAll,
                physicalMarketsOpenToAll: params.physicalMarketsOpenToAll,
                authorizedMarkets: params.authorizedMarkets,
                status: FGOLibrary.ActiveStatus.ACTIVE,
                totalPurchases: 0,
                maxDigitalEditions: params.maxDigitalEditions,
                maxPhysicalEditions: params.maxPhysicalEditions,
                currentDigitalEditions: 0,
                currentPhysicalEditions: 0
            });

            if (params.authorizedMarkets.length > MAX_AUTHORIZED_ADDRESSES) {
                revert FGOErrors.BatchTooLarge();
            }

            _setAuthorizedMarkets(reservedParentId, params.authorizedMarkets);

            for (uint256 i = 0; i < params.childReferences.length; i++) {
                try
                    IFGOChild(params.childReferences[i].childContract)
                        .incrementChildUsage(params.childReferences[i].childId)
                {} catch {}
            }

            _safeMint(msg.sender, reservedParentId);
            delete _reservedBy[reservedParentId];
            emit ParentMinted(reservedParentId, msg.sender);

            createdIds[j] = reservedParentId;
        }

        return createdIds;
    }

    function updateParent(
        FGOLibrary.UpdateParentParams memory params
    ) external virtual onlyDesignOwner(params.designId) {
        if (!designExists(params.designId)) {
            revert FGOErrors.NotActive();
        }

        FGOLibrary.ParentMetadata storage design = _parents[params.designId];
        if (design.totalPurchases > 0) {
            revert FGOErrors.InvalidAmount();
        }

        design.digitalPrice = params.digitalPrice;
        design.physicalPrice = params.physicalPrice;
        design.preferredPayoutCurrency = params.preferredPayoutCurrency !=
            address(0)
            ? params.preferredPayoutCurrency
            : accessControl.PAYMENT_TOKEN();
        design.digitalMarketsOpenToAll = params.digitalMarketsOpenToAll;
        design.physicalMarketsOpenToAll = params.physicalMarketsOpenToAll;

        if (params.authorizedMarkets.length > MAX_AUTHORIZED_ADDRESSES) {
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
            revert FGOErrors.NotActive();
        }

        FGOLibrary.ParentMetadata storage design = _parents[designId];
        if (design.status != FGOLibrary.ActiveStatus.ACTIVE) {
            revert FGOErrors.NotActive();
        }

        if (_authorizedMarkets[designId][market]) {
            return;
        }

        if (design.authorizedMarkets.length > MAX_AUTHORIZED_ADDRESSES) {
            revert FGOErrors.BatchTooLarge();
        }

        _authorizedMarkets[designId][market] = true;
        design.authorizedMarkets.push(market);

        emit MarketApproved(designId, market);
    }

    function revokeMarket(
        uint256 designId,
        address market
    ) external onlyDesignOwner(designId) {
        if (!designExists(designId)) {
            revert FGOErrors.NotActive();
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
            revert FGOErrors.NotActive();
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

        FGOLibrary.ParentMetadata storage design = _parents[designId];
        if (design.authorizedMarkets.length > MAX_AUTHORIZED_ADDRESSES) {
            revert FGOErrors.BatchTooLarge();
        }

        _authorizedMarkets[designId][market] = true;
        request.isPending = false;
        design.authorizedMarkets.push(market);

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

        if (design.status != FGOLibrary.ActiveStatus.ACTIVE) {
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
                    return false;
                }
            } catch {
                return false;
            }

            try
                IFGOChild(childRef.childContract).approvesParent(
                    childRef.childId,
                    designId,
                    address(this)
                )
            returns (bool childApprovesParent) {
                if (!childApprovesParent) {
                    return false;
                }
            } catch {
                return false;
            }

            try
                IFGOChild(childRef.childContract).approvesMarket(
                    childRef.childId,
                    market
                )
            returns (bool childApprovesMarket) {
                if (!childApprovesMarket) {
                    return false;
                }
            } catch {
                return false;
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
        return design.status == FGOLibrary.ActiveStatus.ACTIVE;
    }

    function disableParent(
        uint256 designId
    ) external virtual onlyDesignOwner(designId) {
        FGOLibrary.ParentMetadata storage design = _parents[designId];
        design.status = FGOLibrary.ActiveStatus.DISABLED;
        emit ParentDisabled(designId);
    }

    function enableParent(
        uint256 designId
    ) external virtual onlyDesignOwner(designId) {
        FGOLibrary.ParentMetadata storage design = _parents[designId];
        design.status = FGOLibrary.ActiveStatus.ACTIVE;
        emit ParentEnabled(designId);
    }

    function deleteParent(
        uint256 designId
    ) external virtual onlyDesignOwner(designId) {
        FGOLibrary.ParentMetadata storage design = _parents[designId];

        if (design.totalPurchases > 0) {
            revert FGOErrors.InvalidAmount();
        }

        _decrementChildUsageCounts(design.childReferences);

        design.status = FGOLibrary.ActiveStatus.DELETED;
        emit ParentDeleted(designId);
    }

    function incrementPurchases(uint256 designId, bool isPhysical) external {
        if (!designExists(designId)) {
            revert FGOErrors.NotActive();
        }

        FGOLibrary.ParentMetadata storage design = _parents[designId];
        if (design.status != FGOLibrary.ActiveStatus.ACTIVE) {
            revert FGOErrors.InvalidAmount();
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
            revert FGOErrors.InvalidAmount();
        }
        FGOLibrary.ParentMetadata storage design = _parents[tokenId];
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
            if (ownerOf(params[i].designId) != msg.sender) {
                revert FGOErrors.AddressInvalid();
            }
            this.updateParent(params[i]);
            unchecked {
                ++i;
            }
        }
    }

    function designExists(uint256 designId) public view returns (bool) {
        return _parents[designId].status == FGOLibrary.ActiveStatus.ACTIVE;
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
                revert FGOErrors.ChildNotAuthorized();
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
                revert FGOErrors.ChildNotAuthorized();
            }
            unchecked {
                ++i;
            }
        }
    }

    function getSupply() public view returns (uint256) {
        return _supply;
    }
}
