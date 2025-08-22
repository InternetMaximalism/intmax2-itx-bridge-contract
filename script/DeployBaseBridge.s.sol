// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {BaseBridgeOApp} from "../src/BaseBridgeOApp.sol";
import {BridgeStorage} from "../src/BridgeStorage.sol";

contract DeployBaseBridge is Script {
    function run() external {
        // Load configuration from environment variables
        address endpoint = vm.envAddress("BASE_ENDPOINT");
        address token = vm.envAddress("BASE_TOKEN");
        uint32 dstEid = uint32(vm.envUint("BASE_DST_EID"));

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Display configuration
        console.log("=== Base Bridge Deployment Configuration ===");
        console.log("Endpoint:", endpoint);
        console.log("Token:", token);
        console.log("Destination EID:", dstEid);
        console.log("Deployer:", deployer);
        console.log("===========================================");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy BridgeStorage contract first
        BridgeStorage bridgeStorage = new BridgeStorage(deployer);
        console.log("Bridge Storage deployed to:", address(bridgeStorage));

        // Deploy BaseBridgeOApp
        BaseBridgeOApp baseBridge = new BaseBridgeOApp(
            endpoint, // endpoint
            deployer, // delegate
            deployer, // owner
            token, // token
            dstEid // destination EID
        );
        console.log("Base Bridge deployed to:", address(baseBridge));

        // Set bridge storage in BaseBridgeOApp
        baseBridge.setBridgeStorage(address(bridgeStorage));
        console.log("Bridge storage set in BaseBridgeOApp");

        // Transfer ownership of BridgeStorage to BaseBridgeOApp
        bridgeStorage.transferOwnership(address(baseBridge));
        console.log("BridgeStorage ownership transferred to BaseBridgeOApp");

        console.log("=== Deployment Summary ===");
        console.log("BaseBridgeOApp:", address(baseBridge));
        console.log("BridgeStorage:", address(bridgeStorage));
        console.log("=========================");

        vm.stopBroadcast();
    }
}
