// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import {Script, console} from "forge-std/Script.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";

contract ConfigureSenderOApp is Script {
    uint32 internal constant CONFIG_TYPE_ULN = 2;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Load environment variables for the specific chain
        address senderOappAddress = vm.envAddress("SENDER_OAPP");
        address endpoint = vm.envAddress("ENDPOINT");
        address dvn = vm.envAddress("DVN");
        uint32 dstEid = uint32(vm.envUint("DST_EID"));

        console.log("Configuring Sender OApp:", senderOappAddress);
        console.log("Endpoint:", endpoint);
        console.log("Destination EID:", dstEid);

        vm.startBroadcast(deployerPrivateKey);

        // Get the Send Library
        address sendLib = ILayerZeroEndpointV2(endpoint).getSendLibrary(senderOappAddress, dstEid);
        console.log("Send Library:", sendLib);

        // Prepare DVN configuration
        address[] memory requiredDVNs = new address[](1);
        requiredDVNs[0] = dvn;

        address[] memory optionalDVNs = new address[](0);

        UlnConfig memory ulnConfig = UlnConfig({
            confirmations: 15,
            requiredDVNCount: 1,
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: requiredDVNs,
            optionalDVNs: optionalDVNs
        });

        bytes memory configData = abi.encode(ulnConfig);

        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam({eid: dstEid, configType: CONFIG_TYPE_ULN, config: configData});

        // Set Config
        ILayerZeroEndpointV2(endpoint).setConfig(senderOappAddress, sendLib, params);
        console.log("DVN Config set for Sender OApp.");

        vm.stopBroadcast();
    }
}
