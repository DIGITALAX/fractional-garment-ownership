// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;
import "./FGOErrors.sol";

contract FGOAccessControl {
    bool public isDesignerGated = true;
    bool public isSupplierGated = true;
    bool public isPaymentTokenLocked = false;
    bool public adminControlRevoked = false;
    address public PAYMENT_TOKEN;
    string public symbol;
    string public name;

    mapping(address => bool) private _admins;
    mapping(address => bool) private _designers;
    mapping(address => bool) private _suppliers;
    mapping(address => bool) private _fulfillers;

    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event DesignerAdded(address indexed designer);
    event DesignerRemoved(address indexed designer);
    event SupplierAdded(address indexed supplier);
    event SupplierRemoved(address indexed supplier);
    event FulfillerAdded(address indexed fulfiller);
    event FulfillerRemoved(address indexed fulfiller);
    event DesignerGatingToggled(bool isGated);
    event SupplierGatingToggled(bool isGated);
    event PaymentTokenUpdated(address indexed newToken);
    event PaymentTokenLocked();
    event AdminRevoked();

    modifier onlyAdmin() {
        if (adminControlRevoked) {
            revert FGOErrors.AddressInvalid();
        }
        if (!_admins[msg.sender]) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    constructor(address _paymentToken, address _admin) {
        _admins[_admin] = true;
        symbol = "FGOAC";
        name = "FGOAccessControl";
        PAYMENT_TOKEN = _paymentToken;
        isPaymentTokenLocked = false;
    }

    function addAdmin(address admin) external onlyAdmin {
        if (_admins[admin] || admin == msg.sender) {
            revert FGOErrors.Existing();
        }
        _admins[admin] = true;
        emit AdminAdded(admin);
    }

    function removeAdmin(address admin) external onlyAdmin {
        if (admin == msg.sender) {
            revert FGOErrors.CantRemoveSelf();
        }
        if (!_admins[admin]) {
            revert FGOErrors.AddressInvalid();
        }
        _admins[admin] = false;
        emit AdminRemoved(admin);
    }

    function addDesigner(address designer) external onlyAdmin {
        if (_designers[designer] || designer == msg.sender) {
            revert FGOErrors.Existing();
        }
        _designers[designer] = true;
        emit DesignerAdded(designer);
    }

    function removeDesigner(address designer) external onlyAdmin {
        if (!_designers[designer]) {
            revert FGOErrors.AddressInvalid();
        }
        _designers[designer] = false;
        emit DesignerRemoved(designer);
    }

    function addSupplier(address supplier) external onlyAdmin {
        if (_suppliers[supplier] || supplier == msg.sender) {
            revert FGOErrors.Existing();
        }
        _suppliers[supplier] = true;
        emit SupplierAdded(supplier);
    }

    function removeSupplier(address supplier) external onlyAdmin {
        if (!_suppliers[supplier]) {
            revert FGOErrors.AddressInvalid();
        }
        _suppliers[supplier] = false;
        emit SupplierRemoved(supplier);
    }

    function addFulfiller(address fulfiller) external onlyAdmin {
        if (_fulfillers[fulfiller] || fulfiller == msg.sender) {
            revert FGOErrors.Existing();
        }
        _fulfillers[fulfiller] = true;
        emit FulfillerAdded(fulfiller);
    }

    function removeFulfiller(address fulfiller) external onlyAdmin {
        if (!_fulfillers[fulfiller]) {
            revert FGOErrors.AddressInvalid();
        }
        _fulfillers[fulfiller] = false;
        emit FulfillerRemoved(fulfiller);
    }

    function isAdmin(address _address) public view returns (bool) {
        return _admins[_address];
    }

    function isDesigner(address _address) public view returns (bool) {
        return _designers[_address];
    }

    function isSupplier(address _address) public view returns (bool) {
        return _suppliers[_address];
    }

    function isFulfiller(address _address) public view returns (bool) {
        return _fulfillers[_address];
    }

    function toggleDesignerGating() external onlyAdmin {
        isDesignerGated = !isDesignerGated;
        emit DesignerGatingToggled(isDesignerGated);
    }

    function toggleSupplierGating() external onlyAdmin {
        isSupplierGated = !isSupplierGated;
        emit SupplierGatingToggled(isSupplierGated);
    }

    function canCreateParents(address _address) public view returns (bool) {
        if (!isDesignerGated) {
            return true;
        }
        return _designers[_address];
    }

    function canCreateChildren(address _address) public view returns (bool) {
        if (!isSupplierGated) {
            return true;
        }
        return _suppliers[_address];
    }

    function updatePaymentToken(address _newToken) external onlyAdmin {
        if (isPaymentTokenLocked) {
            revert FGOErrors.InvalidAmount();
        }
        if (_newToken == address(0)) {
            revert FGOErrors.AddressInvalid();
        }
        PAYMENT_TOKEN = _newToken;
        emit PaymentTokenUpdated(_newToken);
    }

    function lockPaymentToken() external onlyAdmin {
        isPaymentTokenLocked = true;
        emit PaymentTokenLocked();
    }

    function revokeAdminControl() external onlyAdmin {
        adminControlRevoked = true;
        isPaymentTokenLocked = true;
        emit AdminRevoked();
        emit PaymentTokenLocked();
    }
}
