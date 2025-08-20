// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import "../src/FGOFactory.sol";
import "../src/FGOLibrary.sol";

contract DeployInfrastructure is Script {
    using stdJson for string;

    struct InfrastructureContracts {
        FGOFactory factory;
        bytes32 infraId;
        address printZoneChild;
        address coinOpTemplateChild;
        address coinOpParent;
    }

    address constant FACTORY_ADDRESS =
        0x796048d827B983B085324Ebe377c2cCB089155C0;
    address constant TEST_TOKEN_ADDRESS =
        0xE5E9D4C119a28302EDa029155bF00efd35E06c93;

    function run() external {
        require(FACTORY_ADDRESS != address(0), "Factory address not set");
        require(TEST_TOKEN_ADDRESS != address(0), "Test token address not set");

        vm.startBroadcast();

        console.log("=== FGO Infrastructure Deployment ===");
        console.log("Deployer:", msg.sender);
        console.log("Chain ID:", block.chainid);
        console.log("Factory:", FACTORY_ADDRESS);
        console.log("Test Token:", TEST_TOKEN_ADDRESS);

        InfrastructureContracts
            memory contracts = deployInfrastructureContracts(
                FACTORY_ADDRESS,
                TEST_TOKEN_ADDRESS
            );
        verifyInfrastructureDeployment(contracts);
        performInfrastructureTests(contracts);
        logInfrastructureAddresses(contracts);

        vm.stopBroadcast();

        console.log("\n--- INFRASTRUCTURE DEPLOYMENT COMPLETE ---");
        console.log(
            "IMPORTANT: Real contract addresses are in the broadcast JSON:"
        );
        console.log(
            "Path:",
            string.concat(
                "broadcast/DeployInfrastructure.s.sol/",
                vm.toString(block.chainid),
                "/run-latest.json"
            )
        );
        console.log(
            "Order: AccessControl, Suppliers, Designers, Fulfillers, PrintZoneChild, CoinOpParent"
        );
        console.log(
            "Run 'forge script script/ParseAddresses.s.sol:ParseAddresses --rpc-url RPC' to see parsed addresses"
        );
        console.log("=== Infrastructure Deployment Complete ===");
    }

    function deployInfrastructureContracts(
        address factoryAddress,
        address testTokenAddress
    ) internal returns (InfrastructureContracts memory contracts) {
        contracts.factory = FGOFactory(factoryAddress);

        console.log("\n--- Step 1: Deploying Infrastructure Suite ---");
        console.log("Deploying FGO Infrastructure via Factory...");
        contracts.infraId = contracts.factory.deployInfrastructure(
            testTokenAddress,
            "ipfs://infrastructure-base-uri"
        );

        console.log("\n--- Step 2: Deploying Child Contract ---");
        console.log("Deploying FGOChild via Factory...");
        contracts.printZoneChild = contracts.factory.deployChildContract(
            contracts.infraId,
            1,
            "Print Zone",
            "PRTZ",
            "Coin Op"
        );

        console.log("\n--- Step 3: Deploying Template Contract ---");
        console.log("Deploying FGOTemplateChild via Factory...");
        contracts.coinOpTemplateChild = contracts
            .factory
            .deployTemplateChildContract(
                contracts.infraId,
                2,
                "Coin Op Template",
                "COTEMP",
                "Coin Op"
            );

        console.log("\n--- Step 4: Deploying Parent Contract ---");
        console.log("Deploying FGOParent via Factory...");
        contracts.coinOpParent = contracts.factory.deployParentContract(
            contracts.infraId,
            "ipfs://QmFGOCoinOpCollectionMetadata",
            "CoinOp",
            "COINP",
            "Coin Op Parent"
        );

        return contracts;
    }

    function verifyInfrastructureDeployment(
        InfrastructureContracts memory contracts
    ) internal view {
        console.log("\n--- Step 4: Verifying Infrastructure Deployment ---");

        require(
            address(contracts.factory) != address(0),
            "Factory not connected"
        );
        require(contracts.infraId != bytes32(0), "Infrastructure not deployed");
        require(
            contracts.printZoneChild != address(0),
            "PrintZoneChild not deployed"
        );
        require(
            contracts.coinOpParent != address(0),
            "CoinOpParent not deployed"
        );

        // Verify infrastructure
        FGOLibrary.InfrastructureAddresses memory infra = contracts
            .factory
            .getInfrastructure(contracts.infraId);
        require(infra.exists, "Infrastructure not properly created");
        require(infra.deployer == msg.sender, "Deployer not set correctly");


        console.log("All infrastructure verifications passed!");
    }

    function performInfrastructureTests(
        InfrastructureContracts memory contracts
    ) internal view {
        console.log("\n--- Step 5: Infrastructure Functionality Tests ---");

        // Test infrastructure access
        require(
            contracts.factory.isInfraAdmin(contracts.infraId, msg.sender),
            "Deployer should be infra admin"
        );

        // Test contract registrations
        bytes32[] memory allInfra = contracts.factory.getAllInfrastructures();
        require(allInfra.length > 0, "No infrastructures registered");

        address[] memory allChildren = contracts.factory.getAllChildContracts();
        require(allChildren.length > 0, "No child contracts registered");

        address[] memory allParents = contracts.factory.getAllParentContracts();
        require(allParents.length > 0, "No parent contracts registered");

        console.log("All infrastructure functionality tests passed!");
    }

    function logInfrastructureAddresses(
        InfrastructureContracts memory contracts
    ) internal view {
        console.log("\n--- Step 6: Infrastructure Contract Addresses ---");
        console.log("Factory:", address(contracts.factory));

        console.log("\n--- Infrastructure Details ---");
        console.log("Infrastructure ID:", vm.toString(contracts.infraId));

        FGOLibrary.InfrastructureAddresses memory infra = contracts
            .factory
            .getInfrastructure(contracts.infraId);
        console.log("Access Control:", infra.accessControl);
        console.log("Suppliers:", infra.suppliers);
        console.log("Designers:", infra.designers);
        console.log("Fulfillers:", infra.fulfillers);

        console.log("\n--- Child & Parent Contracts ---");
        console.log("FGOChild:", contracts.printZoneChild);
        console.log("FGOCoinOpParent:", contracts.coinOpParent);

        console.log("\n--- Factory Stats ---");
        console.log(
            "Total Infrastructures:",
            contracts.factory.getAllInfrastructures().length
        );
        console.log(
            "Total Child Contracts:",
            contracts.factory.getAllChildContracts().length
        );
        console.log(
            "Total Parent Contracts:",
            contracts.factory.getAllParentContracts().length
        );
    }
}
