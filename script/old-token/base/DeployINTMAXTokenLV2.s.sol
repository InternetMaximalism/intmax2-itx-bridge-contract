// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {INTMAXTokenLV2} from "./INTMAXTokenLV2.sol";

// export PRIVATE_KEY=0xyour_private_key_here
// export BASESCAN_API_KEY=your_basescan_api_key_here
// forge script script/old-token/base/DeployINTMAXTokenLV2.s.sol:DeployINTMAXTokenLV2 --rpc-url https://sepolia.base.org --broadcast --etherscan-api-key $BASESCAN_API_KEY --verify

contract DeployINTMAXTokenLV2 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address adminAddress = vm.addr(deployerPrivateKey);

        console.log("=== INTMAXTokenLV2 Deployment Configuration ===");
        console.log("Deployer: %s", vm.addr(deployerPrivateKey));
        console.log("Admin Address: %s", adminAddress);
        console.log("===============================================");

        vm.startBroadcast(deployerPrivateKey);

        INTMAXTokenLV2 intmaxToken = new INTMAXTokenLV2(adminAddress);

        console.log("INTMAXTokenLV2 deployed to: %s", address(intmaxToken));
        console.log("===============================================");

        vm.stopBroadcast();
    }
}
