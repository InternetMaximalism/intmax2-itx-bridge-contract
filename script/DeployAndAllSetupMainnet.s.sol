// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {DeployReceiverBridge, ReceiverBridgeOApp} from "./DeployReceiverBridge.s.sol";
import {DeploySenderBridge, SenderBridgeOApp} from "./DeploySenderBridge.s.sol";
import {ConfigureSenderOApp} from "./ConfigureSenderOApp.s.sol";
import {ConfigureReceiverOApp} from "./ConfigureReceiverOApp.s.sol";
import {
    LayerZeroV2BaseMainnet,
    LayerZeroV2DVNBaseMainnet,
    LayerZeroV2EthereumMainnet,
    LayerZeroV2DVNEthereumMainnet,
    LayerZeroV2ScrollMainnet,
    LayerZeroV2DVNScrollMainnet
} from "lz-address-book/generated/LZAddresses.sol";

// forge script script/DeployAllMainnet.s.sol:DeployAllMainnet --broadcast --verify
contract DeployAndAllSetupMainnet is Script {
    // Fork IDs
    uint256 private scrollFork;
    uint256 private ethFork;
    uint256 private baseFork;

    function run() external {
        // Create forks
        scrollFork = vm.createFork("scroll");
        ethFork = vm.createFork("ethereum");
        baseFork = vm.createFork("base");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer Address:", deployer);

        address ethReceiver = deployEthereumReceiver();
        address scrollSender = deployScrollSender();
        address baseSender = deployBaseSender();

        setSenderPeer(scrollFork, scrollSender, ethReceiver);
        setSenderPeer(baseFork, baseSender, ethReceiver);

        setReceiverPeer(LayerZeroV2ScrollMainnet.EID, ethReceiver, scrollSender);
        setReceiverPeer(LayerZeroV2BaseMainnet.EID, ethReceiver, baseSender);

        setupSenderConfig(
            scrollFork,
            address(LayerZeroV2ScrollMainnet.ENDPOINT_V2),
            scrollSender,
            LayerZeroV2EthereumMainnet.EID,
            LayerZeroV2DVNScrollMainnet.DVN_LAYERZERO_LABS
        );
        setupSenderConfig(
            baseFork,
            address(LayerZeroV2BaseMainnet.ENDPOINT_V2),
            baseSender,
            LayerZeroV2EthereumMainnet.EID,
            LayerZeroV2DVNBaseMainnet.DVN_LAYERZERO_LABS_2
        );

        setupReceiverConfig(
            address(LayerZeroV2EthereumMainnet.ENDPOINT_V2),
            ethReceiver,
            LayerZeroV2ScrollMainnet.EID,
            LayerZeroV2DVNEthereumMainnet.DVN_LAYERZERO_LABS
        );
        setupReceiverConfig(
            address(LayerZeroV2EthereumMainnet.ENDPOINT_V2),
            ethReceiver,
            LayerZeroV2BaseMainnet.EID,
            LayerZeroV2DVNEthereumMainnet.DVN_LAYERZERO_LABS
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
        sender.setPeer(LayerZeroV2EthereumMainnet.EID, bytes32(uint256(uint160(ethReceiver))));
        vm.stopBroadcast();
        console.log("set sender peer on fork:", forkId);
    }

    function deployScrollSender() private returns (address) {
        vm.selectFork(scrollFork);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        DeploySenderBridge deploySender = new DeploySenderBridge();
        address sender = deploySender.deploy(
            address(LayerZeroV2ScrollMainnet.ENDPOINT_V2),
            vm.envAddress("SCROLL_DELEGATE"),
            vm.envAddress("SCROLL_OWNER"),
            vm.envAddress("SCROLL_OLD_TOKEN"),
            LayerZeroV2EthereumMainnet.EID
        );
        vm.stopBroadcast();
        return sender;
    }

    function deployBaseSender() private returns (address) {
        vm.selectFork(baseFork);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        DeploySenderBridge deploySender = new DeploySenderBridge();
        address sender = deploySender.deploy(
            address(LayerZeroV2BaseMainnet.ENDPOINT_V2),
            vm.envAddress("BASE_DELEGATE"),
            vm.envAddress("BASE_OWNER"),
            vm.envAddress("BASE_OLD_TOKEN"),
            LayerZeroV2EthereumMainnet.EID
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
            address(LayerZeroV2EthereumMainnet.ENDPOINT_V2),
            vm.envAddress("ETHEREUM_DELEGATE"),
            vm.envAddress("ETHEREUM_OWNER"),
            vm.envAddress("ETHEREUM_VESTING_CONTRACT")
        );
        vm.stopBroadcast();
        return receiver;
    }
}
