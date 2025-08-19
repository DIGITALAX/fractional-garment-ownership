// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

import "./FGOAccessControl.sol";
import "./FGOLibrary.sol";
import "./FGOErrors.sol";

contract FGOFulfillers {
    uint256 private _fulfillerSupply;
    string public symbol;
    string public name;
    FGOAccessControl public accessControl;

    mapping(uint256 => FGOLibrary.FulfillerProfile) private _fulfillers;
    mapping(address => uint256) private _addressToFulfillerId;

    event FulfillerProfileCreated(
        uint256 indexed fulfillerId,
        address indexed fulfiller
    );
    event FulfillerProfileUpdated(uint256 indexed fulfillerId);
    event FulfillerProfileDeleted(uint256 indexed fulfillerId);
    event FulfillerWalletTransferred(
        uint256 indexed fulfillerId,
        address oldWallet,
        address newWallet
    );
    event FulfillerProfileDeactivated(uint256 indexed fulfillerId);
    event FulfillerProfileReactivated(uint256 indexed fulfillerId);

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    modifier onlyApprovedFulfiller() {
        if (!accessControl.isFulfiller(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    modifier onlyFulfillerOwner(uint256 fulfillerId) {
        if (_fulfillers[fulfillerId].fulfillerAddress != msg.sender) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    constructor(address _accessControl) {
        accessControl = FGOAccessControl(_accessControl);
        symbol = "FGOF";
        name = "FGOFulfillers";
    }

    function createProfile(
        uint256 version,
        string memory uri
    ) external onlyApprovedFulfiller {
        if (_addressToFulfillerId[msg.sender] != 0) {
            revert FGOErrors.Existing();
        }
        if (bytes(uri).length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        if (_fulfillerSupply == type(uint256).max) {
            revert FGOErrors.MaxSupplyReached();
        }

        _fulfillerSupply++;

        _fulfillers[_fulfillerSupply] = FGOLibrary.FulfillerProfile({
            version: version,
            fulfillerAddress: msg.sender,
            isActive: true,
            uri: uri
        });

        _addressToFulfillerId[msg.sender] = _fulfillerSupply;

        emit FulfillerProfileCreated(_fulfillerSupply, msg.sender);
    }

    function updateProfile(
        uint256 fulfillerId,
        uint256 version,
        string memory uri
    ) external onlyFulfillerOwner(fulfillerId) {
        if (bytes(uri).length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        _fulfillers[fulfillerId].uri = uri;
        _fulfillers[fulfillerId].version = version;
        emit FulfillerProfileUpdated(fulfillerId);
    }

    function deactivateProfile(
        uint256 fulfillerId
    ) external onlyFulfillerOwner(fulfillerId) {
        _fulfillers[fulfillerId].isActive = false;
        emit FulfillerProfileDeactivated(fulfillerId);
    }

    function reactivateProfile(
        uint256 fulfillerId
    ) external onlyFulfillerOwner(fulfillerId) {
        _fulfillers[fulfillerId].isActive = true;
        emit FulfillerProfileReactivated(fulfillerId);
    }

    function deleteProfile(
        uint256 fulfillerId
    ) external onlyFulfillerOwner(fulfillerId) {
        delete _fulfillers[fulfillerId];
        delete _addressToFulfillerId[msg.sender];
        emit FulfillerProfileDeleted(fulfillerId);
    }

    function setAccessControl(address _accessControl) external onlyAdmin {
        accessControl = FGOAccessControl(_accessControl);
    }

    function getFulfiller(
        uint256 fulfillerId
    ) public view returns (FGOLibrary.FulfillerProfile memory) {
        return _fulfillers[fulfillerId];
    }

    function getFulfillerByAddress(
        address fulfillerAddress
    ) public view returns (FGOLibrary.FulfillerProfile memory) {
        uint256 fulfillerId = _addressToFulfillerId[fulfillerAddress];
        return _fulfillers[fulfillerId];
    }

    function getFulfillerAddress(
        uint256 fulfillerId
    ) public view returns (address) {
        return _fulfillers[fulfillerId].fulfillerAddress;
    }

    function getFulfillerSupply() public view returns (uint256) {
        return _fulfillerSupply;
    }

    function fulfillerExists(uint256 fulfillerId) public view returns (bool) {
        return
            _fulfillers[fulfillerId].fulfillerAddress != address(0) &&
            _fulfillers[fulfillerId].isActive;
    }

    function transferWallet(
        uint256 fulfillerId,
        address newWallet
    ) external onlyFulfillerOwner(fulfillerId) {
        if (newWallet == address(0)) {
            revert FGOErrors.AddressInvalid();
        }

        if (_addressToFulfillerId[newWallet] != 0) {
            revert FGOErrors.Existing();
        }

        address oldWallet = _fulfillers[fulfillerId].fulfillerAddress;

        _fulfillers[fulfillerId].fulfillerAddress = newWallet;
        _addressToFulfillerId[newWallet] = fulfillerId;
        delete _addressToFulfillerId[oldWallet];

        emit FulfillerWalletTransferred(fulfillerId, oldWallet, newWallet);
    }

    function getFulfillerIdByAddress(
        address fulfillerAddress
    ) public view returns (uint256) {
        return _addressToFulfillerId[fulfillerAddress];
    }
}
