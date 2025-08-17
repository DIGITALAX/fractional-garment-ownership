// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./FGOAccessControl.sol";
import "./FGOLibrary.sol";
import "./FGOErrors.sol";

abstract contract FGOBaseParent is ERC721Enumerable {
    FGOAccessControl public accessControl;
    uint256 internal _supply;
    string public collectionURI;

    mapping(uint256 => FGOLibrary.ParentMetadata) internal _designTemplates;
    mapping(uint256 => uint256) internal _tokenIdToDesignId;
    mapping(address => uint256[]) internal _designerToDesigns;
    mapping(uint256 => address) internal _designToDesigner;

    event ParentMinted(uint256 indexed tokenId, uint256 indexed designId, address indexed designer);
    event ParentUpdated(uint256 indexed designId);
    event ParentDisabled(uint256 indexed designId);
    event ParentEnabled(uint256 indexed designId);
    event ParentPurchased(uint256 indexed designId, bool indexed physical);

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    modifier onlyDesigner() {
        if (!accessControl.canCreateDesigns(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    modifier onlyDesignOwner(uint256 designId) {
        if (_designToDesigner[designId] != msg.sender) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    modifier onlyAuthorizedMarket() {
        if (!accessControl.isAuthorizedMarket(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    constructor(
        address _accessControl,
        string memory _name,
        string memory _symbol,
        string memory _collectionURI
    ) ERC721(_name, _symbol) {
        accessControl = FGOAccessControl(_accessControl);
        collectionURI = _collectionURI;
    }

    function createParent(
        FGOLibrary.CreateParentParams memory params
    ) external virtual onlyDesigner returns (uint256) {
        if (
            params.parentType != FGOLibrary.ParentType.DIGITAL_ONLY &&
            params.workflow.steps.length == 0
        ) {
            revert FGOErrors.InvalidAmount();
        }

        uint256 totalBasisPoints = 0;
        for (uint256 i = 0; i < params.workflow.steps.length; i++) {
            totalBasisPoints += params.workflow.steps[i].paymentBasisPoints;
        }

        if (params.workflow.steps.length > 0 && totalBasisPoints != 10000) {
            revert FGOErrors.InvalidAmount();
        }

        if (params.childReferences.length == 0) {
            revert FGOErrors.InvalidAmount();
        }

        _supply++;

        _designTemplates[_supply] = FGOLibrary.ParentMetadata({
            childReferences: params.childReferences,
            uri: params.uri,
            price: params.price,
            printType: params.printType,
            parentType: params.parentType,
            workflow: params.workflow,
            preferredPayoutCurrency: params.preferredPayoutCurrency != address(0) 
                ? params.preferredPayoutCurrency 
                : accessControl.PAYMENT_TOKEN(),
            acceptedMarkets: new address[](0),
            status: FGOLibrary.ParentStatus.ACTIVE,
            totalPurchases: 0,
            maxDigitalEditions: params.maxDigitalEditions,
            maxPhysicalEditions: params.maxPhysicalEditions,
            currentDigitalEditions: 0,
            currentPhysicalEditions: 0
        });

        _designerToDesigns[msg.sender].push(_supply);
        _designToDesigner[_supply] = msg.sender;

        uint256 tokenId = totalSupply() + 1;
        _mint(msg.sender, tokenId);
        _tokenIdToDesignId[tokenId] = _supply;

        emit ParentMinted(tokenId, _supply, msg.sender);

        return _supply;
    }

    function updateParent(
        uint256 designId,
        uint256 price,
        address preferredPayoutCurrency,
        address[] memory acceptedMarkets
    ) external virtual onlyDesignOwner(designId) {
        if (_designTemplates[designId].totalPurchases > 0) {
            revert FGOErrors.InvalidAmount();
        }

        _designTemplates[designId].price = price;
        _designTemplates[designId].preferredPayoutCurrency = preferredPayoutCurrency != address(0) 
            ? preferredPayoutCurrency 
            : accessControl.PAYMENT_TOKEN();
        _designTemplates[designId].acceptedMarkets = acceptedMarkets;

        emit ParentUpdated(designId);
    }

    function incrementParentPurchases(
        uint256 designId,
        bool isPhysical
    ) external virtual onlyAuthorizedMarket {
        _designTemplates[designId].totalPurchases++;

        if (isPhysical) {
            _designTemplates[designId].currentPhysicalEditions++;
        } else {
            _designTemplates[designId].currentDigitalEditions++;
        }

        emit ParentPurchased(designId, isPhysical);
    }

    function getParentChildReferences(
        uint256 designId
    ) external view virtual returns (FGOLibrary.ChildReference[] memory) {
        return _designTemplates[designId].childReferences;
    }

    function getParentPrice(uint256 tokenId) external view virtual returns (uint256) {
        uint256 designId = _tokenIdToDesignId[tokenId];
        return _designTemplates[designId].price;
    }

    function getParentType(uint256 tokenId) external view virtual returns (FGOLibrary.ParentType) {
        uint256 designId = _tokenIdToDesignId[tokenId];
        return _designTemplates[designId].parentType;
    }

    function getParentDesignId(uint256 tokenId) external view virtual returns (uint256) {
        return _tokenIdToDesignId[tokenId];
    }

    function getParentPreferredPayoutCurrency(uint256 tokenId) external view virtual returns (address) {
        uint256 designId = _tokenIdToDesignId[tokenId];
        return _designTemplates[designId].preferredPayoutCurrency;
    }

    function canPurchaseDigital(uint256 designId) external view virtual returns (bool) {
        if (_designTemplates[designId].maxDigitalEditions == 0) return true;
        return _designTemplates[designId].currentDigitalEditions < _designTemplates[designId].maxDigitalEditions;
    }

    function canPurchasePhysical(uint256 designId) external view virtual returns (bool) {
        if (_designTemplates[designId].maxPhysicalEditions == 0) return true;
        return _designTemplates[designId].currentPhysicalEditions < _designTemplates[designId].maxPhysicalEditions;
    }

    function getCurrentDigitalEditions(uint256 designId) external view virtual returns (uint256) {
        return _designTemplates[designId].currentDigitalEditions;
    }

    function getCurrentPhysicalEditions(uint256 designId) external view virtual returns (uint256) {
        return _designTemplates[designId].currentPhysicalEditions;
    }

    function isParentActive(uint256 designId) external view virtual returns (bool) {
        return _designTemplates[designId].status == FGOLibrary.ParentStatus.ACTIVE;
    }

    function disableParent(uint256 designId) external virtual onlyDesignOwner(designId) {
        _designTemplates[designId].status = FGOLibrary.ParentStatus.DISABLED;
        emit ParentDisabled(designId);
    }

    function enableParent(uint256 designId) external virtual onlyDesignOwner(designId) {
        _designTemplates[designId].status = FGOLibrary.ParentStatus.ACTIVE;
        emit ParentEnabled(designId);
    }

    function parentAcceptsMarket(uint256 designId, address market) external view virtual returns (bool) {
        address[] memory acceptedMarkets = _designTemplates[designId].acceptedMarkets;
        
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

    function setAccessControl(address _accessControl) external onlyAdmin {
        accessControl = FGOAccessControl(_accessControl);
    }

    function getDesignerDesigns(address designer) external view returns (uint256[] memory) {
        return _designerToDesigns[designer];
    }

    function getDesignTemplate(uint256 designId) external view returns (FGOLibrary.ParentMetadata memory) {
        return _designTemplates[designId];
    }

    function getParentWorkflow(uint256 tokenId) external view returns (FGOLibrary.FulfillmentWorkflow memory) {
        uint256 designId = _tokenIdToDesignId[tokenId];
        return _designTemplates[designId].workflow;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) {
            revert FGOErrors.InvalidChild();
        }
        uint256 designId = _tokenIdToDesignId[tokenId];
        return _designTemplates[designId].uri;
    }

    function _getParentType() internal pure virtual returns (string memory);
}