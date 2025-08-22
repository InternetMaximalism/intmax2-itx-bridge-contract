// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {MainnetBridgeOApp} from "../src/MainnetBridgeOApp.sol";

contract DeployMainnetBridge is Script {
    function run() external {
        // Load configuration from environment variables
        address endpoint = vm.envAddress("MAINNET_ENDPOINT");
        address token = vm.envAddress("MAINNET_TOKEN");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Display configuration
        console.log("=== Mainnet Bridge Deployment Configuration ===");
        console.log("Endpoint:", endpoint);
        console.log("Token:", token);
        console.log("Deployer:", deployer);
        console.log("==============================================");

        vm.startBroadcast(deployerPrivateKey);

        MainnetBridgeOApp mainnetBridge = new MainnetBridgeOApp(
            endpoint, // endpoint
            deployer, // delegate
            deployer, // owner
            token // token
        );

        console.log("=== Deployment Summary ===");
        console.log("MainnetBridgeOApp:", address(mainnetBridge));
        console.log("=========================");

        vm.stopBroadcast();
    }
}
