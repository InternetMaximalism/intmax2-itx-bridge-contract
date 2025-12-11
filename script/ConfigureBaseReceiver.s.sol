// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import {Script, console} from "forge-std/Script.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";

contract ConfigureBaseReceiver is Script {
    // Base Mainnet Constants
    address internal constant BASE_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    address internal constant BASE_LZ_DVN = 0x9e059a54699a285714207b43B055483E78FAac25;

    uint32 internal constant ETH_EID = 30101;
    uint32 internal constant SCROLL_EID = 30214;
    uint32 internal constant CONFIG_TYPE_ULN = 2;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address receiverAddress = vm.envAddress("RECEIVER_OAPP"); // Deployed on Base

        vm.startBroadcast(deployerPrivateKey);

        // Configure DVN for Ethereum -> Base
        _configureDVN(receiverAddress, ETH_EID);

        // Configure DVN for Scroll -> Base
        _configureDVN(receiverAddress, SCROLL_EID);

        vm.stopBroadcast();
    }

    function _configureDVN(address _oapp, uint32 _srcEid) internal {
        // Retrieve the default Receive Library for the source chain
        // Note: For custom config, we often set config on the specific library used by the channel.
        // Here we assume we modify the config for the OApp's receive library.
        (address receiveLib,) = ILayerZeroEndpointV2(BASE_ENDPOINT).getReceiveLibrary(_oapp, _srcEid);
        console.log("Configuring Receive Lib:", receiveLib, "for Source EID:", _srcEid);

        address[] memory requiredDVNs = new address[](1);
        requiredDVNs[0] = BASE_LZ_DVN; // Use Base DVN to verify messages on Base

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

        ILayerZeroEndpointV2(BASE_ENDPOINT).setConfig(_oapp, receiveLib, params);
        console.log("DVN Configured for Source EID:", _srcEid);
    }
}
