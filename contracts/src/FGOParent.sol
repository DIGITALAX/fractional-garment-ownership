// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./FGOAccessControl.sol";
import "./FGOLibrary.sol";
import "./FGOErrors.sol";
import "./FGOBaseChild.sol";

contract FGOParent is ERC721Enumerable {
    FGOAccessControl public accessControl;
    uint256 private _supply;
    uint256 private _designSupply;
    
    mapping(uint256 => FGOLibrary.ParentMetadata) private _designTemplates;
    mapping(uint256 => uint256) private _tokenIdToDesignId;
    mapping(uint256 => uint256) private _maxEditions;
    mapping(uint256 => uint256) private _currentEditions;
    mapping(address => uint256[]) private _designerToDesigns;
    mapping(FGOLibrary.ChildType => address) private _childContracts;
    
    event DesignCreated(uint256 indexed designId, address indexed designer);
    event ParentMinted(uint256 indexed tokenId, uint256 indexed designId, address indexed designer);
    event DesignMetadataUpdated(uint256 indexed designId);
    event DesignPlacementsUpdated(uint256 indexed designId);
    event DesignWorkflowUpdated(uint256 indexed designId);
    event MaxEditionsSet(uint256 indexed designId, uint256 maxEditions);
    event BulkParentsMinted(uint256 indexed startTokenId, uint256 count, uint256 indexed designId, address indexed designer);
    event ParentDisabled(uint256 indexed designId);
    event ParentEnabled(uint256 indexed designId);
    event ParentURIUpdated(uint256 indexed designId, string newURI, uint256 version, string updateReason);
    event ParentPurchased(uint256 indexed designId);

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    modifier onlyAdminOrDesigner() {
        if (!accessControl.canCreateDesigns(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    constructor(address _accessControl) ERC721("FGOParent", "FGOP") {
        accessControl = FGOAccessControl(_accessControl);
    }

    function createDesign(
        FGOLibrary.ChildPlacement[] memory placements,
        string memory uri,
        uint256 price,
        uint8 printType,
        FGOLibrary.ParentType parentType,
        FGOLibrary.FulfillmentWorkflow memory workflow,
        uint256 maxEditions,
        address[] memory acceptedCurrencies,
        uint256 minPrice
    ) external onlyAdminOrDesigner returns (uint256) {
        if (parentType != FGOLibrary.ParentType.DIGITAL_ONLY && workflow.steps.length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        
        uint256 totalBasisPoints = 0;
        for (uint256 i = 0; i < workflow.steps.length; i++) {
            totalBasisPoints += workflow.steps[i].paymentBasisPoints;
            
            uint256 subTotalBasisPoints = 0;
            for (uint256 j = 0; j < workflow.steps[i].subPerformers.length; j++) {
                subTotalBasisPoints += workflow.steps[i].subPerformers[j].splitBasisPoints;
            }
            
            if (workflow.steps[i].subPerformers.length > 0 && subTotalBasisPoints != 10000) {
                revert FGOErrors.InvalidAmount();
            }
        }
        
        if (workflow.steps.length > 0 && totalBasisPoints != 10000) {
            revert FGOErrors.InvalidAmount();
        }
        
        _designSupply++;
        _supply++;
        
        _designTemplates[_designSupply] = FGOLibrary.ParentMetadata({
            placements: placements,
            uri: uri,
            price: price,
            printType: printType,
            parentType: parentType,
            workflow: workflow,
            acceptedCurrencies: acceptedCurrencies,
            minPrice: minPrice,
            acceptedMarkets: new address[](0),
            status: FGOLibrary.ParentStatus.ACTIVE,
            uriVersion: 1,
            totalPurchases: 0,
            uriHistory: new FGOLibrary.URIVersion[](0)
        });
        
        _designTemplates[_designSupply].uriHistory.push(FGOLibrary.URIVersion({
            uri: uri,
            version: 1,
            timestamp: block.timestamp,
            updateReason: "Initial creation"
        }));
        
        for (uint256 i = 0; i < placements.length; i++) {
            if (_childContracts[placements[i].childType] != address(0)) {
                FGOBaseChild(_childContracts[placements[i].childType]).incrementUsageCount(placements[i].childId);
            }
        }
        
        _maxEditions[_designSupply] = maxEditions;
        _designerToDesigns[msg.sender].push(_designSupply);
        
        _mint(msg.sender, _supply);
        _tokenIdToDesignId[_supply] = _designSupply;
        _currentEditions[_designSupply]++;
        
        emit DesignCreated(_designSupply, msg.sender);
        emit ParentMinted(_supply, _designSupply, msg.sender);
        
        return _supply;
    }

    function mintCatalogItem(uint256 designId) external onlyAdminOrDesigner returns (uint256) {
        if (_designTemplates[designId].placements.length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        
        if (_maxEditions[designId] > 0 && _currentEditions[designId] >= _maxEditions[designId]) {
            revert FGOErrors.MaxSupplyReached();
        }
        
        _supply++;
        _currentEditions[designId]++;
        
        _mint(msg.sender, _supply);
        _tokenIdToDesignId[_supply] = designId;
        
        emit ParentMinted(_supply, designId, msg.sender);
        return _supply;
    }

    function updateDesignMetadata(
        uint256 designId,
        string memory uri,
        uint256 price
    ) external onlyAdminOrDesigner {
        if (_designTemplates[designId].placements.length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        
        if (_currentEditions[designId] > 0) {
            revert FGOErrors.InvalidAmount();
        }
        
        _designTemplates[designId].uri = uri;
        _designTemplates[designId].price = price;
        
        emit DesignMetadataUpdated(designId);
    }

    function updateDesignPlacements(
        uint256 designId,
        FGOLibrary.ChildPlacement[] memory newPlacements
    ) external onlyAdminOrDesigner {
        if (_designTemplates[designId].placements.length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        
        if (_currentEditions[designId] > 0) {
            revert FGOErrors.InvalidAmount();
        }
        
        delete _designTemplates[designId].placements;
        
        for (uint256 i = 0; i < newPlacements.length; i++) {
            _designTemplates[designId].placements.push(newPlacements[i]);
        }
        
        emit DesignPlacementsUpdated(designId);
    }
    
    function updateDesignWorkflow(
        uint256 designId,
        FGOLibrary.FulfillmentWorkflow memory newWorkflow
    ) external onlyAdminOrDesigner {
        if (_designTemplates[designId].placements.length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        
        if (_designTemplates[designId].parentType != FGOLibrary.ParentType.DIGITAL_ONLY && newWorkflow.steps.length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        
        uint256 totalBasisPoints = 0;
        for (uint256 i = 0; i < newWorkflow.steps.length; i++) {
            totalBasisPoints += newWorkflow.steps[i].paymentBasisPoints;
            
            uint256 subTotalBasisPoints = 0;
            for (uint256 j = 0; j < newWorkflow.steps[i].subPerformers.length; j++) {
                subTotalBasisPoints += newWorkflow.steps[i].subPerformers[j].splitBasisPoints;
            }
            
            if (newWorkflow.steps[i].subPerformers.length > 0 && subTotalBasisPoints != 10000) {
                revert FGOErrors.InvalidAmount();
            }
        }
        
        if (totalBasisPoints != 10000) {
            revert FGOErrors.InvalidAmount();
        }
        
        _designTemplates[designId].workflow = newWorkflow;
        
        emit DesignWorkflowUpdated(designId);
    }

    function setMaxEditions(uint256 designId, uint256 maxEditions) external onlyAdmin {
        if (maxEditions < _currentEditions[designId]) {
            revert FGOErrors.InvalidAmount();
        }
        
        _maxEditions[designId] = maxEditions;
        emit MaxEditionsSet(designId, maxEditions);
    }

    function setAccessControl(address _accessControl) external onlyAdmin {
        accessControl = FGOAccessControl(_accessControl);
    }

    function getDesignSupply() public view returns (uint256) {
        return _designSupply;
    }

    function getTokenSupply() public view returns (uint256) {
        return _supply;
    }

    function getDesignTemplate(uint256 designId) public view returns (FGOLibrary.ParentMetadata memory) {
        return _designTemplates[designId];
    }

    function getParentDesignId(uint256 tokenId) public view returns (uint256) {
        return _tokenIdToDesignId[tokenId];
    }

    function getParentPlacements(uint256 tokenId) public view returns (FGOLibrary.ChildPlacement[] memory) {
        uint256 designId = _tokenIdToDesignId[tokenId];
        return _designTemplates[designId].placements;
    }

    function getParentPrice(uint256 tokenId) public view returns (uint256) {
        uint256 designId = _tokenIdToDesignId[tokenId];
        return _designTemplates[designId].price;
    }

    function getParentURI(uint256 tokenId) public view returns (string memory) {
        uint256 designId = _tokenIdToDesignId[tokenId];
        return _designTemplates[designId].uri;
    }

    function getParentType(uint256 tokenId) public view returns (FGOLibrary.ParentType) {
        uint256 designId = _tokenIdToDesignId[tokenId];
        return _designTemplates[designId].parentType;
    }

    function getParentWorkflow(uint256 tokenId) public view returns (FGOLibrary.FulfillmentWorkflow memory) {
        uint256 designId = _tokenIdToDesignId[tokenId];
        return _designTemplates[designId].workflow;
    }

    function getParentAcceptedCurrencies(uint256 tokenId) public view returns (address[] memory) {
        uint256 designId = _tokenIdToDesignId[tokenId];
        return _designTemplates[designId].acceptedCurrencies;
    }

    function getParentMinPrice(uint256 tokenId) public view returns (uint256) {
        uint256 designId = _tokenIdToDesignId[tokenId];
        return _designTemplates[designId].minPrice;
    }

    function getMaxEditions(uint256 designId) public view returns (uint256) {
        return _maxEditions[designId];
    }

    function getCurrentEditions(uint256 designId) public view returns (uint256) {
        return _currentEditions[designId];
    }

    function getAvailableEditions(uint256 designId) public view returns (uint256) {
        if (_maxEditions[designId] == 0) return type(uint256).max;
        return _maxEditions[designId] - _currentEditions[designId];
    }

    function getDesignerDesigns(address designer) public view returns (uint256[] memory) {
        return _designerToDesigns[designer];
    }

    function designExists(uint256 designId) public view returns (bool) {
        return _designTemplates[designId].placements.length > 0;
    }

    function canMintEdition(uint256 designId) public view returns (bool) {
        if (!designExists(designId)) return false;
        if (_maxEditions[designId] == 0) return true;
        return _currentEditions[designId] < _maxEditions[designId];
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        uint256 designId = _tokenIdToDesignId[tokenId];
        return _designTemplates[designId].uri;
    }
    
    function mintCatalogItemsBatch(uint256 designId, uint256 quantity) external onlyAdminOrDesigner returns (uint256[] memory) {
        if (_designTemplates[designId].placements.length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        
        if (_maxEditions[designId] > 0 && _currentEditions[designId] + quantity > _maxEditions[designId]) {
            revert FGOErrors.MaxSupplyReached();
        }
        
        uint256[] memory tokenIds = new uint256[](quantity);
        uint256 startTokenId = _supply + 1;
        
        for (uint256 i = 0; i < quantity; i++) {
            _supply++;
            _currentEditions[designId]++;
            
            _mint(msg.sender, _supply);
            _tokenIdToDesignId[_supply] = designId;
            tokenIds[i] = _supply;
            
            emit ParentMinted(_supply, designId, msg.sender);
        }
        
        emit BulkParentsMinted(startTokenId, quantity, designId, msg.sender);
        return tokenIds;
    }
    
    function setChildContract(FGOLibrary.ChildType childType, address contractAddress) external onlyAdmin {
        _childContracts[childType] = contractAddress;
    }
    
    function disableParent(uint256 designId) external onlyAdminOrDesigner {
        if (_designTemplates[designId].placements.length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        
        _designTemplates[designId].status = FGOLibrary.ParentStatus.DISABLED;
        emit ParentDisabled(designId);
    }
    
    function enableParent(uint256 designId) external onlyAdminOrDesigner {
        if (_designTemplates[designId].placements.length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        
        _designTemplates[designId].status = FGOLibrary.ParentStatus.ACTIVE;
        emit ParentEnabled(designId);
    }
    
    function updateParentURI(uint256 designId, string memory newURI, string memory updateReason) external onlyAdminOrDesigner {
        if (_designTemplates[designId].placements.length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        
        _designTemplates[designId].uriVersion++;
        _designTemplates[designId].uri = newURI;
        
        _designTemplates[designId].uriHistory.push(FGOLibrary.URIVersion({
            uri: newURI,
            version: _designTemplates[designId].uriVersion,
            timestamp: block.timestamp,
            updateReason: updateReason
        }));
        
        emit ParentURIUpdated(designId, newURI, _designTemplates[designId].uriVersion, updateReason);
    }
    
    function incrementParentPurchases(uint256 designId) external {
        if (!accessControl.isAuthorizedMarket(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        
        _designTemplates[designId].totalPurchases++;
        emit ParentPurchased(designId);
    }
    
    function canDeleteParent(uint256 designId) public view returns (bool) {
        return _designTemplates[designId].placements.length > 0 && 
               _designTemplates[designId].totalPurchases == 0;
    }
    
    function deleteParent(uint256 designId) external onlyAdminOrDesigner {
        if (!canDeleteParent(designId)) {
            revert FGOErrors.InvalidAmount(); 
        }
        
        FGOLibrary.ChildPlacement[] memory placements = _designTemplates[designId].placements;
        for (uint256 i = 0; i < placements.length; i++) {
            if (_childContracts[placements[i].childType] != address(0)) {
                FGOBaseChild(_childContracts[placements[i].childType]).decrementUsageCount(placements[i].childId);
            }
        }
        
        _designTemplates[designId].status = FGOLibrary.ParentStatus.DELETED;
    }
    
    function getParentStatus(uint256 designId) public view returns (FGOLibrary.ParentStatus) {
        return _designTemplates[designId].status;
    }
    
    function getParentURIVersion(uint256 designId) public view returns (uint256) {
        return _designTemplates[designId].uriVersion;
    }
    
    function getParentTotalPurchases(uint256 designId) public view returns (uint256) {
        return _designTemplates[designId].totalPurchases;
    }
    
    function getParentURIHistory(uint256 designId) public view returns (FGOLibrary.URIVersion[] memory) {
        return _designTemplates[designId].uriHistory;
    }
    
    function isParentActive(uint256 designId) public view returns (bool) {
        return _designTemplates[designId].status == FGOLibrary.ParentStatus.ACTIVE;
    }
}