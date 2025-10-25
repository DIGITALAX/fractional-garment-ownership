// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;
import "./FGOErrors.sol";
import "../interfaces/IFGOContracts.sol";

contract FGOAccessControl {
    bytes32 public infraId;
    address public PAYMENT_TOKEN;
    bool public isPaymentTokenLocked;
    bool public isDesignerGated;
    bool public isSupplierGated;
    bool public adminControlRevoked;
    address public factory;
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
            revert FGOErrors.Unauthorized();
        }
        if (!_admins[msg.sender]) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    modifier infraActive() {
        if (
            factory != address(0) &&
            !IFGOFactory(factory).isInfrastructureActive(infraId)
        ) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    constructor(
        bytes32 _infraId,
        address _paymentToken,
        address _admin,
        address _factory
    ) {
        _admins[_admin] = true;
        symbol = "FGOAC";
        name = "FGOAccessControl";
        PAYMENT_TOKEN = _paymentToken;
        factory = _factory;
        infraId = _infraId;
        isPaymentTokenLocked = false;
        isDesignerGated = true;
        isSupplierGated = true;
        adminControlRevoked = false;
    }

    function addAdmin(address admin) external onlyAdmin infraActive {
        if (_admins[admin]) {
            revert FGOErrors.AlreadyExists();
        }
        _admins[admin] = true;
        emit AdminAdded(admin);
    }

    function removeAdmin(address admin) external onlyAdmin infraActive {
        if (admin == msg.sender) {
            revert FGOErrors.CantRemoveSelf();
        }
        if (!_admins[admin]) {
            revert FGOErrors.Unauthorized();
        }
        _admins[admin] = false;
        emit AdminRemoved(admin);
    }

    function addDesigner(address designer) external onlyAdmin infraActive {
        if (_designers[designer]) {
            revert FGOErrors.AlreadyExists();
        }
        _designers[designer] = true;
        emit DesignerAdded(designer);
    }

    function removeDesigner(address designer) external onlyAdmin infraActive {
        if (!_designers[designer]) {
            revert FGOErrors.Unauthorized();
        }
        _designers[designer] = false;
        emit DesignerRemoved(designer);
    }

    function addSupplier(address supplier) external onlyAdmin infraActive {
        if (_suppliers[supplier]) {
            revert FGOErrors.AlreadyExists();
        }
        _suppliers[supplier] = true;
        emit SupplierAdded(supplier);
    }

    function removeSupplier(address supplier) external onlyAdmin infraActive {
        if (!_suppliers[supplier]) {
            revert FGOErrors.Unauthorized();
        }
        _suppliers[supplier] = false;
        emit SupplierRemoved(supplier);
    }

    function addFulfiller(address fulfiller) external onlyAdmin infraActive {
        if (_fulfillers[fulfiller]) {
            revert FGOErrors.AlreadyExists();
        }
        _fulfillers[fulfiller] = true;
        emit FulfillerAdded(fulfiller);
    }

    function removeFulfiller(address fulfiller) external onlyAdmin infraActive {
        if (!_fulfillers[fulfiller]) {
            revert FGOErrors.Unauthorized();
        }
        _fulfillers[fulfiller] = false;
        emit FulfillerRemoved(fulfiller);
    }

    function isAdmin(address _address) public view returns (bool) {
        return _admins[_address];
    }

    function isDesigner(address _address) public view returns (bool) {
        if (!isDesignerGated) {
            return true;
        }
        return _designers[_address];
    }

    function isSupplier(address _address) public view returns (bool) {
        if (!isSupplierGated) {
            return true;
        }
        return _suppliers[_address];
    }

    function isFulfiller(address _address) public view returns (bool) {
        return _fulfillers[_address];
    }

    function toggleDesignerGating() external onlyAdmin infraActive {
        isDesignerGated = !isDesignerGated;
        emit DesignerGatingToggled(isDesignerGated);
    }

    function toggleSupplierGating() external onlyAdmin infraActive {
        isSupplierGated = !isSupplierGated;
        emit SupplierGatingToggled(isSupplierGated);
    }

    function canCreateParents(address _address) public view returns (bool) {
        if (
            factory != address(0) &&
            !IFGOFactory(factory).isInfrastructureActive(infraId)
        ) {
            return false;
        }
        if (!isDesignerGated) {
            return true;
        }
        return _designers[_address];
    }

    function canCreateChildren(address _address) public view returns (bool) {
        if (
            factory != address(0) &&
            !IFGOFactory(factory).isInfrastructureActive(infraId)
        ) {
            return false;
        }
        if (!isSupplierGated) {
            return true;
        }
        return _suppliers[_address];
    }

    function updatePaymentToken(
        address _newToken
    ) external onlyAdmin infraActive {
        if (isPaymentTokenLocked) {
            revert FGOErrors.NotApproved();
        }
        if (_newToken == address(0)) {
            revert FGOErrors.Unauthorized();
        }
        PAYMENT_TOKEN = _newToken;
        emit PaymentTokenUpdated(_newToken);
    }

    function lockPaymentToken() external onlyAdmin infraActive {
        isPaymentTokenLocked = true;
        emit PaymentTokenLocked();
    }

    function revokeAdminControl() external onlyAdmin infraActive {
        adminControlRevoked = true;
        isPaymentTokenLocked = true;
        emit AdminRevoked();
        emit PaymentTokenLocked();
    }
}
