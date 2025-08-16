// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;
import "./FGOErrors.sol";

contract FGOAccessControl {
    string public symbol;
    string public name;
    bool public isDesignerGated = true;
    bool public isSupplierGated = true;
    bool public isMarketGated = true;
    bool public adminControlRevoked = false;

    mapping(address => bool) private _admins;
    mapping(address => bool) private _designers;
    mapping(address => bool) private _suppliers;
    mapping(address => bool) private _fulfillers;
    mapping(address => bool) private _authorizedMarkets;

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
    event MarketGatingToggled(bool isGated);
    event MarketAuthorized(address indexed market, bool status);
    event AdminControlRevoked();

    modifier onlyAdmin() {
        if (adminControlRevoked) {
            revert FGOErrors.AddressInvalid();
        }
        if (!_admins[msg.sender]) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    modifier onlyAuthorizedMarket() {
        if (!_authorizedMarkets[msg.sender]) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    constructor() {
        _admins[msg.sender] = true;
        symbol = "FGOAC";
        name = "FGOAccessControl";
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
    
    function isAdminOrDesigner(address _address) public view returns (bool) {
        return _admins[_address] || _designers[_address];
    }
    
    function isAdminOrSupplier(address _address) public view returns (bool) {
        return _admins[_address] || _suppliers[_address];
    }
    
    function toggleDesignerGating() external onlyAdmin {
        isDesignerGated = !isDesignerGated;
        emit DesignerGatingToggled(isDesignerGated);
    }
    
    function toggleSupplierGating() external onlyAdmin {
        isSupplierGated = !isSupplierGated;
        emit SupplierGatingToggled(isSupplierGated);
    }
    
    function toggleMarketGating() external onlyAdmin {
        isMarketGated = !isMarketGated;
        emit MarketGatingToggled(isMarketGated);
    }
    
    function canCreateDesigns(address _address) public view returns (bool) {
        if (!isDesignerGated) {
            return true;
        }
        return _admins[_address] || _designers[_address];
    }
    
    function canCreateChildren(address _address) public view returns (bool) {
        if (!isSupplierGated) {
            return true;
        }
        return _admins[_address] || _suppliers[_address];
    }
    
    function authorizeMarket(address market) external onlyAdmin {
        _authorizedMarkets[market] = true;
        emit MarketAuthorized(market, true);
    }
    
    function revokeMarket(address market) external onlyAdmin {
        _authorizedMarkets[market] = false;
        emit MarketAuthorized(market, false);
    }
    
    function isAuthorizedMarket(address market) public view returns (bool) {
        if (!isMarketGated) {
            return true;
        }
        return _authorizedMarkets[market];
    }
    
    function revokeAdminControl() external onlyAdmin {
        adminControlRevoked = true;
        emit AdminControlRevoked();
    }
}
