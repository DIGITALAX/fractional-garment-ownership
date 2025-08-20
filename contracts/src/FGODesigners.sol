// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOAccessControl.sol";
import "./FGOLibrary.sol";
import "./FGOErrors.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FGODesigners is ReentrancyGuard {
    uint256 private _designerSupply;
    string public symbol;
    string public name;
    FGOAccessControl public accessControl;

    mapping(uint256 => FGOLibrary.DesignerProfile) private _designers;
    mapping(address => uint256) private _addressToDesignerId;

    event DesignerCreated(uint256 indexed designerId, address indexed designer);
    event DesignerUpdated(uint256 indexed designerId);
    event DesignerWalletTransferred(
        uint256 indexed designerId,
        address oldAddress,
        address newAddress
    );
    event DesignerDeactivated(uint256 indexed designerId);
    event DesignerReactivated(uint256 indexed designerId);

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    modifier onlyApprovedDesigner() {
        if (!accessControl.canCreateParents(msg.sender)) {
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

    constructor(address _accessControl) {
        accessControl = FGOAccessControl(_accessControl);
        symbol = "FGOD";
        name = "FGODesigners";
    }

    function createProfile(
        uint256 version,
        string memory uri
    ) external onlyApprovedDesigner {
        if (_addressToDesignerId[msg.sender] != 0) {
            revert FGOErrors.Existing();
        }
        if (bytes(uri).length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        if (_designerSupply == type(uint256).max) {
            revert FGOErrors.MaxSupplyReached();
        }

        _designerSupply++;

        _designers[_designerSupply] = FGOLibrary.DesignerProfile({
            designerAddress: msg.sender,
            uri: uri,
            isActive: true,
            version: version
        });

        _addressToDesignerId[msg.sender] = _designerSupply;

        emit DesignerCreated(_designerSupply, msg.sender);
    }

    function updateProfile(
        uint256 designerId,
        uint256 version,
        string memory uri
    ) external onlyDesignerOwner(designerId) {
        if (bytes(uri).length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        _designers[designerId].uri = uri;
        _designers[designerId].version = version;
        emit DesignerUpdated(designerId);
    }

    function deactivateProfile(
        uint256 designerId
    ) external onlyDesignerOwner(designerId) {
        _designers[designerId].isActive = false;
        emit DesignerDeactivated(designerId);
    }

    function reactivateProfile(
        uint256 designerId
    ) external onlyDesignerOwner(designerId) {
        _designers[designerId].isActive = true;
        emit DesignerReactivated(designerId);
    }

    function setAccessControl(address _accessControl) external onlyAdmin {
        accessControl = FGOAccessControl(_accessControl);
    }

    function getDesignerProfile(
        uint256 designerId
    ) public view returns (FGOLibrary.DesignerProfile memory) {
        return _designers[designerId];
    }

    function getDesignerSupply() public view returns (uint256) {
        return _designerSupply;
    }

    function designerExists(uint256 designerId) public view returns (bool) {
        return
            _designers[designerId].designerAddress != address(0) &&
            _designers[designerId].isActive;
    }

    function getDesignerIdByAddress(
        address designerAddress
    ) public view returns (uint256) {
        return _addressToDesignerId[designerAddress];
    }

    function transferWallet(
        uint256 designerId,
        address newWallet
    ) external onlyDesignerOwner(designerId) {
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
}
