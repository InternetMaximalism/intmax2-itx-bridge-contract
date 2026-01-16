// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {DeployReceiverBridge, ReceiverBridgeOApp} from "./DeployReceiverBridge.s.sol";
import {DeploySenderBridge, SenderBridgeOApp} from "./DeploySenderBridge.s.sol";
import {ConfigureSenderOApp} from "./ConfigureSenderOApp.s.sol";
import {ConfigureReceiverOApp} from "./ConfigureReceiverOApp.s.sol";

// forge script script/DeployAndAllSetupTestnet.s.sol:DeployAndAllSetupTestnet --broadcast --verify
contract DeployAndAllSetupTestnet is Script {
    // solhint-disable-next-line state-visibility
    uint32 constant BASE_EID = 40245;
    // solhint-disable-next-line state-visibility
    uint32 constant ETHEREUM_EID = 40161;

    // solhint-disable-next-line state-visibility
    address constant ETHEREUM_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    // solhint-disable-next-line state-visibility
    address constant BASE_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    // solhint-disable-next-line state-visibility
    address constant ETHEREUM_LAYER_ZERO_DVN = 0x8eebf8b423B73bFCa51a1Db4B7354AA0bFCA9193;
    // solhint-disable-next-line state-visibility
    address constant BASE_LAYER_ZERO_DVN = 0xe1a12515F9AB2764b887bF60B923Ca494EBbB2d6;

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

        address ethSender = deployEthereumSender();
        address baseReceiver = deployBaseReceiver();

        setSenderPeer(ethFork, ethSender, baseReceiver);

        setReceiverPeer(ETHEREUM_EID, baseReceiver, ethSender);

        setupSenderConfig(ethFork, ETHEREUM_ENDPOINT, ethSender, BASE_EID, ETHEREUM_LAYER_ZERO_DVN);

        setupReceiverConfig(BASE_ENDPOINT, baseReceiver, ETHEREUM_EID, BASE_LAYER_ZERO_DVN);
    }

    function setupReceiverConfig(address endpoint, address receiverAddress, uint32 srcEid, address dvn) private {
        vm.selectFork(baseFork);
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
        vm.selectFork(baseFork);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        ReceiverBridgeOApp receiver = ReceiverBridgeOApp(receiverAddress);
        receiver.setPeer(senderEid, bytes32(uint256(uint160(senderAddress))));
        vm.stopBroadcast();
        console.log("set receiver peer for eid:", senderEid);
    }

    function setSenderPeer(uint256 forkId, address senderAddress, address baseReceiver) private {
        vm.selectFork(forkId);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        SenderBridgeOApp sender = SenderBridgeOApp(senderAddress);
        sender.setPeer(BASE_EID, bytes32(uint256(uint160(baseReceiver))));
        vm.stopBroadcast();
        console.log("set sender peer on fork:", forkId);
    }

    function deployEthereumSender() private returns (address) {
        vm.selectFork(ethFork);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        DeploySenderBridge deploySender = new DeploySenderBridge();
        address sender = deploySender.deploy(
            ETHEREUM_ENDPOINT,
            vm.envAddress("ETHEREUM_DELEGATE"),
            vm.envAddress("ETHEREUM_OWNER"),
            vm.envAddress("ETHEREUM_OLD_TOKEN"),
            BASE_EID
        );
        vm.stopBroadcast();
        return sender;
    }

    function deployBaseReceiver() private returns (address) {
        vm.selectFork(baseFork);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        DeployReceiverBridge deployReceiver = new DeployReceiverBridge();
        address receiver = deployReceiver.deploy(
            BASE_ENDPOINT,
            vm.envAddress("BASE_DELEGATE"),
            vm.envAddress("BASE_OWNER"),
            vm.envAddress("BASE_VESTING_CONTRACT")
        );
        vm.stopBroadcast();
        return receiver;
    }
}
