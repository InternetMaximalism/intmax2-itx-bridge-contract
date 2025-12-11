// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import {Script, console} from "forge-std/Script.sol";
import {INTMAXToken} from "./INTMAXToken.sol";

// export PRIVATE_KEY=0xyour_private_key_here
// export ETHERSCAN_API_KEY=your_etherscan_api_key_here
// forge script script/old-token/ethereum/DeployINTMAXToken.s.sol:DeployINTMAXToken --rpc-url https://sepolia.rpc.thirdweb.com --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify

contract DeployINTMAXToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address adminAddress = vm.addr(deployerPrivateKey);
        address minterAddress = vm.addr(deployerPrivateKey);

        console.log("=== INTMAXToken Deployment Configuration ===");
        console.log("Deployer: %s", vm.addr(deployerPrivateKey));
        console.log("Admin Address: %s", adminAddress);
        console.log("Minter Address: %s", minterAddress);
        console.log("===============================================");

        vm.startBroadcast(deployerPrivateKey);

        INTMAXToken intmaxToken = new INTMAXToken(adminAddress, minterAddress);

        console.log("INTMAXToken deployed to: %s", address(intmaxToken));
        console.log("===============================================");

        vm.stopBroadcast();
    }
}
