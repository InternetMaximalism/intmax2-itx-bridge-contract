// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {MainnetBridgeOApp} from "../src/MainnetBridgeOApp.sol";

contract DeployMainnetBridge is Script {
    function run() external {
        // Load configuration from environment variables
        address endpoint = vm.envAddress("MAINNET_ENDPOINT");
        address token = vm.envAddress("MAINNET_TOKEN");
        uint32 srcEid = uint32(vm.envUint("MAINNET_SRC_EID"));

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Load source sender from env, fallback to zero address if not set
        bytes32 srcSender;
        try vm.envBytes32("MAINNET_SRC_SENDER") returns (bytes32 envSrcSender) {
            srcSender = envSrcSender;
            console.log("Using source sender from env");
        } catch {
            // Try to get BASE_BRIDGE_ADDRESS and convert to bytes32
            try vm.envAddress("BASE_BRIDGE_ADDRESS") returns (address baseBridgeAddress) {
                srcSender = bytes32(uint256(uint160(baseBridgeAddress)));
                console.log("Using BASE_BRIDGE_ADDRESS as source sender:", baseBridgeAddress);
            } catch {
                srcSender = bytes32(0);
                console.log("Warning: No source sender set, using zero address");
            }
        }

        // Display configuration
        console.log("=== Mainnet Bridge Deployment Configuration ===");
        console.log("Endpoint:", endpoint);
        console.log("Token:", token);
        console.log("Source EID:", srcEid);
        console.log("Source Sender (address):", address(uint160(uint256(srcSender))));
        console.log("Deployer:", deployer);
        console.log("==============================================");

        vm.startBroadcast(deployerPrivateKey);

        MainnetBridgeOApp mainnetBridge = new MainnetBridgeOApp(
            endpoint, // endpoint
            deployer, // delegate
            deployer, // owner
            token, // token
            srcEid,
            srcSender
        );
        
        console.log("=== Deployment Summary ===");
        console.log("MainnetBridgeOApp:", address(mainnetBridge));
        console.log("=========================");

        vm.stopBroadcast();
    }
}
