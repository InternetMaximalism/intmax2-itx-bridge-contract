// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {
    ILayerZeroEndpointV2
} from "lib/LayerZero-v2/packages/layerzero-v2/evm/protocol/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {
    SetConfigParam
} from "lib/LayerZero-v2/packages/layerzero-v2/evm/protocol/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "lib/LayerZero-v2/packages/layerzero-v2/evm/messagelib/contracts/uln/UlnBase.sol";

contract ConfigureEthereumBaseReceiver is Script {
    address internal constant ETH_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    address internal constant RECEIVE_LIB = 0xc02Ab410f0734EFa3F14628780e6e695156024C2;

    address internal constant LZ_LABS_DVN_ETH = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b;

    uint32 internal constant BASE_EID = 30184;
    uint32 internal constant CONFIG_TYPE_ULN = 2;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address receiverAddress = vm.envAddress("L1_RECEIVER_OAPP");
        vm.startBroadcast(deployerPrivateKey);

        // Required DVNs: LZ Labs DVN only
        address[] memory requiredDVNs = new address[](1);
        requiredDVNs[0] = LZ_LABS_DVN_ETH;

        address[] memory optionalDVNs = new address[](0);

        UlnConfig memory ulnConfig = UlnConfig({
            confirmations: 15, // Increased to 15 (>= 10 required by Ethereum)
            requiredDVNCount: 1,
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: requiredDVNs,
            optionalDVNs: optionalDVNs
        });

        bytes memory configData = abi.encode(ulnConfig);

        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam({eid: BASE_EID, configType: CONFIG_TYPE_ULN, config: configData});

        ILayerZeroEndpointV2(ETH_ENDPOINT).setConfig(receiverAddress, RECEIVE_LIB, params);
        console.log("DVN (ULN) Config set for Ethereum Receiver: LZ Labs DVN only, 15 confirmations.");

        vm.stopBroadcast();
    }
}
