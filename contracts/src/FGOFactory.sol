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

contract FGOFactory {
    uint256 public infrastructureCounter;
    bytes32[] public allInfrastructures;
    address[] public allChildContracts;
    address[] public allTemplateContracts;
    address[] public allParentContracts;

    mapping(bytes32 => FGOLibrary.InfrastructureAddresses)
        public infrastructures;
    mapping(bytes32 => FGOLibrary.ChildContractData[]) public childContracts;
    mapping(bytes32 => FGOLibrary.TemplateContractData[])
        public templateContracts;
    mapping(bytes32 => FGOLibrary.ParentContractData[]) public parentContracts;
    mapping(address => bytes32[]) public deployerToInfras;

    event InfrastructureDeployed(
        bytes32 indexed infraId,
        address indexed deployer,
        address indexed accessControl,
        address suppliers,
        address designers,
        address fulfillers
    );
    event ChildContractDeployed(
        bytes32 indexed infraId,
        uint256 indexed childType,
        address indexed childContract,
        address deployer
    );
    event TemplateContractDeployed(
        bytes32 indexed infraId,
        uint256 indexed childType,
        address indexed templateContract,
        address deployer
    );
    event ParentContractDeployed(
        bytes32 indexed infraId,
        address indexed parentContract,
        address deployer
    );

    modifier onlyInfraAdmin(bytes32 infraId) {
        if (!infrastructures[infraId].exists) {
            revert FGOErrors.AddressInvalid();
        }

        FGOAccessControl accessControl = FGOAccessControl(
            infrastructures[infraId].accessControl
        );
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    modifier infraExists(bytes32 infraId) {
        if (!infrastructures[infraId].exists) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }

    function deployInfrastructure(
        address paymentToken
    ) external returns (bytes32 infraId) {
        infrastructureCounter++;
        infraId = bytes32(infrastructureCounter);

        if (infrastructures[infraId].exists) {
            revert FGOErrors.Existing();
        }

        FGOAccessControl accessControl = new FGOAccessControl(
            paymentToken,
            msg.sender
        );

        FGOSuppliers suppliers = new FGOSuppliers(address(accessControl));
        FGODesigners designers = new FGODesigners(address(accessControl));
        FGOFulfillers fulfillers = new FGOFulfillers(address(accessControl));

        infrastructures[infraId] = FGOLibrary.InfrastructureAddresses({
            exists: true,
            accessControl: address(accessControl),
            suppliers: address(suppliers),
            designers: address(designers),
            fulfillers: address(fulfillers),
            deployer: msg.sender
        });

        allInfrastructures.push(infraId);
        deployerToInfras[msg.sender].push(infraId);

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
        bytes32 infraId,
        uint256 childType,
        string memory name,
        string memory symbol,
        string memory smu
    ) external onlyInfraAdmin(infraId) returns (address childContract) {
        FGOLibrary.InfrastructureAddresses memory infra = infrastructures[
            infraId
        ];

        childContract = address(
            new FGOChild(childType, infra.accessControl, smu, name, symbol)
        );

        childContracts[infraId].push(
            FGOLibrary.ChildContractData({
                childType: childType,
                exists: true,
                childContract: childContract,
                deployer: msg.sender
            })
        );

        allChildContracts.push(childContract);

        emit ChildContractDeployed(
            infraId,
            childType,
            childContract,
            msg.sender
        );

        return childContract;
    }

    function deployTemplateChildContract(
        bytes32 infraId,
        uint256 childType,
        string memory name,
        string memory symbol,
        string memory smu
    ) external onlyInfraAdmin(infraId) returns (address templateContract) {
        FGOLibrary.InfrastructureAddresses memory infra = infrastructures[
            infraId
        ];

        templateContract = address(
            new FGOTemplateChild(
                childType,
                infra.accessControl,
                smu,
                name,
                symbol
            )
        );

        templateContracts[infraId].push(
            FGOLibrary.TemplateContractData({
                childType: childType,
                exists: true,
                templateContract: templateContract,
                deployer: msg.sender
            })
        );

        allTemplateContracts.push(templateContract);

        emit TemplateContractDeployed(
            infraId,
            childType,
            templateContract,
            msg.sender
        );

        return templateContract;
    }

    function deployParentContract(
        bytes32 infraId,
        string memory parentURI,
        string memory smu,
        string memory symbol,
        string memory name
    ) external onlyInfraAdmin(infraId) returns (address parentContract) {
        FGOLibrary.InfrastructureAddresses memory infra = infrastructures[
            infraId
        ];

        parentContract = address(
            new FGOParent(infra.accessControl, smu, name, symbol, parentURI)
        );

        parentContracts[infraId].push(
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

    function getInfrastructure(
        bytes32 infraId
    )
        external
        view
        infraExists(infraId)
        returns (FGOLibrary.InfrastructureAddresses memory)
    {
        return infrastructures[infraId];
    }

    function getChildContracts(
        bytes32 infraId
    )
        external
        view
        infraExists(infraId)
        returns (FGOLibrary.ChildContractData[] memory)
    {
        return childContracts[infraId];
    }

    function getTemplateContracts(
        bytes32 infraId
    )
        external
        view
        infraExists(infraId)
        returns (FGOLibrary.TemplateContractData[] memory)
    {
        return templateContracts[infraId];
    }

    function getParentContracts(
        bytes32 infraId
    )
        external
        view
        infraExists(infraId)
        returns (FGOLibrary.ParentContractData[] memory)
    {
        return parentContracts[infraId];
    }

    function getDeployerInfrastructures(
        address deployer
    ) external view returns (bytes32[] memory) {
        return deployerToInfras[deployer];
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

    function isInfraAdmin(
        bytes32 infraId,
        address user
    ) external view infraExists(infraId) returns (bool) {
        FGOAccessControl accessControl = FGOAccessControl(
            infrastructures[infraId].accessControl
        );
        return accessControl.isAdmin(user);
    }
}
