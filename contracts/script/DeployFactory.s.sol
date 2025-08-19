// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import "../src/FGOFactory.sol";
import "../src/TestToken.sol";

contract DeployFactory is Script {
    using stdJson for string;

    struct FactoryContracts {
        TestToken testToken;
        FGOFactory factory;
    }

    function run() external {
        console.log("=== FGO Factory Deployment ===");
        console.log("Deployer:", msg.sender);
        console.log("Chain ID:", block.chainid);

        vm.startBroadcast();

        // console.log("\n--- Step 1: Deploying Payment Token ---");
        // console.log("Deploying TestToken...");
        // new TestToken();

        console.log("\n--- Step 2: Deploying FGO Factory ---");
        console.log("Deploying FGOFactory...");
        new FGOFactory();

        vm.stopBroadcast();

        console.log("\n--- DEPLOYMENT COMPLETE ---");
        console.log(
            "IMPORTANT: The real contract addresses will be in the broadcast JSON file:"
        );
        console.log(
            "Path:",
            string.concat(
                "broadcast/DeployFactory.s.sol/",
                vm.toString(block.chainid),
                "/run-latest.json"
            )
        );
        console.log("Look for 'contractAddress' fields in the receipts array");
        console.log("Order: TestToken (receipts[0]), FGOFactory (receipts[1])");
        console.log("=== Factory Deployment Complete ===");
    }
}
