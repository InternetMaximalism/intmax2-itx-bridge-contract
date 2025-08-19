// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {MainnetBridgeOApp} from "../src/MainnetBridgeOApp.sol";

contract DeployMainnetBridge is Script {
    function run() external {
        // Sepolia configuration
        address endpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f; // LayerZero V2 Endpoint Sepolia
        address token = 0xA78B3d7db31EC214a33c5C383B606DA8B87DF41F; // Sepolia ITX token
        uint32 srcEid = 40245; // Base Sepolia EID for LayerZero V2

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // This should be set to the deployed Base Bridge address after deployment
        address baseBridgeAddress = vm.envOr("BASE_BRIDGE_ADDRESS", address(0x0));
        bytes32 srcSender = bytes32(uint256(uint160(baseBridgeAddress)));

        vm.startBroadcast(deployerPrivateKey);

        MainnetBridgeOApp mainnetBridge = new MainnetBridgeOApp(endpoint, token, deployer, srcEid, srcSender);

        vm.stopBroadcast();

        console.log("Mainnet Bridge deployed to:", address(mainnetBridge));
        console.log("Endpoint:", endpoint);
        console.log("Token:", token);
        console.log("Source EID:", srcEid);
        console.log("Source Sender:", baseBridgeAddress);
        console.log("Owner:", deployer);
    }
}
