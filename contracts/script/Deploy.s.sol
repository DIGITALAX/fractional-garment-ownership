// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import "../src/FGOAccessControl.sol";
import "../src/FGOSplitsData.sol";
import "../src/FGOPatternChild.sol";
import "../src/FGOMaterialChild.sol";
import "../src/FGOPrintDesignChild.sol";
import "../src/FGOEmbellishmentsChild.sol";
import "../src/FGOConstructionChild.sol";
import "../src/FGODigitalEffectsChild.sol";
import "../src/FGOFinishingTreatmentsChild.sol";
import "../src/FGOTemplatePackChild.sol";
import "../src/FGOParent.sol";
import "../src/FGODesigners.sol";
import "../src/FGOSuppliers.sol";
import "../src/FGOFulfillers.sol";
import "../src/FGOWorkflowExecutor.sol";
import "../src/CustomCompositeNFT.sol";
import "../src/FGOMarket.sol";
import "../src/TestToken.sol";

contract Deploy is Script {
    struct DeployedContracts {
        FGOAccessControl accessControl;
        FGOSplitsData splitsData;
        FGOPatternChild patternChild;
        FGOMaterialChild materialChild;
        FGOPrintDesignChild printDesignChild;
        FGOEmbellishmentsChild embellishmentsChild;
        FGOConstructionChild constructionChild;
        FGODigitalEffectsChild digitalEffectsChild;
        FGOFinishingTreatmentsChild finishingTreatmentsChild;
        FGOTemplatePackChild templatePackChild;
        FGOParent parentFGO;
        FGODesigners designers;
        FGOSuppliers suppliers;
        FGOFulfillers fulfillers;
        FGOWorkflowExecutor workflowExecutor;
        CustomCompositeNFT customComposite;
        FGOMarket market;
        TestToken testToken;
    }

    function run() external {
        vm.startBroadcast();

        console.log("=== FGO Contract Suite Deployment ===");
        console.log("Deployer:", msg.sender);
        console.log("Chain ID:", block.chainid);

        DeployedContracts memory contracts = deployContracts();
        configureContracts(contracts);
        verifyDeployment(contracts);
        logAddresses(contracts);

        vm.stopBroadcast();

        console.log("=== Deployment Complete ===");
    }

    function deployContracts()
        internal
        returns (DeployedContracts memory contracts)
    {
        console.log("\n--- Step 1: Deploying Core Contracts ---");

        // 1. Deploy Access Control (needed by all other contracts)
        console.log("Deploying FGOAccessControl...");
        contracts.accessControl = new FGOAccessControl();

        // 2. Deploy Test Token (for testing/demo purposes)
        console.log("Deploying TestToken...");
        contracts.testToken = new TestToken();

        // 3. Deploy Splits Data
        console.log("Deploying FGOSplitsData...");
        contracts.splitsData = new FGOSplitsData(
            address(contracts.accessControl)
        );

        console.log("\n--- Step 2: Deploying Child Contracts ---");

        // 4. Deploy all 8 child contract types
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

        console.log("\n--- Step 3: Deploying Parent & Profile Contracts ---");

        // 5. Deploy Parent
        console.log("Deploying FGOParent...");
        contracts.parentFGO = new FGOParent(address(contracts.accessControl));

        // 6. Deploy Profile Contracts
        console.log("Deploying FGODesigners...");
        contracts.designers = new FGODesigners(
            address(contracts.accessControl),
            address(contracts.parentFGO)
        );

        console.log("Deploying FGOSuppliers...");
        contracts.suppliers = new FGOSuppliers(
            address(contracts.accessControl)
        );

        console.log("Deploying FGOFulfillers...");
        contracts.fulfillers = new FGOFulfillers(
            address(contracts.accessControl)
        );

        console.log("\n--- Step 4: Deploying Workflow & Market Contracts ---");

        // 7. Deploy Workflow Executor
        console.log("Deploying FGOWorkflowExecutor...");
        contracts.workflowExecutor = new FGOWorkflowExecutor(
            address(contracts.accessControl),
            address(contracts.parentFGO),
            address(contracts.fulfillers)
        );

        // 8. Deploy Custom Composite NFT
        console.log("Deploying CustomCompositeNFT...");
        contracts.customComposite = new CustomCompositeNFT(
            address(contracts.accessControl)
        );

        // 9. Deploy Market (last - needs all other contracts)
        console.log("Deploying FGOMarket...");
        contracts.market = new FGOMarket(
            address(contracts.accessControl),
            address(contracts.customComposite),
            address(contracts.parentFGO),
            address(contracts.splitsData),
            address(contracts.fulfillers),
            address(contracts.patternChild),
            address(contracts.materialChild),
            address(contracts.printDesignChild),
            address(contracts.embellishmentsChild),
            address(contracts.constructionChild),
            address(contracts.digitalEffectsChild),
            address(contracts.finishingTreatmentsChild),
            address(contracts.templatePackChild),
            address(contracts.workflowExecutor)
        );

        return contracts;
    }

    function configureContracts(DeployedContracts memory contracts) internal {
        console.log("\n--- Step 5: Configuring Contract Relationships ---");

        // Configure Access Control
        console.log("Authorizing market in AccessControl...");
        contracts.accessControl.authorizeMarket(address(contracts.market));

        // Configure Custom Composite
        console.log("Setting up CustomComposite relationships...");
        contracts.customComposite.setParentFGO(address(contracts.parentFGO));
        contracts.customComposite.authorizeMarket(address(contracts.market));

        // Authorize market in access control (handles all child contract authorization)
        console.log("Authorizing market in access control...");
        contracts.accessControl.authorizeMarket(address(contracts.market));

        // Set up default currency (TestToken for demo)
        console.log("Adding default currency to SplitsData...");
        contracts.splitsData.addCurrency(
            address(contracts.testToken),
            1e18, // 1 token wei amount
            1e18 // 1:1 exchange rate with wei
        );

        // Set default splits for test token
        console.log("Setting default splits for TestToken...");
        contracts.splitsData.setSplits(
            address(contracts.testToken),
            7500, // 75% to fulfiller
            1000 * 1e18, // 1000 token base amount
            1 // printType 1
        );

        console.log("Configuration complete!");
    }

    function verifyDeployment(
        DeployedContracts memory contracts
    ) internal view {
        console.log("\n--- Step 6: Verifying Deployment ---");

        // Verify contract deployments
        require(
            address(contracts.accessControl) != address(0),
            "AccessControl not deployed"
        );
        require(
            address(contracts.splitsData) != address(0),
            "SplitsData not deployed"
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
            address(contracts.parentFGO) != address(0),
            "Parent not deployed"
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
            address(contracts.workflowExecutor) != address(0),
            "WorkflowExecutor not deployed"
        );
        require(
            address(contracts.customComposite) != address(0),
            "CustomComposite not deployed"
        );
        require(address(contracts.market) != address(0), "Market not deployed");
        require(
            address(contracts.testToken) != address(0),
            "TestToken not deployed"
        );

        // Verify configurations
        require(
            contracts.accessControl.isAuthorizedMarket(
                address(contracts.market)
            ),
            "Market not authorized"
        );
        require(
            contracts.customComposite.parentFGO() ==
                address(contracts.parentFGO),
            "ParentFGO not set"
        );
        require(
            contracts.customComposite.authorizedMarkets(
                address(contracts.market)
            ),
            "Market not authorized in CustomComposite"
        );
        require(
            contracts.splitsData.getIsCurrency(address(contracts.testToken)),
            "TestToken not added as currency"
        );

        console.log("All verifications passed!");
    }

    function logAddresses(DeployedContracts memory contracts) internal view {
        console.log("\n--- Step 7: Contract Addresses ---");
        console.log("FGOAccessControl:", address(contracts.accessControl));
        console.log("FGOSplitsData:", address(contracts.splitsData));
        console.log("FGOPatternChild:", address(contracts.patternChild));
        console.log("FGOMaterialChild:", address(contracts.materialChild));
        console.log(
            "FGOPrintDesignChild:",
            address(contracts.printDesignChild)
        );
        console.log(
            "FGOEmbellishmentsChild:",
            address(contracts.embellishmentsChild)
        );
        console.log(
            "FGOConstructionChild:",
            address(contracts.constructionChild)
        );
        console.log(
            "FGODigitalEffectsChild:",
            address(contracts.digitalEffectsChild)
        );
        console.log(
            "FGOFinishingTreatmentsChild:",
            address(contracts.finishingTreatmentsChild)
        );
        console.log(
            "FGOTemplatePackChild:",
            address(contracts.templatePackChild)
        );
        console.log("FGOParent:", address(contracts.parentFGO));
        console.log("FGODesigners:", address(contracts.designers));
        console.log("FGOSuppliers:", address(contracts.suppliers));
        console.log("FGOFulfillers:", address(contracts.fulfillers));
        console.log(
            "FGOWorkflowExecutor:",
            address(contracts.workflowExecutor)
        );
        console.log("CustomCompositeNFT:", address(contracts.customComposite));
        console.log("FGOMarket:", address(contracts.market));
        console.log("TestToken:", address(contracts.testToken));

        console.log("\n--- Configuration Status ---");
        console.log(
            "Market authorized in AccessControl:",
            contracts.accessControl.isAuthorizedMarket(
                address(contracts.market)
            )
        );
        console.log(
            "ParentFGO set in CustomComposite:",
            contracts.customComposite.parentFGO() ==
                address(contracts.parentFGO)
        );
        console.log(
            "Market authorized in CustomComposite:",
            contracts.customComposite.authorizedMarkets(
                address(contracts.market)
            )
        );
        console.log(
            "TestToken added as currency:",
            contracts.splitsData.getIsCurrency(address(contracts.testToken))
        );
        console.log(
            "Deployer is admin:",
            contracts.accessControl.isAdmin(msg.sender)
        );
    }
}
