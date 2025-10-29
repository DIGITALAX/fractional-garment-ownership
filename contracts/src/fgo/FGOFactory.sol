// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOAccessControl.sol";
import "./FGOSuppliers.sol";
import "./FGODesigners.sol";
import "./FGOFulfillers.sol";
import "./FGOChild.sol";
import "./FGOTemplateChild.sol";
import "./FGOParent.sol";
import "./FGOErrors.sol";
import "./FGOLibrary.sol";
import "../market/FGOMarket.sol";


contract FGOFactory {
    uint256 public infrastructureCounter;
    address public supplyCoordination;
    address public futuresCoordination;
    address public admin;
    bytes32[] public allInfrastructures;
    address[] public allChildContracts;
    address[] public allTemplateContracts;
    address[] public allParentContracts;
    address[] public allMarketContracts;

    mapping(bytes32 => FGOLibrary.InfrastructureAddresses)
        private _infrastructures;
    mapping(bytes32 => FGOLibrary.ChildContractData[]) private _childContracts;
    mapping(bytes32 => FGOLibrary.TemplateContractData[])
        private _templateContracts;
    mapping(bytes32 => FGOLibrary.ParentContractData[])
        private _parentContracts;
    mapping(bytes32 => FGOLibrary.MarketContractData[])
        private _marketContracts;
    mapping(address => bytes32[]) private _deployerToInfras;

    event InfrastructureDeployed(
        bytes32 indexed infraId,
        address indexed deployer,
        address indexed accessControl,
        address suppliers,
        address designers,
        address fulfillers
    );
    event ChildContractDeployed(
        uint256 indexed childType,
        bytes32 indexed infraId,
        address indexed childContract,
        address deployer
    );
    event TemplateContractDeployed(
        uint256 indexed childType,
        bytes32 indexed infraId,
        address indexed templateContract,
        address deployer
    );
    event ParentContractDeployed(
        bytes32 indexed infraId,
        address indexed parentContract,
        address deployer
    );
    event MarketContractDeployed(
        bytes32 indexed infraId,
        address indexed marketContract,
        address deployer
    );
    event InfrastructureURIUpdated(
        bytes32 indexed infraId,
        string oldURI,
        string newURI,
        address updatedBy
    );
    event InfrastructureDeactivated(
        bytes32 indexed infraId,
        address deactivatedBy
    );
    event InfrastructureReactivated(
        bytes32 indexed infraId,
        address reactivatedBy
    );
    event SuperAdminTransferred(
        bytes32 indexed infraId,
        address oldSuperAdmin,
        address newSuperAdmin
    );

    modifier onlyInfraAdmin(bytes32 infraId) {
        if (!_infrastructures[infraId].exists) {
            revert FGOErrors.Unauthorized();
        }

        FGOAccessControl accessControl = FGOAccessControl(
            _infrastructures[infraId].accessControl
        );
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    modifier infraExists(bytes32 infraId) {
        if (!_infrastructures[infraId].exists) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    modifier onlySuperAdmin(bytes32 infraId) {
        if (!_infrastructures[infraId].exists) {
            revert FGOErrors.Unauthorized();
        }
        if (_infrastructures[infraId].superAdmin != msg.sender) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    modifier infraActive(bytes32 infraId) {
        if (
            !_infrastructures[infraId].exists ||
            !_infrastructures[infraId].isActive
        ) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function deployInfrastructure(
        address paymentToken,
        string memory uri
    ) external returns (bytes32 infraId) {
        infrastructureCounter++;
        infraId = bytes32(infrastructureCounter);

        if (_infrastructures[infraId].exists) {
            revert FGOErrors.InfrastructureAlreadyExists();
        }

        FGOAccessControl accessControl = new FGOAccessControl(
            infraId,
            paymentToken,
            msg.sender,
            address(this)
        );

        FGOSuppliers suppliers = new FGOSuppliers(
            infraId,
            address(accessControl)
        );
        FGODesigners designers = new FGODesigners(
            infraId,
            address(accessControl)
        );
        FGOFulfillers fulfillers = new FGOFulfillers(
            infraId,
            address(accessControl)
        );

        _infrastructures[infraId] = FGOLibrary.InfrastructureAddresses({
            exists: true,
            isActive: true,
            accessControl: address(accessControl),
            suppliers: address(suppliers),
            designers: address(designers),
            fulfillers: address(fulfillers),
            deployer: msg.sender,
            superAdmin: msg.sender,
            uri: uri
        });

        allInfrastructures.push(infraId);
        _deployerToInfras[msg.sender].push(infraId);

        emit InfrastructureDeployed(
            infraId,
            msg.sender,
            address(accessControl),
            address(suppliers),
            address(designers),
            address(fulfillers)
        );

        return infraId;
    }

    function deployChildContract(
        uint256 childType,
        bytes32 infraId,
        string memory name,
        string memory symbol,
        string memory scm
    )
        external
        onlyInfraAdmin(infraId)
        infraActive(infraId)
        returns (address childContract)
    {
        FGOLibrary.InfrastructureAddresses memory infra = _infrastructures[
            infraId
        ];

        childContract = address(
            new FGOChild(
                childType,
                infraId,
                infra.accessControl,
                supplyCoordination,
                futuresCoordination,
                address(this),
                scm,
                name,
                symbol
            )
        );

        _childContracts[infraId].push(
            FGOLibrary.ChildContractData({
                childType: childType,
                exists: true,
                childContract: childContract,
                deployer: msg.sender
            })
        );

        allChildContracts.push(childContract);

        emit ChildContractDeployed(
            childType,
            infraId,
            childContract,
            msg.sender
        );

        return childContract;
    }

    function deployTemplateChildContract(
        uint256 childType,
        bytes32 infraId,
        string memory name,
        string memory symbol,
        string memory scm
    )
        external
        onlyInfraAdmin(infraId)
        infraActive(infraId)
        returns (address templateContract)
    {
        FGOLibrary.InfrastructureAddresses memory infra = _infrastructures[
            infraId
        ];

        templateContract = address(
            new FGOTemplateChild(
                childType,
                infraId,
                infra.accessControl,
                supplyCoordination,
                futuresCoordination,
                address(this),
                scm,
                name,
                symbol
            )
        );

        _templateContracts[infraId].push(
            FGOLibrary.TemplateContractData({
                childType: childType,
                exists: true,
                templateContract: templateContract,
                deployer: msg.sender
            })
        );

        allTemplateContracts.push(templateContract);

        emit TemplateContractDeployed(
            childType,
            infraId,
            templateContract,
            msg.sender
        );

        return templateContract;
    }

    function deployParentContract(
        bytes32 infraId,
        string memory parentURI,
        string memory scm,
        string memory symbol,
        string memory name
    )
        external
        onlyInfraAdmin(infraId)
        infraActive(infraId)
        returns (address parentContract)
    {
        FGOLibrary.InfrastructureAddresses memory infra = _infrastructures[
            infraId
        ];

        parentContract = address(
            new FGOParent(
                infraId,
                infra.accessControl,
                infra.fulfillers,
                supplyCoordination,
                futuresCoordination,
                scm,
                name,
                symbol,
                parentURI
            )
        );

        _parentContracts[infraId].push(
            FGOLibrary.ParentContractData({
                exists: true,
                deployer: msg.sender,
                parentContract: parentContract
            })
        );

        allParentContracts.push(parentContract);

        emit ParentContractDeployed(infraId, parentContract, msg.sender);

        return parentContract;
    }

    function deployMarketContract(
        bytes32 infraId,
        string memory marketURI,
        string memory name,
        string memory symbol
    )
        external
        onlyInfraAdmin(infraId)
        infraActive(infraId)
        returns (address marketContract)
    {
        FGOLibrary.InfrastructureAddresses memory infra = _infrastructures[
            infraId
        ];

        FGOMarket market = new FGOMarket(
            infraId,
            infra.accessControl,
            infra.fulfillers,
            futuresCoordination,
            symbol,
            name,
            marketURI
        );

        marketContract = address(market);
        address fulfillmentContract = address(
            new FGOFulfillment(infraId, infra.accessControl, marketContract)
        );

        market.setFulfillment(fulfillmentContract);

        _marketContracts[infraId].push(
            FGOLibrary.MarketContractData({
                exists: true,
                deployer: msg.sender,
                marketContract: marketContract
            })
        );

        allMarketContracts.push(marketContract);

        emit MarketContractDeployed(infraId, marketContract, msg.sender);

        return marketContract;
    }

    function getInfrastructure(
        bytes32 infraId
    )
        external
        view
        infraExists(infraId)
        returns (FGOLibrary.InfrastructureAddresses memory)
    {
        return _infrastructures[infraId];
    }

    function getChildContracts(
        bytes32 infraId
    )
        external
        view
        infraExists(infraId)
        returns (FGOLibrary.ChildContractData[] memory)
    {
        return _childContracts[infraId];
    }

    function getTemplateContracts(
        bytes32 infraId
    )
        external
        view
        infraExists(infraId)
        returns (FGOLibrary.TemplateContractData[] memory)
    {
        return _templateContracts[infraId];
    }

    function getParentContracts(
        bytes32 infraId
    )
        external
        view
        infraExists(infraId)
        returns (FGOLibrary.ParentContractData[] memory)
    {
        return _parentContracts[infraId];
    }

    function getMarketContracts(
        bytes32 infraId
    )
        external
        view
        infraExists(infraId)
        returns (FGOLibrary.MarketContractData[] memory)
    {
        return _marketContracts[infraId];
    }

    function getDeployerInfrastructures(
        address deployer
    ) external view returns (bytes32[] memory) {
        return _deployerToInfras[deployer];
    }

    function getAllInfrastructures() external view returns (bytes32[] memory) {
        return allInfrastructures;
    }

    function getAllChildContracts() external view returns (address[] memory) {
        return allChildContracts;
    }

    function getAllTemplateContracts()
        external
        view
        returns (address[] memory)
    {
        return allTemplateContracts;
    }

    function getAllParentContracts() external view returns (address[] memory) {
        return allParentContracts;
    }

    function getAllMarketContracts() external view returns (address[] memory) {
        return allMarketContracts;
    }

    function isInfraAdmin(
        bytes32 infraId,
        address user
    ) external view infraExists(infraId) returns (bool) {
        FGOAccessControl accessControl = FGOAccessControl(
            _infrastructures[infraId].accessControl
        );
        return accessControl.isAdmin(user);
    }

    function updateInfrastructureURI(
        bytes32 infraId,
        string memory newURI
    ) external onlySuperAdmin(infraId) {
        string memory oldURI = _infrastructures[infraId].uri;
        _infrastructures[infraId].uri = newURI;

        emit InfrastructureURIUpdated(infraId, oldURI, newURI, msg.sender);
    }

    function deactivateInfrastructure(
        bytes32 infraId
    ) external onlySuperAdmin(infraId) {
        if (!_infrastructures[infraId].isActive) {
            revert FGOErrors.Unauthorized();
        }

        _infrastructures[infraId].isActive = false;
        emit InfrastructureDeactivated(infraId, msg.sender);
    }

    function reactivateInfrastructure(
        bytes32 infraId
    ) external onlySuperAdmin(infraId) {
        if (_infrastructures[infraId].isActive) {
            revert FGOErrors.Unauthorized();
        }

        _infrastructures[infraId].isActive = true;
        emit InfrastructureReactivated(infraId, msg.sender);
    }

    function transferSuperAdmin(
        bytes32 infraId,
        address newSuperAdmin
    ) external onlySuperAdmin(infraId) {
        if (newSuperAdmin == address(0)) {
            revert FGOErrors.Unauthorized();
        }

        address oldSuperAdmin = _infrastructures[infraId].superAdmin;
        _infrastructures[infraId].superAdmin = newSuperAdmin;

        emit SuperAdminTransferred(infraId, oldSuperAdmin, newSuperAdmin);
    }

    function isSuperAdmin(
        bytes32 infraId,
        address user
    ) external view infraExists(infraId) returns (bool) {
        return _infrastructures[infraId].superAdmin == user;
    }

    function isInfrastructureActive(
        bytes32 infraId
    ) external view infraExists(infraId) returns (bool) {
        return _infrastructures[infraId].isActive;
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }

    function setSupplyCoordination(
        address _supplyCoordination
    ) external onlyAdmin {
        supplyCoordination = _supplyCoordination;
    }

    function setFuturesCoordination(
        address _futuresCoordination
    ) external onlyAdmin {
        futuresCoordination = _futuresCoordination;
    }
    

    function isValidParent(address _contract) external view returns (bool) {
        for (uint256 i = 0; i < allParentContracts.length; ) {
            if (allParentContracts[i] == _contract) {
                return true;
            }
            unchecked {
                ++i;
            }
        }
        return false;
    }

    function isValidChild(address _contract) external view returns (bool) {
        for (uint256 i = 0; i < allChildContracts.length; ) {
            if (allChildContracts[i] == _contract) {
                return true;
            }
            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < allTemplateContracts.length; ) {
            if (allTemplateContracts[i] == _contract) {
                return true;
            }
            unchecked {
                ++i;
            }
        }

        return false;
    }

    function isValidContract(address _contract) external view returns (bool) {
        for (uint256 i = 0; i < allParentContracts.length; ) {
            if (allParentContracts[i] == _contract) {
                return true;
            }
            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < allTemplateContracts.length; ) {
            if (allTemplateContracts[i] == _contract) {
                return true;
            }
            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < allMarketContracts.length; ) {
            if (allMarketContracts[i] == _contract) {
                return true;
            }
            unchecked {
                ++i;
            }
        }

        return false;
    }
}
