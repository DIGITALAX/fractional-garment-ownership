// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

import "./FGOAccessControl.sol";
import "./FGOLibrary.sol";
import "./FGOErrors.sol";
import "./FGOParent.sol";

contract FGODesigners {
    FGOAccessControl public accessControl;
    FGOParent public parentFGO;
    string public symbol;
    string public name;
    uint256 private _designerSupply;
    bool public isDesignerGated = true;
    
    mapping(uint256 => FGOLibrary.DesignerProfile) private _designers;
    mapping(address => uint256) private _addressToDesignerId;
    
    event DesignerProfileCreated(uint256 indexed designerId, address indexed designer);
    event DesignerProfileUpdated(uint256 indexed designerId);
    event DesignerProfileDeleted(uint256 indexed designerId);
    event DesignerGatingToggled(bool isGated);
    event DesignerWalletTransferred(uint256 indexed designerId, address oldWallet, address newWallet);
    event DesignerParentAssetsTransferred(uint256 indexed designerId, address oldWallet, address newWallet, uint256 parentTokensTransferred);
    
    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }
    
    modifier onlyApprovedDesigner() {
        if (!canCreateDesignerProfile(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }
    
    modifier onlyDesignerOwner(uint256 designerId) {
        if (_designers[designerId].designerAddress != msg.sender) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }
    
    constructor(
        address _accessControl,
        address _parentFGO
    ) {
        accessControl = FGOAccessControl(_accessControl);
        parentFGO = FGOParent(_parentFGO);
        symbol = "FGOD";
        name = "FGODesigners";
    }
    
    function toggleDesignerGating() external onlyAdmin {
        isDesignerGated = !isDesignerGated;
        emit DesignerGatingToggled(isDesignerGated);
    }
    
    function canCreateDesignerProfile(address _address) public view returns (bool) {
        if (!isDesignerGated) return true;
        return accessControl.isAdmin(_address) || accessControl.isDesigner(_address);
    }
    
    function createProfile(string memory uri) external onlyApprovedDesigner {
        if (_addressToDesignerId[msg.sender] != 0) {
            revert FGOErrors.Existing();
        }
        
        _designerSupply++;
        
        _designers[_designerSupply] = FGOLibrary.DesignerProfile({
            designerAddress: msg.sender,
            uri: uri,
            isActive: true,
            totalDesigns: 0,
            totalSales: 0,
            version: 1
        });
        
        _addressToDesignerId[msg.sender] = _designerSupply;
        
        emit DesignerProfileCreated(_designerSupply, msg.sender);
    }
    
    function updateProfile(
        uint256 designerId,
        string memory uri,
        uint256 version
    ) external onlyDesignerOwner(designerId) {
        _designers[designerId].uri = uri;
        _designers[designerId].version = version;
        emit DesignerProfileUpdated(designerId);
    }
    
    function deleteProfile(uint256 designerId) external onlyDesignerOwner(designerId) {
        delete _designers[designerId];
        delete _addressToDesignerId[msg.sender];
        emit DesignerProfileDeleted(designerId);
    }
    
    function incrementDesigns(address designerAddress) external onlyAdmin {
        uint256 designerId = _addressToDesignerId[designerAddress];
        if (designerId != 0) {
            _designers[designerId].totalDesigns++;
        }
    }
    
    function incrementSales(address designerAddress) external onlyAdmin {
        uint256 designerId = _addressToDesignerId[designerAddress];
        if (designerId != 0) {
            _designers[designerId].totalSales++;
        }
    }
    
    function setAccessControl(address _accessControl) external onlyAdmin {
        accessControl = FGOAccessControl(_accessControl);
    }
    
    function getDesigner(uint256 designerId) public view returns (FGOLibrary.DesignerProfile memory) {
        return _designers[designerId];
    }
    
    function getDesignerByAddress(address designerAddress) public view returns (FGOLibrary.DesignerProfile memory) {
        uint256 designerId = _addressToDesignerId[designerAddress];
        return _designers[designerId];
    }
    
    function getDesignerAddress(uint256 designerId) public view returns (address) {
        return _designers[designerId].designerAddress;
    }
    
    function getDesignerSupply() public view returns (uint256) {
        return _designerSupply;
    }
    
    function designerExists(uint256 designerId) public view returns (bool) {
        return _designers[designerId].designerAddress != address(0) && _designers[designerId].isActive;
    }
    
    function getDesignerIdByAddress(address designerAddress) public view returns (uint256) {
        return _addressToDesignerId[designerAddress];
    }
    
    function transferWallet(uint256 designerId, address newWallet) external onlyDesignerOwner(designerId) {
        if (newWallet == address(0)) {
            revert FGOErrors.AddressInvalid();
        }
        
        if (_addressToDesignerId[newWallet] != 0) {
            revert FGOErrors.Existing();
        }
        
        address oldWallet = _designers[designerId].designerAddress;
        
        _designers[designerId].designerAddress = newWallet;
        _addressToDesignerId[newWallet] = designerId;
        delete _addressToDesignerId[oldWallet];
        
        emit DesignerWalletTransferred(designerId, oldWallet, newWallet);
    }
    
    function transferAllParentAssets(uint256 designerId, address newWallet) external onlyDesignerOwner(designerId) {
        if (newWallet == address(0)) {
            revert FGOErrors.AddressInvalid();
        }
        
        if (_addressToDesignerId[newWallet] != 0) {
            revert FGOErrors.Existing();
        }
        
        address oldWallet = _designers[designerId].designerAddress;
        
        _designers[designerId].designerAddress = newWallet;
        _addressToDesignerId[newWallet] = designerId;
        delete _addressToDesignerId[oldWallet];
        
        uint256 totalSupply = parentFGO.totalSupply();
        uint256 tokensTransferred = 0;
        
        for (uint256 tokenId = 1; tokenId <= totalSupply; tokenId++) {
            try parentFGO.ownerOf(tokenId) returns (address owner) {
                if (parentFGO.isApprovedForAll(owner, address(this))) {
                    parentFGO.transferFrom(owner, newWallet, tokenId);
                    tokensTransferred++;
                }
            } catch {
                continue;
            }
        }
        
        emit DesignerParentAssetsTransferred(designerId, oldWallet, newWallet, tokensTransferred);
    }
}