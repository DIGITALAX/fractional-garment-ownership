// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import "../src/FGOAccessControl.sol";
import "../src/FGOSplitsData.sol";
import "../src/FGOWorkflowExecutor.sol";
import "../src/CustomCompositeNFT.sol";
import "../src/FGOMarket.sol";
import "../src/FGOCoinOpParent.sol";
import "../src/FGOFulfillers.sol";
import "../src/FGOPatternChild.sol";
import "../src/FGOMaterialChild.sol";
import "../src/FGOPrintDesignChild.sol";
import "../src/FGOEmbellishmentsChild.sol";
import "../src/FGOConstructionChild.sol";
import "../src/FGODigitalEffectsChild.sol";
import "../src/FGOFinishingTreatmentsChild.sol";
import "../src/FGOTemplatePackChild.sol";
import "../src/FGOPrintZoneChild.sol";
import "../src/TestToken.sol";

contract DeployMarket is Script {
    struct MarketContracts {
        FGOSplitsData splitsData;
        FGOWorkflowExecutor workflowExecutor;
        CustomCompositeNFT customComposite;
        FGOMarket market;
    }

    struct CoreAddresses {
        address accessControl;
        address coinOpParent;
        address fulfillers;
        address patternChild;
        address materialChild;
        address printDesignChild;
        address embellishmentsChild;
        address constructionChild;
        address digitalEffectsChild;
        address finishingTreatmentsChild;
        address templatePackChild;
        address printZoneChild;
        address testToken;
    }

    function run() external {
        vm.startBroadcast();

        console.log("=== FGO Market System Deployment ===");
        console.log("Deployer:", msg.sender);
        console.log("Chain ID:", block.chainid);

        CoreAddresses memory coreAddresses = getCoreAddresses();
        MarketContracts memory contracts = deployMarketContracts(coreAddresses);
        configureMarket(contracts, coreAddresses);
        verifyMarketDeployment(contracts, coreAddresses);
        logMarketAddresses(contracts);

        vm.stopBroadcast();

        console.log("=== Market Deployment Complete ===");
    }

    function getCoreAddresses() internal view returns (CoreAddresses memory) {
        console.log("\n--- Getting Core Contract Addresses ---");
        console.log("NOTE: Update these addresses from your core deployment!");
        
        return CoreAddresses({
            accessControl: 0x0000000000000000000000000000000000000000, // UPDATE THIS
            coinOpParent: 0x0000000000000000000000000000000000000000,   // UPDATE THIS
            fulfillers: 0x0000000000000000000000000000000000000000,     // UPDATE THIS
            patternChild: 0x0000000000000000000000000000000000000000,   // UPDATE THIS
            materialChild: 0x0000000000000000000000000000000000000000,  // UPDATE THIS
            printDesignChild: 0x0000000000000000000000000000000000000000, // UPDATE THIS
            embellishmentsChild: 0x0000000000000000000000000000000000000000, // UPDATE THIS
            constructionChild: 0x0000000000000000000000000000000000000000, // UPDATE THIS
            digitalEffectsChild: 0x0000000000000000000000000000000000000000, // UPDATE THIS
            finishingTreatmentsChild: 0x0000000000000000000000000000000000000000, // UPDATE THIS
            templatePackChild: 0x0000000000000000000000000000000000000000, // UPDATE THIS
            printZoneChild: 0x0000000000000000000000000000000000000000, // UPDATE THIS
            testToken: 0x0000000000000000000000000000000000000000      // UPDATE THIS
        });
    }

    function deployMarketContracts(
        CoreAddresses memory coreAddresses
    ) internal returns (MarketContracts memory contracts) {
        console.log("\n--- Step 1: Deploying Market Support Contracts ---");

        console.log("Deploying FGOSplitsData...");
        contracts.splitsData = new FGOSplitsData(coreAddresses.accessControl);

        console.log("Deploying FGOWorkflowExecutor...");
        contracts.workflowExecutor = new FGOWorkflowExecutor(
            coreAddresses.accessControl,
            coreAddresses.coinOpParent,
            coreAddresses.fulfillers
        );

        console.log("Deploying CustomCompositeNFT...");
        contracts.customComposite = new CustomCompositeNFT(
            coreAddresses.accessControl
        );

        console.log("\n--- Step 2: Deploying Market Contract ---");

        console.log("Deploying FGOMarket...");
        contracts.market = new FGOMarket(
            coreAddresses.accessControl,
            address(contracts.customComposite),
            coreAddresses.coinOpParent,
            address(contracts.splitsData),
            coreAddresses.fulfillers,
            coreAddresses.patternChild,
            coreAddresses.materialChild,
            coreAddresses.printDesignChild,
            coreAddresses.embellishmentsChild,
            coreAddresses.constructionChild,
            coreAddresses.digitalEffectsChild,
            coreAddresses.finishingTreatmentsChild,
            coreAddresses.templatePackChild,
            coreAddresses.printZoneChild,
            address(contracts.workflowExecutor)
        );

        return contracts;
    }

    function configureMarket(
        MarketContracts memory contracts,
        CoreAddresses memory coreAddresses
    ) internal {
        console.log("\n--- Step 3: Configuring Market System ---");

        FGOAccessControl accessControl = FGOAccessControl(coreAddresses.accessControl);

        console.log("Authorizing market in AccessControl...");
        accessControl.authorizeMarket(address(contracts.market));

        console.log("Setting up CustomComposite relationships...");
        contracts.customComposite.setParentFGO(coreAddresses.coinOpParent);
        contracts.customComposite.authorizeMarket(address(contracts.market));

        console.log("Setting up child type mappings in market...");
        contracts.market.setChildContract(0, coreAddresses.patternChild);
        contracts.market.setChildContract(1, coreAddresses.materialChild);
        contracts.market.setChildContract(2, coreAddresses.printDesignChild);
        contracts.market.setChildContract(3, coreAddresses.embellishmentsChild);
        contracts.market.setChildContract(4, coreAddresses.constructionChild);
        contracts.market.setChildContract(5, coreAddresses.digitalEffectsChild);
        contracts.market.setChildContract(6, coreAddresses.finishingTreatmentsChild);
        contracts.market.setChildContract(7, coreAddresses.templatePackChild);
        contracts.market.setChildContract(8, coreAddresses.printZoneChild);

        console.log("Adding default currency to SplitsData...");
        contracts.splitsData.addCurrency(
            coreAddresses.testToken,
            1e18, // 1 token wei amount
            1e18  // 1:1 exchange rate with wei
        );

        console.log("Setting default splits for TestToken...");
        contracts.splitsData.setSplits(
            coreAddresses.testToken,
            7500, // 75% to fulfiller
            1000 * 1e18, // 1000 token base amount
            1 // printType 1
        );

        console.log("Market configuration complete!");
    }

    function verifyMarketDeployment(
        MarketContracts memory contracts,
        CoreAddresses memory coreAddresses
    ) internal view {
        console.log("\n--- Step 4: Verifying Market Deployment ---");

        FGOAccessControl accessControl = FGOAccessControl(coreAddresses.accessControl);

        require(
            address(contracts.splitsData) != address(0),
            "SplitsData not deployed"
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
            accessControl.isAuthorizedMarket(address(contracts.market)),
            "Market not authorized"
        );
        require(
            contracts.customComposite.parentFGO() == coreAddresses.coinOpParent,
            "ParentFGO not set"
        );
        require(
            contracts.customComposite.authorizedMarkets(address(contracts.market)),
            "Market not authorized in CustomComposite"
        );
        require(
            contracts.splitsData.getIsCurrency(coreAddresses.testToken),
            "TestToken not added as currency"
        );

        console.log("All market verifications passed!");
    }

    function logMarketAddresses(MarketContracts memory contracts) internal view {
        console.log("\n--- Step 5: Market Contract Addresses ---");
        console.log("FGOSplitsData:", address(contracts.splitsData));
        console.log("FGOWorkflowExecutor:", address(contracts.workflowExecutor));
        console.log("CustomCompositeNFT:", address(contracts.customComposite));
        console.log("FGOMarket:", address(contracts.market));

        console.log("\n--- Child Type Mappings in Market ---");
        console.log("Type 0 (Pattern):", contracts.market.childTypeToContract(0));
        console.log("Type 1 (Material):", contracts.market.childTypeToContract(1));
        console.log("Type 2 (Print Design):", contracts.market.childTypeToContract(2));
        console.log("Type 3 (Embellishments):", contracts.market.childTypeToContract(3));
        console.log("Type 4 (Construction):", contracts.market.childTypeToContract(4));
        console.log("Type 5 (Digital Effects):", contracts.market.childTypeToContract(5));
        console.log("Type 6 (Finishing Treatments):", contracts.market.childTypeToContract(6));
        console.log("Type 7 (Template Pack):", contracts.market.childTypeToContract(7));
        console.log("Type 8 (Print Zone):", contracts.market.childTypeToContract(8));
    }
}