// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import {Script, console} from "forge-std/Script.sol";
import {ScrollINTMAXToken} from "./ScrollINTMAXToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// export PRIVATE_KEY=0xyour_private_key_here
// export SCROLLSCAN_API_KEY=your_scrollscan_api_key_here
// forge script script/old-token/scroll/DeployScrollINTMAXToken.s.sol:DeployScrollINTMAXToken --rpc-url https://sepolia-rpc.scroll.io --broadcast --etherscan-api-key $SCROLLSCAN_API_KEY --verify
contract DeployScrollINTMAXToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address adminAddress = vm.addr(deployerPrivateKey);
        address rewardContractAddress = vm.addr(deployerPrivateKey);
        uint256 mintAmount = 1_000_000 * (10 ** 18); // 1 million tokens with 18 decimals

        console.log("=== ScrollINTMAXToken Deployment Configuration ===");
        console.log("Deployer: %s", vm.addr(deployerPrivateKey));
        console.log("Admin Address: %s", adminAddress);
        console.log("Reward Contract Address: %s", rewardContractAddress);
        console.log("Mint Amount: %s", mintAmount);
        console.log("===============================================");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy the implementation contract
        ScrollINTMAXToken implementation = new ScrollINTMAXToken();
        console.log("ScrollINTMAXToken Implementation deployed to: %s", address(implementation));

        // 2. Encode the initializer call
        bytes memory initializerData =
            abi.encodeCall(ScrollINTMAXToken.initialize, (adminAddress, rewardContractAddress, mintAmount));

        // 3. Deploy the ERC1967Proxy, pointing to the implementation and initializing it
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initializerData);
        console.log("ScrollINTMAXToken Proxy deployed to: %s", address(proxy));
        console.log("===============================================");

        vm.stopBroadcast();
    }
}
