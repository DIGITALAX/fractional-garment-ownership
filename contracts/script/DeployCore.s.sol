// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import "../src/FGOAccessControl.sol";
import "../src/FGOPatternChild.sol";
import "../src/FGOMaterialChild.sol";
import "../src/FGOPrintDesignChild.sol";
import "../src/FGOEmbellishmentsChild.sol";
import "../src/FGOConstructionChild.sol";
import "../src/FGODigitalEffectsChild.sol";
import "../src/FGOFinishingTreatmentsChild.sol";
import "../src/FGOTemplatePackChild.sol";
import "../src/FGOPrintZoneChild.sol";
import "../src/FGOCoinOpParent.sol";
import "../src/FGODesigners.sol";
import "../src/FGOSuppliers.sol";
import "../src/FGOFulfillers.sol";
import "../src/TestToken.sol";

contract DeployCore is Script {
    struct CoreContracts {
        FGOAccessControl accessControl;
        FGOPatternChild patternChild;
        FGOMaterialChild materialChild;
        FGOPrintDesignChild printDesignChild;
        FGOEmbellishmentsChild embellishmentsChild;
        FGOConstructionChild constructionChild;
        FGODigitalEffectsChild digitalEffectsChild;
        FGOFinishingTreatmentsChild finishingTreatmentsChild;
        FGOTemplatePackChild templatePackChild;
        FGOPrintZoneChild printZoneChild;
        FGOCoinOpParent coinOpParent;
        FGODesigners designers;
        FGOSuppliers suppliers;
        FGOFulfillers fulfillers;
        TestToken testToken;
    }

    function run() external {
        vm.startBroadcast();

        console.log("=== FGO Core System Deployment ===");
        console.log("Deployer:", msg.sender);
        console.log("Chain ID:", block.chainid);

        CoreContracts memory contracts = deployCoreContracts();
        configureCore(contracts);
        verifyCoreDeployment(contracts);
        logCoreAddresses(contracts);

        vm.stopBroadcast();

        console.log("=== Core Deployment Complete ===");
    }

    function deployCoreContracts()
        internal
        returns (CoreContracts memory contracts)
    {
        console.log("\n--- Step 1: Deploying Payment Token ---");
        
        console.log("Deploying TestToken...");
        contracts.testToken = new TestToken();

        console.log("\n--- Step 2: Deploying Access Control ---");
        
        console.log("Deploying FGOAccessControl...");
        contracts.accessControl = new FGOAccessControl(address(contracts.testToken));

        console.log("\n--- Step 3: Deploying All 9 Child Contracts ---");

        console.log("Deploying FGOPatternChild...");
        contracts.patternChild = new FGOPatternChild(
            address(contracts.accessControl)
        );

        console.log("Deploying FGOMaterialChild...");
        contracts.materialChild = new FGOMaterialChild(
            address(contracts.accessControl)
        );

        console.log("Deploying FGOPrintDesignChild...");
        contracts.printDesignChild = new FGOPrintDesignChild(
            address(contracts.accessControl)
        );

        console.log("Deploying FGOEmbellishmentsChild...");
        contracts.embellishmentsChild = new FGOEmbellishmentsChild(
            address(contracts.accessControl)
        );

        console.log("Deploying FGOConstructionChild...");
        contracts.constructionChild = new FGOConstructionChild(
            address(contracts.accessControl)
        );

        console.log("Deploying FGODigitalEffectsChild...");
        contracts.digitalEffectsChild = new FGODigitalEffectsChild(
            address(contracts.accessControl)
        );

        console.log("Deploying FGOFinishingTreatmentsChild...");
        contracts.finishingTreatmentsChild = new FGOFinishingTreatmentsChild(
            address(contracts.accessControl)
        );

        console.log("Deploying FGOTemplatePackChild...");
        contracts.templatePackChild = new FGOTemplatePackChild(
            address(contracts.accessControl)
        );

        console.log("Deploying FGOPrintZoneChild...");
        contracts.printZoneChild = new FGOPrintZoneChild(
            address(contracts.accessControl)
        );

        console.log("\n--- Step 4: Deploying Parent Contract ---");

        console.log("Deploying FGOCoinOpParent...");
        contracts.coinOpParent = new FGOCoinOpParent(
            address(contracts.accessControl),
            "ipfs://QmFGOCoinOpCollectionMetadata"
        );

        console.log("\n--- Step 5: Deploying Profile Contracts ---");

        console.log("Deploying FGODesigners...");
        contracts.designers = new FGODesigners(
            address(contracts.accessControl),
            address(contracts.coinOpParent)
        );

        console.log("Deploying FGOSuppliers...");
        contracts.suppliers = new FGOSuppliers(
            address(contracts.accessControl)
        );

        console.log("Deploying FGOFulfillers...");
        contracts.fulfillers = new FGOFulfillers(
            address(contracts.accessControl)
        );

        return contracts;
    }

    function configureCore(CoreContracts memory contracts) internal {
        console.log("\n--- Step 6: Configuring Core System ---");

        console.log("Core system deployed - ready for market integration!");
    }

    function verifyCoreDeployment(
        CoreContracts memory contracts
    ) internal view {
        console.log("\n--- Step 7: Verifying Core Deployment ---");

        require(
            address(contracts.accessControl) != address(0),
            "AccessControl not deployed"
        );
        require(
            address(contracts.patternChild) != address(0),
            "PatternChild not deployed"
        );
        require(
            address(contracts.materialChild) != address(0),
            "MaterialChild not deployed"
        );
        require(
            address(contracts.printDesignChild) != address(0),
            "PrintDesignChild not deployed"
        );
        require(
            address(contracts.embellishmentsChild) != address(0),
            "EmbellishmentsChild not deployed"
        );
        require(
            address(contracts.constructionChild) != address(0),
            "ConstructionChild not deployed"
        );
        require(
            address(contracts.digitalEffectsChild) != address(0),
            "DigitalEffectsChild not deployed"
        );
        require(
            address(contracts.finishingTreatmentsChild) != address(0),
            "FinishingTreatmentsChild not deployed"
        );
        require(
            address(contracts.templatePackChild) != address(0),
            "TemplatePackChild not deployed"
        );
        require(
            address(contracts.printZoneChild) != address(0),
            "PrintZoneChild not deployed"
        );
        require(
            address(contracts.coinOpParent) != address(0),
            "CoinOpParent not deployed"
        );
        require(
            address(contracts.designers) != address(0),
            "Designers not deployed"
        );
        require(
            address(contracts.suppliers) != address(0),
            "Suppliers not deployed"
        );
        require(
            address(contracts.fulfillers) != address(0),
            "Fulfillers not deployed"
        );
        require(
            address(contracts.testToken) != address(0),
            "TestToken not deployed"
        );

        require(
            contracts.accessControl.isAdmin(msg.sender),
            "Deployer not admin"
        );

        console.log("All core verifications passed!");
    }

    function logCoreAddresses(CoreContracts memory contracts) internal view {
        console.log("\n--- Step 8: Core Contract Addresses ---");
        console.log("FGOAccessControl:", address(contracts.accessControl));
        console.log("TestToken:", address(contracts.testToken));
        
        console.log("\n--- Child Contracts (9 types) ---");
        console.log("FGOPatternChild:", address(contracts.patternChild));
        console.log("FGOMaterialChild:", address(contracts.materialChild));
        console.log("FGOPrintDesignChild:", address(contracts.printDesignChild));
        console.log("FGOEmbellishmentsChild:", address(contracts.embellishmentsChild));
        console.log("FGOConstructionChild:", address(contracts.constructionChild));
        console.log("FGODigitalEffectsChild:", address(contracts.digitalEffectsChild));
        console.log("FGOFinishingTreatmentsChild:", address(contracts.finishingTreatmentsChild));
        console.log("FGOTemplatePackChild:", address(contracts.templatePackChild));
        console.log("FGOPrintZoneChild:", address(contracts.printZoneChild));
        
        console.log("\n--- Parent & Profile Contracts ---");
        console.log("FGOCoinOpParent:", address(contracts.coinOpParent));
        console.log("FGODesigners:", address(contracts.designers));
        console.log("FGOSuppliers:", address(contracts.suppliers));
        console.log("FGOFulfillers:", address(contracts.fulfillers));

        console.log("\n--- Collection Info ---");
        console.log("Collection URI:", contracts.coinOpParent.collectionURI());
        console.log("Collection Name:", contracts.coinOpParent.name());
        console.log("Collection Symbol:", contracts.coinOpParent.symbol());
    }
}