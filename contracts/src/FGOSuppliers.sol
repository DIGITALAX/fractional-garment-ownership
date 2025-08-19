// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOAccessControl.sol";
import "./FGOLibrary.sol";
import "./FGOErrors.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FGOSuppliers is ReentrancyGuard {
    uint256 private _supplierSupply;
    string public symbol;
    string public name;
    FGOAccessControl public accessControl;

    mapping(uint256 => FGOLibrary.SupplierProfile) private _suppliers;
    mapping(address => uint256) private _addressToSupplierId;

    event SupplierRegistered(
        uint256 indexed supplierId,
        address indexed supplier
    );
    event SupplierUpdated(uint256 indexed supplierId, address indexed supplier);
    event SupplierWalletTransferred(
        address indexed oldAddress,
        address indexed newAddress,
        uint256 supplierId
    );
    event SupplierDeactivated(uint256 indexed supplier);
    event SupplierReactivated(uint256 indexed supplier);

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    modifier onlyApprovedSupplier() {
        if (!accessControl.canCreateChildren(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    modifier onlySupplierOwner(uint256 supplierId) {
        if (_suppliers[supplierId].supplierAddress != msg.sender) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    constructor(address _accessControl) {
        accessControl = FGOAccessControl(_accessControl);
        symbol = "FGOS";
        name = "FGOSuppliers";
    }

    function createProfile(
        uint256 version,
        string memory uri
    ) external onlyApprovedSupplier {
        if (_addressToSupplierId[msg.sender] != 0) {
            revert FGOErrors.Existing();
        }
        if (bytes(uri).length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        if (_supplierSupply == type(uint256).max) {
            revert FGOErrors.MaxSupplyReached();
        }

        _supplierSupply++;

        _suppliers[_supplierSupply] = FGOLibrary.SupplierProfile({
            supplierAddress: msg.sender,
            uri: uri,
            isActive: true,
            version: version
        });

        _addressToSupplierId[msg.sender] = _supplierSupply;

        emit SupplierRegistered(_supplierSupply, msg.sender);
    }

    function updateProfile(
        uint256 supplierId,
        uint256 version,
        string memory newURI
    ) external onlySupplierOwner(supplierId) {
        if (bytes(newURI).length == 0) {
            revert FGOErrors.InvalidAmount();
        }

        _suppliers[supplierId].uri = newURI;
        _suppliers[supplierId].version = version;

        emit SupplierUpdated(supplierId, msg.sender);
    }

    function transferSupplierWallet(
        uint256 supplierId,
        address newAddress
    ) external onlySupplierOwner(supplierId) nonReentrant {
        _suppliers[supplierId].supplierAddress = newAddress;

        _addressToSupplierId[newAddress] = supplierId;

        emit SupplierWalletTransferred(msg.sender, newAddress, supplierId);
    }

    function deactivateProfile(
        uint256 supplierId
    ) external onlySupplierOwner(supplierId) {
        _suppliers[supplierId].isActive = false;
        emit SupplierDeactivated(supplierId);
    }

    function reactivateProfile(
        uint256 supplierId
    ) external onlySupplierOwner(supplierId) {
        _suppliers[supplierId].isActive = true;
        emit SupplierReactivated(supplierId);
    }

    function setAccessControl(address _accessControl) external onlyAdmin {
        accessControl = FGOAccessControl(_accessControl);
    }

    function getSupplierIdByAddress(
        address supplier
    ) public view returns (uint256) {
        return _addressToSupplierId[supplier];
    }

    function getSupplierProfile(
        uint256 supplierId
    ) public view returns (FGOLibrary.SupplierProfile memory) {
        return _suppliers[supplierId];
    }

    function getSupplierSupply() public view returns (uint256) {
        return _supplierSupply;
    }
}
