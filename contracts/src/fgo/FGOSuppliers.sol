// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOAccessControl.sol";
import "./FGOLibrary.sol";
import "./FGOErrors.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FGOSuppliers is ReentrancyGuard {
    uint256 private _supplierSupply;
    bytes32 public infraId;
    FGOAccessControl public accessControl;
    string public symbol;
    string public name;

    mapping(uint256 => FGOLibrary.SupplierProfile) private _suppliers;
    mapping(address => uint256) private _addressToSupplierId;

    event SupplierInit(uint256 indexed supplierId, address indexed supplier);
    event SupplierCreated(uint256 indexed supplierId, address indexed supplier);
    event SupplierUpdated(uint256 indexed supplierId, address indexed supplier);
    event SupplierWalletTransferred(
        uint256 indexed supplierId,
        address oldAddress,
        address newAddress
    );
    event SupplierDeactivated(uint256 indexed supplierId);
    event SupplierReactivated(uint256 indexed supplierId);

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    modifier onlyApprovedSupplier() {
        if (
            !accessControl.canCreateChildren(msg.sender) ||
            _addressToSupplierId[msg.sender] == 0
        ) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    modifier onlySupplierOwner(uint256 supplierId) {
        if (_suppliers[supplierId].supplierAddress != msg.sender) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    modifier onlyAccessControls() {
        if (msg.sender != address(accessControl)) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    constructor(bytes32 _infraId, address _accessControl) {
        infraId = _infraId;
        accessControl = FGOAccessControl(_accessControl);
        symbol = "FGOS";
        name = "FGOSuppliers";
    }

    function initProfile(address supplier) external onlyAccessControls {
        if (_addressToSupplierId[supplier] != 0) {
            return;
        }
        if (_supplierSupply == type(uint256).max) {
            revert FGOErrors.MaxSupplyReached();
        }

        _supplierSupply++;

        _suppliers[_supplierSupply].supplierAddress = supplier;
        _suppliers[_supplierSupply].isActive = true;

        _addressToSupplierId[supplier] = _supplierSupply;

        emit SupplierInit(_supplierSupply, supplier);
    }

    function createProfile(
        uint256 version,
        string memory uri
    ) external onlyApprovedSupplier {
        if (bytes(uri).length == 0) {
            revert FGOErrors.ZeroValue();
        }
        if (_supplierSupply == type(uint256).max) {
            revert FGOErrors.MaxSupplyReached();
        }

        uint256 supplierId = _addressToSupplierId[msg.sender];

        if (bytes(_suppliers[supplierId].uri).length != 0) {
            revert FGOErrors.Unauthorized();
        }

        _suppliers[supplierId].uri = uri;
        _suppliers[supplierId].version = version;

        emit SupplierCreated(supplierId, msg.sender);
    }

    function updateProfile(
        uint256 supplierId,
        uint256 version,
        string memory newURI
    ) external onlySupplierOwner(supplierId) {
        if (bytes(newURI).length == 0) {
            revert FGOErrors.EmptyString();
        }

        _suppliers[supplierId].uri = newURI;
        _suppliers[supplierId].version = version;

        emit SupplierUpdated(supplierId, msg.sender);
    }

    function transferSupplierWallet(
        uint256 supplierId,
        address newAddress
    ) external onlySupplierOwner(supplierId) nonReentrant {
        if (newAddress == address(0)) {
            revert FGOErrors.ZeroAddress();
        }

        if (_addressToSupplierId[newAddress] != 0) {
            revert FGOErrors.AlreadyExists();
        }

        address oldAddress = _suppliers[supplierId].supplierAddress;
        _suppliers[supplierId].supplierAddress = newAddress;
        _addressToSupplierId[newAddress] = supplierId;
        delete _addressToSupplierId[oldAddress];

        accessControl.addSupplier(newAddress);

        emit SupplierWalletTransferred(supplierId, oldAddress, newAddress);
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
    ) external view returns (uint256) {
        return _addressToSupplierId[supplier];
    }

    function getSupplierProfile(
        uint256 supplierId
    ) external view returns (FGOLibrary.SupplierProfile memory) {
        return _suppliers[supplierId];
    }

    function getSupplierSupply() external view returns (uint256) {
        return _supplierSupply;
    }
}
