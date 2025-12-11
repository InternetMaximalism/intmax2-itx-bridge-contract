// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import {Script, console} from "forge-std/Script.sol";
import {SenderBridgeOApp} from "../src/SenderBridgeOApp.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// forge script script/DeploySenderBridge.s.sol:DeploySenderBridge --rpc-url <RPC> --broadcast --verify
contract DeploySenderBridge is Script {
    function run() external {
        // Load configuration from environment variables
        address endpoint = vm.envAddress("ENDPOINT");
        address token = vm.envAddress("TOKEN");
        uint32 dstEid = uint32(vm.envUint("DST_EID"));

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        deploy(endpoint, deployer, deployer, token, dstEid);

        vm.stopBroadcast();
    }

    function deploy(address endpoint, address delegate, address owner, address token, uint32 dstEid)
        public
        returns (address)
    {
        // Display configuration
        console.log("=== Sender Bridge Deployment Configuration ===");
        console.log("Endpoint:", endpoint);
        console.log("Delegate:", delegate);
        console.log("Owner:", owner);
        console.log("Token:", token);
        console.log("Destination EID:", dstEid);
        console.log("==============================================");

        // 1. Deploy Implementation
        // Constructor: (address _endpoint, address _token, uint32 _dstEid)
        SenderBridgeOApp implementation = new SenderBridgeOApp(endpoint, token, dstEid);
        console.log("Sender Bridge Implementation deployed to:", address(implementation));

        // 2. Prepare initialization data
        // initialize(address _delegate, address _owner)
        bytes memory initData = abi.encodeCall(
            SenderBridgeOApp.initialize,
            (delegate, owner) // _delegate, _owner
        );

        // 3. Deploy Proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console.log("Sender Bridge Proxy deployed to:", address(proxy));

        console.log("=== Deployment Summary ===");
        console.log("Proxy Address (Use this):", address(proxy));
        console.log("Implementation Address:", address(implementation));
        console.log("=========================");

        return address(proxy);
    }
}
