// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {DeployReceiverBridge, ReceiverBridgeOApp} from "./DeployReceiverBridge.s.sol";
import {DeploySenderBridge, SenderBridgeOApp} from "./DeploySenderBridge.s.sol";
import {ConfigureSenderOApp} from "./ConfigureSenderOApp.s.sol";
import {ConfigureReceiverOApp} from "./ConfigureReceiverOApp.s.sol";
import {
    LayerZeroV2BasesepTestnet,
    LayerZeroV2DVNBasesepTestnet,
    LayerZeroV2SepoliaTestnet,
    LayerZeroV2DVNSepoliaTestnet
} from "lz-address-book/generated/LZAddresses.sol";

// forge script script/DeployAndAllSetupTestnet.s.sol:DeployAndAllSetupTestnet --broadcast --verify
contract DeployAndAllSetupTestnet is Script {
    // Fork IDs
    uint256 private ethFork;
    uint256 private baseFork;

    function run() external {
        // Create forks
        ethFork = vm.createFork("ethereum");
        baseFork = vm.createFork("base");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer Address:", deployer);

        address ethReceiver = deployEthereumReceiver();
        address baseSender = deployBaseSender();

        setSenderPeer(baseFork, baseSender, ethReceiver);

        setReceiverPeer(LayerZeroV2BasesepTestnet.EID, ethReceiver, baseSender);

        setupSenderConfig(
            baseFork,
            address(LayerZeroV2BasesepTestnet.ENDPOINT_V2),
            baseSender,
            LayerZeroV2SepoliaTestnet.EID,
            LayerZeroV2DVNBasesepTestnet.DVN_LAYERZERO_LABS_2
        );

        setupReceiverConfig(
            address(LayerZeroV2SepoliaTestnet.ENDPOINT_V2),
            ethReceiver,
            LayerZeroV2BasesepTestnet.EID,
            LayerZeroV2DVNSepoliaTestnet.DVN_LAYERZERO_LABS
        );
    }

    function setupReceiverConfig(address endpoint, address receiverAddress, uint32 srcEid, address dvn) private {
        vm.selectFork(ethFork);
        ConfigureReceiverOApp configureReceiver = new ConfigureReceiverOApp();
        configureReceiver.setupConfig(endpoint, receiverAddress, srcEid, dvn);
    }

    function setupSenderConfig(uint256 forkId, address endpoint, address senderAddress, uint32 dstEid, address dvn)
        private
    {
        vm.selectFork(forkId);
        ConfigureSenderOApp configureSender = new ConfigureSenderOApp();
        configureSender.setupConfig(endpoint, senderAddress, dstEid, dvn);
    }

    function setReceiverPeer(uint32 senderEid, address receiverAddress, address senderAddress) private {
        vm.selectFork(ethFork);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        ReceiverBridgeOApp receiver = ReceiverBridgeOApp(receiverAddress);
        receiver.setPeer(senderEid, bytes32(uint256(uint160(senderAddress))));
        vm.stopBroadcast();
        console.log("set receiver peer for eid:", senderEid);
    }

    function setSenderPeer(uint256 forkId, address senderAddress, address ethReceiver) private {
        vm.selectFork(forkId);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        SenderBridgeOApp sender = SenderBridgeOApp(senderAddress);
        sender.setPeer(LayerZeroV2SepoliaTestnet.EID, bytes32(uint256(uint160(ethReceiver))));
        vm.stopBroadcast();
        console.log("set sender peer on fork:", forkId);
    }

    function deployBaseSender() private returns (address) {
        vm.selectFork(baseFork);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        DeploySenderBridge deploySender = new DeploySenderBridge();
        address sender = deploySender.deploy(
            address(LayerZeroV2BasesepTestnet.ENDPOINT_V2),
            vm.envAddress("BASE_DELEGATE"),
            vm.envAddress("BASE_OWNER"),
            vm.envAddress("BASE_OLD_TOKEN"),
            LayerZeroV2SepoliaTestnet.EID
        );
        vm.stopBroadcast();
        return sender;
    }

    function deployEthereumReceiver() private returns (address) {
        vm.selectFork(ethFork);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        DeployReceiverBridge deployReceiver = new DeployReceiverBridge();
        address receiver = deployReceiver.deploy(
            address(LayerZeroV2SepoliaTestnet.ENDPOINT_V2),
            vm.envAddress("ETHEREUM_DELEGATE"),
            vm.envAddress("ETHEREUM_OWNER"),
            vm.envAddress("ETHEREUM_VESTING_CONTRACT")
        );
        vm.stopBroadcast();
        return receiver;
    }
}
