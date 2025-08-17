// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOAccessControl.sol";
import "./FGOLibrary.sol";
import "./FGOErrors.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FGOSuppliers is ReentrancyGuard {
    FGOAccessControl public accessControl;
    mapping(address => FGOLibrary.SupplierProfile) private _supplierProfiles;
    mapping(uint256 => address) private _supplierIdToAddress;
    mapping(address => uint256) private _supplierAddressToId;
    mapping(address => uint256[]) private _childrenBySupplier;
    uint256 private _supplierSupply;

    event SupplierRegistered(address indexed supplier, uint256 indexed supplierId, string uri);
    event SupplierURIUpdated(address indexed supplier, uint256 version, string newURI);
    event SupplierWalletTransferred(address indexed oldAddress, address indexed newAddress, uint256 supplierId, bool transferChildren);
    event SupplierDeactivated(address indexed supplier);
    event SupplierReactivated(address indexed supplier);

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    modifier onlySupplier() {
        if (!accessControl.isSupplier(msg.sender) && !accessControl.isAdmin(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    constructor(address _accessControl) {
        accessControl = FGOAccessControl(_accessControl);
    }

    function registerSupplier(string memory uri, uint256 version) external {
        if (_supplierProfiles[msg.sender].supplierAddress != address(0)) {
            revert FGOErrors.AddressInvalid();
        }

        _supplierSupply++;

        _supplierProfiles[msg.sender] = FGOLibrary.SupplierProfile({
            supplierAddress: msg.sender,
            uri: uri,
            isActive: true,
            version: version
        });

        _supplierIdToAddress[_supplierSupply] = msg.sender;
        _supplierAddressToId[msg.sender] = _supplierSupply;

        emit SupplierRegistered(msg.sender, _supplierSupply, uri);
    }

    function updateSupplierURI(string memory newURI, uint256 version) external onlySupplier {
        if (_supplierProfiles[msg.sender].supplierAddress == address(0)) {
            revert FGOErrors.AddressInvalid();
        }

        _supplierProfiles[msg.sender].uri = newURI;
        _supplierProfiles[msg.sender].version = version;

        emit SupplierURIUpdated(msg.sender, version, newURI);
    }

    function transferSupplierWallet(address newAddress, bool transferChildren) external onlySupplier nonReentrant {
        if (_supplierProfiles[newAddress].supplierAddress != address(0)) {
            revert FGOErrors.AddressInvalid();
        }

        uint256 supplierId = _supplierAddressToId[msg.sender];
        
        _supplierProfiles[newAddress] = _supplierProfiles[msg.sender];
        _supplierProfiles[newAddress].supplierAddress = newAddress;
        
        _supplierIdToAddress[supplierId] = newAddress;
        _supplierAddressToId[newAddress] = supplierId;

        if (transferChildren) {
            _childrenBySupplier[newAddress] = _childrenBySupplier[msg.sender];
            delete _childrenBySupplier[msg.sender];
        }
        
        delete _supplierProfiles[msg.sender];
        delete _supplierAddressToId[msg.sender];

        emit SupplierWalletTransferred(msg.sender, newAddress, supplierId, transferChildren);
    }

    function deactivateSupplier(address supplier) external onlyAdmin {
        _supplierProfiles[supplier].isActive = false;
        emit SupplierDeactivated(supplier);
    }

    function reactivateSupplier(address supplier) external onlyAdmin {
        _supplierProfiles[supplier].isActive = true;
        emit SupplierReactivated(supplier);
    }

    function addChildToSupplier(address supplier, uint256 childId) external {
        if (!accessControl.isAdmin(msg.sender) && 
            !accessControl.canCreateChildren(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        
        _childrenBySupplier[supplier].push(childId);
    }

    function setAccessControl(address _accessControl) external onlyAdmin {
        accessControl = FGOAccessControl(_accessControl);
    }

    function supplierExists(uint256 supplierId) public view returns (bool) {
        return _supplierIdToAddress[supplierId] != address(0);
    }

    function getSupplierAddress(uint256 supplierId) public view returns (address) {
        return _supplierIdToAddress[supplierId];
    }

    function getSupplierId(address supplier) public view returns (uint256) {
        return _supplierAddressToId[supplier];
    }

    function getSupplierProfile(address supplier) public view returns (FGOLibrary.SupplierProfile memory) {
        return _supplierProfiles[supplier];
    }

    function getSupplierURI(address supplier) public view returns (string memory) {
        return _supplierProfiles[supplier].uri;
    }

    function getSupplierVersion(address supplier) public view returns (uint256) {
        return _supplierProfiles[supplier].version;
    }

    function isSupplierActive(address supplier) public view returns (bool) {
        return _supplierProfiles[supplier].isActive;
    }

    function getSupplierSupply() public view returns (uint256) {
        return _supplierSupply;
    }

    function getSupplierChildren(address supplier) public view returns (uint256[] memory) {
        return _childrenBySupplier[supplier];
    }

    function getSupplierChildrenCount(address supplier) public view returns (uint256) {
        return _childrenBySupplier[supplier].length;
    }

    function isValidSupplier(address supplier) public view returns (bool) {
        return _supplierProfiles[supplier].supplierAddress != address(0) && 
               _supplierProfiles[supplier].isActive;
    }
}