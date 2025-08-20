// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {BaseBridgeOApp} from "../src/BaseBridgeOApp.sol";

contract DeployBaseBridge is Script {
    function run() external {
        // Base Sepolia configuration
        address endpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f; // LayerZero V2 Endpoint Base Sepolia
        address token = 0x2699CD7f883DecC464171a7A92f4CcC4eF220fa2; // Base Sepolia ITX token
        uint32 dstEid = 40161; // Sepolia EID for LayerZero V2

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        BaseBridgeOApp baseBridge = new BaseBridgeOApp(
            endpoint, // endpoint
            deployer, // delegate
            deployer, // owner
            token, // token
            dstEid
        );
        console.log("Base Bridge deployed to:", address(baseBridge));
        console.log("Endpoint:", endpoint);
        console.log("Token:", token);
        console.log("Destination EID:", dstEid);
        console.log("Owner:", deployer);

        vm.stopBroadcast();
    }
}
