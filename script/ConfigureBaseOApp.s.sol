// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {
    ILayerZeroEndpointV2
} from "lib/LayerZero-v2/packages/layerzero-v2/evm/protocol/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {
    SetConfigParam
} from "lib/LayerZero-v2/packages/layerzero-v2/evm/protocol/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "lib/LayerZero-v2/packages/layerzero-v2/evm/messagelib/contracts/uln/UlnBase.sol"; // UlnConfigを直接インポート

contract ConfigureBaseOApp is Script {
    address private constant ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    address private constant GOOGLE_DVN = 0xD56e4eAb23cb81f43168F9F45211Eb027b9aC7cc;
    uint32 internal constant ETH_EID = 30101;
    uint32 internal constant CONFIG_TYPE_ULN = 2; // Defined in SendUln302.sol

    function run() external {
        address senderOappAddress = vm.envAddress("BASE_SENDER_OAPP");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address sendLib = ILayerZeroEndpointV2(ENDPOINT).getSendLibrary(senderOappAddress, ETH_EID);
        console.log("Send Library:", sendLib);

        // Prepare DVN configuration (UlnConfig)
        address[] memory requiredDVNs = new address[](1);
        requiredDVNs[0] = GOOGLE_DVN;

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

        // Prepare SetConfigParam array for setConfig
        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam({eid: ETH_EID, configType: CONFIG_TYPE_ULN, config: configData});

        // Call setConfig on the Endpoint
        // setConfig(address _oapp, address _lib, SetConfigParam[] calldata _params)
        ILayerZeroEndpointV2(ENDPOINT).setConfig(senderOappAddress, sendLib, params);
        console.log("DVN (ULN) Config set for Base Sender OApp to Ethereum EID.");

        vm.stopBroadcast();
    }
}
