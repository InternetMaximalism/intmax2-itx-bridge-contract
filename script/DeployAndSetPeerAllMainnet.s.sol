// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import {Script, console} from "forge-std/Script.sol";
import {DeployReceiverBridge, ReceiverBridgeOApp} from "./DeployReceiverBridge.s.sol";
import {DeploySenderBridge, SenderBridgeOApp} from "./DeploySenderBridge.s.sol";

// forge script script/DeployAllMainnet.s.sol:DeployAllMainnet --broadcast --verify
contract DeployAndSetPeerAllMainnet is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer Address:", deployer);

        address scrollSender = deployScrollSender();
        address ethSender = deployEthereumSender();
        address baseReceiver = deployBaseReceiver();
        setSenderPeer("scroll", scrollSender, baseReceiver);
        setSenderPeer("ethereum", ethSender, baseReceiver);
        setReceiverPeer(baseReceiver, scrollSender);
        setReceiverPeer(baseReceiver, ethSender);
    }

    function setReceiverPeer(address receiverAddress, address senderAddress) private {
        vm.createSelectFork("base");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        ReceiverBridgeOApp receiver = ReceiverBridgeOApp(receiverAddress);
        receiver.setPeer(uint32(vm.envUint("BASE_EID")), bytes32(uint256(uint160(senderAddress))));
        vm.stopBroadcast();
    }

    function setSenderPeer(string memory chainName, address senderAddress, address baseReceiver) private {
        vm.createSelectFork(chainName);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        SenderBridgeOApp sender = SenderBridgeOApp(senderAddress);
        sender.setPeer(uint32(vm.envUint("BASE_EID")), bytes32(uint256(uint160(baseReceiver))));
        vm.stopBroadcast();
    }

    function deployScrollSender() private returns (address) {
        vm.createSelectFork("scroll");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        DeploySenderBridge deploySender = new DeploySenderBridge();
        address sender = deploySender.deploy(
            0x1a44076050125825900e736c501f859c50fE728c,
            vm.envAddress("SCROLL_DELEGATE"),
            vm.envAddress("SCROLL_OWNER"),
            vm.envAddress("SCROLL_OLD_TOKEN"),
            uint32(vm.envUint("BASE_EID"))
        );
        vm.stopBroadcast();
        return sender;
    }

    function deployEthereumSender() private returns (address) {
        vm.createSelectFork("ethereum");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        DeploySenderBridge deploySender = new DeploySenderBridge();
        address sender = deploySender.deploy(
            0x1a44076050125825900e736c501f859c50fE728c,
            vm.envAddress("ETHEREUM_DELEGATE"),
            vm.envAddress("ETHEREUM_OWNER"),
            vm.envAddress("ETHEREUM_OLD_TOKEN"),
            uint32(vm.envUint("BASE_EID"))
        );
        vm.stopBroadcast();
        return sender;
    }

    function deployBaseReceiver() private returns (address) {
        vm.createSelectFork("base");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        DeployReceiverBridge deployReceiver = new DeployReceiverBridge();
        address receiver = deployReceiver.deploy(
            0x1a44076050125825900e736c501f859c50fE728c,
            vm.envAddress("BASE_DELEGATE"),
            vm.envAddress("BASE_OWNER"),
            vm.envAddress("BASE_OLD_TOKEN")
        );
        vm.stopBroadcast();
        return receiver;
    }
}
