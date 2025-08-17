// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./FGOAccessControl.sol";
import "./FGOLibrary.sol";
import "./FGOCoinOpParent.sol";
import "./FGOErrors.sol";

contract CustomCompositeNFT is ERC721Enumerable {
    FGOAccessControl public accessControl;
    address public parentFGO;
    uint256 private _supply;
    mapping(address => bool) public authorizedMarkets;

    mapping(uint256 => string) private _tokenIdURI;
    mapping(uint256 => FGOLibrary.CompositeMetadata) private _compositeMetadata;

    event TokenMinted(address indexed buyer, uint256 indexed tokenId, uint256 indexed parentId);

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    modifier onlyAuthorizedMarket() {
        if (!authorizedMarkets[msg.sender]) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    constructor(address _accessControl) ERC721("CustomCompositeNFT", "POSE") {
        accessControl = FGOAccessControl(_accessControl);
    }

    function mint(
        string memory _uri,
        address buyer,
        uint256 parentTokenId,
        bool isPhysicalPurchase,
        uint256[] memory ownedChildIds,
        uint256 workflowExecutionId
    ) public onlyAuthorizedMarket returns (uint256) {
        _supply++;

        _safeMint(buyer, _supply);
        _tokenIdURI[_supply] = _uri;
        
        FGOLibrary.CompositeStatus status = isPhysicalPurchase ? 
            FGOLibrary.CompositeStatus.PENDING : 
            FGOLibrary.CompositeStatus.FULFILLED;
            
        _compositeMetadata[_supply] = FGOLibrary.CompositeMetadata({
            parentTokenId: parentTokenId,
            timestamp: block.timestamp,
            isPhysicalPurchase: isPhysicalPurchase,
            ownedChildIds: ownedChildIds,
            status: status,
            workflowExecutionId: workflowExecutionId
        });

        emit TokenMinted(buyer, _supply, parentTokenId);

        return _supply;
    }

    function authorizeMarket(address _market) public onlyAdmin {
        authorizedMarkets[_market] = true;
    }
    
    function revokeMarket(address _market) public onlyAdmin {
        authorizedMarkets[_market] = false;
    }
    
    function setParentFGO(address _parentFGO) public onlyAdmin {
        parentFGO = _parentFGO;
    }

    function tokenURI(
        uint256 _tokenId
    ) public view virtual override returns (string memory) {
        return _tokenIdURI[_tokenId];
    }

    function getSupplyCount() public view returns (uint256) {
        return _supply;
    }
    
    function getCompositeParentTokenId(uint256 tokenId) public view returns (uint256) {
        return _compositeMetadata[tokenId].parentTokenId;
    }
    
    function getCompositeOriginalOwner(uint256 tokenId) public view returns (address) {
        uint256 parentTokenId = _compositeMetadata[tokenId].parentTokenId;
        if (parentTokenId == 0) {
            return address(0);
        }
        try FGOCoinOpParent(parentFGO).ownerOf(parentTokenId) returns (address owner) {
            return owner;
        } catch {
            return address(0);
        }
    }
    
    function getCompositeIsPhysical(uint256 tokenId) public view returns (bool) {
        return _compositeMetadata[tokenId].isPhysicalPurchase;
    }
    
    
    function getCompositeTimestamp(uint256 tokenId) public view returns (uint256) {
        return _compositeMetadata[tokenId].timestamp;
    }
    
    function getFullCompositeMetadata(uint256 tokenId) public view returns (FGOLibrary.CompositeMetadata memory) {
        return _compositeMetadata[tokenId];
    }
    
    function getCompositeOwnedChildIds(uint256 tokenId) public view returns (uint256[] memory) {
        return _compositeMetadata[tokenId].ownedChildIds;
    }
    
    function getCompositeDesignId(uint256 tokenId) public view returns (uint256) {
        uint256 parentTokenId = _compositeMetadata[tokenId].parentTokenId;
        return FGOCoinOpParent(parentFGO).getParentDesignId(parentTokenId);
    }
    
    function getCompositeChildReferences(uint256 tokenId) public view returns (FGOLibrary.ChildReference[] memory) {
        uint256 parentTokenId = _compositeMetadata[tokenId].parentTokenId;
        uint256 designId = FGOCoinOpParent(parentFGO).getParentDesignId(parentTokenId);
        return FGOCoinOpParent(parentFGO).getParentChildReferences(designId);
    }
    
    function fulfillComposite(uint256 tokenId, uint256[] memory mintedChildIds) external onlyAuthorizedMarket {
        require(_compositeMetadata[tokenId].status == FGOLibrary.CompositeStatus.PENDING, "Not pending");
        
        _compositeMetadata[tokenId].status = FGOLibrary.CompositeStatus.FULFILLED;
        _compositeMetadata[tokenId].ownedChildIds = mintedChildIds;
    }
    
    function refundComposite(uint256 tokenId) external onlyAuthorizedMarket {
        _compositeMetadata[tokenId].status = FGOLibrary.CompositeStatus.REFUNDED;
    }
    
    function getCompositeStatus(uint256 tokenId) public view returns (FGOLibrary.CompositeStatus) {
        return _compositeMetadata[tokenId].status;
    }
    
    function getCompositeWorkflowId(uint256 tokenId) public view returns (uint256) {
        return _compositeMetadata[tokenId].workflowExecutionId;
    }
    
    function updateCompositeWithOwnedChildren(uint256 tokenId, uint256[] memory mintedChildIds) external onlyAuthorizedMarket {
        require(_compositeMetadata[tokenId].status == FGOLibrary.CompositeStatus.PENDING, "Not pending");
        
        _compositeMetadata[tokenId].status = FGOLibrary.CompositeStatus.FULFILLED;
        _compositeMetadata[tokenId].ownedChildIds = mintedChildIds;
    }
}
