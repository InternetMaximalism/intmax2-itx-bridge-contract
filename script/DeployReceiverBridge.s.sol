// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import {Script, console} from "forge-std/Script.sol";
import {ReceiverBridgeOApp} from "../src/ReceiverBridgeOApp.sol";

// forge script script/DeployReceiverBridge.s.sol:DeployReceiverBridge --rpc-url <RPC> --broadcast --verify
contract DeployReceiverBridge is Script {
    function run() external {
        // Load configuration from environment variables
        address endpoint = vm.envAddress("ENDPOINT");
        address token = vm.envAddress("TOKEN");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        deploy(endpoint, token, deployer, deployer);

        vm.stopBroadcast();
    }

    function deploy(address endpoint, address delegate, address owner, address token) public returns (address) {
        // Display configuration
        console.log("=== Receiver Bridge Deployment Configuration ===");
        console.log("Endpoint:", endpoint);
        console.log("Delegate:", delegate);
        console.log("Owner:", owner);
        console.log("Token:", token);
        console.log("==============================================");
        ReceiverBridgeOApp receiverBridge = new ReceiverBridgeOApp(endpoint, delegate, owner, token);
        console.log("=== Deployment Summary ===");
        console.log("ReceiverBridgeOApp:", address(receiverBridge));
        console.log("=========================");
        return address(receiverBridge);
    }
}
