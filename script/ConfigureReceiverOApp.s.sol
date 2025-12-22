// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";

contract ConfigureReceiverOApp is Script {
    uint32 internal constant CONFIG_TYPE_ULN = 2;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address baseEndPoint = vm.envAddress("BASE_ENDPOINT");
        address receiverAddress = vm.envAddress("RECEIVER_OAPP");
        address dvn = vm.envAddress("DVN");
        uint32 srcEid = uint32(vm.envUint("SRC_EID"));
        vm.startBroadcast(deployerPrivateKey);
        // Configure DVN for Ethereum -> Base
        setupConfig(baseEndPoint, receiverAddress, srcEid, dvn);
        vm.stopBroadcast();
    }

    function setupConfig(address _endpoint, address _oapp, uint32 _srcEid, address _dvn) public {
        console.log("Endpoint:", _endpoint);
        console.log("Configuring Receiver OApp:", _oapp);
        console.log("Source EID:", _srcEid);
        console.log("DVN:", _dvn);
        // Retrieve the default Receive Library for the source chain
        // Note: For custom config, we often set config on the specific library used by the channel.
        // Here we assume we modify the config for the OApp's receive library.
        (address receiveLib,) = ILayerZeroEndpointV2(_endpoint).getReceiveLibrary(_oapp, _srcEid);
        console.log("Configuring Receive Lib:", receiveLib, "for Source EID:", _srcEid);

        address[] memory requiredDVNs = new address[](1);
        requiredDVNs[0] = _dvn; // Use provided DVN to verify messages on Base

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
        params[0] = SetConfigParam({eid: _srcEid, configType: CONFIG_TYPE_ULN, config: configData});
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        ILayerZeroEndpointV2(_endpoint).setConfig(_oapp, receiveLib, params);
        vm.stopBroadcast();
        console.log("DVN Configured for Source EID:", _srcEid);
    }
}
