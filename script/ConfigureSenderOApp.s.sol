// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";

contract ConfigureSenderOApp is Script {
    uint32 internal constant CONFIG_TYPE_ULN = 2;

    function run() external {
        // Load environment variables for the specific chain
        address senderOappAddress = vm.envAddress("SENDER_OAPP");
        address endpoint = vm.envAddress("ENDPOINT");
        address dvn = vm.envAddress("DVN");
        uint32 dstEid = uint32(vm.envUint("DST_EID"));
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        setupConfig(endpoint, senderOappAddress, dstEid, dvn);
        vm.stopBroadcast();
    }

    function setupConfig(address _endpoint, address _oapp, uint32 _dstEid, address _dvn) public {
        console.log("Configuring Sender OApp:", _oapp);
        console.log("Endpoint:", _endpoint);
        console.log("Destination EID:", _dstEid);
        console.log("DVN:", _dvn);
        address sendLib = ILayerZeroEndpointV2(_endpoint).getSendLibrary(_oapp, _dstEid);
        console.log("Send Library:", sendLib);

        address[] memory requiredDVNAddresses = new address[](1);
        requiredDVNAddresses[0] = _dvn;
        address[] memory optionalDVNAddresses = new address[](0);
        UlnConfig memory ulnConfig = UlnConfig({
            confirmations: 15,
            requiredDVNCount: 1,
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: requiredDVNAddresses,
            optionalDVNs: optionalDVNAddresses
        });
        bytes memory configData = abi.encode(ulnConfig);
        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam({eid: _dstEid, configType: CONFIG_TYPE_ULN, config: configData});
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        ILayerZeroEndpointV2(_endpoint).setConfig(_oapp, sendLib, params);
        vm.stopBroadcast();
        console.log("DVN Config set for Sender OApp.");
    }
}
