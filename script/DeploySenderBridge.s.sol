// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {SenderBridgeOApp} from "../src/SenderBridgeOApp.sol";
import {BridgeStorage} from "../src/BridgeStorage.sol";

// forge script script/DeploySenderBridge.s.sol:DeploySenderBridge --rpc-url https://base.meowrpc.com --broadcast --etherscan-api-key ${API KEY} --verify
contract DeploySenderBridge is Script {
    function run() external {
        // Load configuration from environment variables
        address endpoint = vm.envAddress("L2_ENDPOINT");
        address token = vm.envAddress("L2_TOKEN");
        uint32 dstEid = uint32(vm.envUint("L2_DST_EID"));

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Display configuration
        console.log("=== Sender Bridge Deployment Configuration ===");
        console.log("Endpoint:", endpoint);
        console.log("Token:", token);
        console.log("Destination EID:", dstEid);
        console.log("Deployer:", deployer);
        console.log("===========================================");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy BridgeStorage contract first
        BridgeStorage bridgeStorage = new BridgeStorage(deployer);
        console.log("Bridge Storage deployed to:", address(bridgeStorage));

        // Deploy SenderBridgeOApp
        SenderBridgeOApp senderBridge = new SenderBridgeOApp(
            endpoint, // endpoint
            deployer, // delegate
            deployer, // owner
            token, // token
            dstEid // destination EID
        );
        console.log("Sender Bridge deployed to:", address(senderBridge));

        // Set bridge storage in SenderBridgeOApp
        senderBridge.setBridgeStorage(address(bridgeStorage));
        console.log("Bridge storage set in SenderBridgeOApp");

        // Transfer ownership of BridgeStorage to SenderBridgeOApp
        bridgeStorage.transferOwnership(address(senderBridge));
        console.log("BridgeStorage ownership transferred to SenderBridgeOApp");

        console.log("=== Deployment Summary ===");
        console.log("SenderBridgeOApp:", address(senderBridge));
        console.log("BridgeStorage:", address(bridgeStorage));
        console.log("=========================");

        vm.stopBroadcast();
    }
}
