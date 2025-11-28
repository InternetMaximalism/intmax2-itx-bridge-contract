// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {ReceiverBridgeOApp} from "../src/ReceiverBridgeOApp.sol";

// forge script script/DeployReceiverBridge.s.sol:DeployReceiverBridge --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify
contract DeployReceiverBridge is Script {
    function run() external {
        // Load configuration from environment variables
        address endpoint = vm.envAddress("MAINNET_ENDPOINT");
        address token = vm.envAddress("MAINNET_TOKEN");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Display configuration
        console.log("=== Receiver Bridge Deployment Configuration ===");
        console.log("Endpoint:", endpoint);
        console.log("Token:", token);
        console.log("Deployer:", deployer);
        console.log("==============================================");

        vm.startBroadcast(deployerPrivateKey);

        ReceiverBridgeOApp receiverBridge = new ReceiverBridgeOApp(
            endpoint, // endpoint
            deployer, // delegate
            deployer, // owner
            token // token
        );

        console.log("=== Deployment Summary ===");
        console.log("ReceiverBridgeOApp:", address(receiverBridge));
        console.log("=========================");

        vm.stopBroadcast();
    }
}
