// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import {Script, console} from "forge-std/Script.sol";
import {DeployReceiverBridge, ReceiverBridgeOApp} from "./DeployReceiverBridge.s.sol";
import {DeploySenderBridge, SenderBridgeOApp} from "./DeploySenderBridge.s.sol";
import {ConfigureSenderOApp} from "./ConfigureSenderOApp.s.sol";
import {ConfigureReceiverOApp} from "./ConfigureReceiverOApp.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// forge script script/DeployAllMainnet.s.sol:DeployAllMainnet --broadcast --verify
contract DeployAndAllSetupMainnet is Script {
    using SafeERC20 for IERC20;
    // solhint-disable-next-line state-visibility
    uint32 constant BASE_EID = 30184;
    // solhint-disable-next-line state-visibility
    uint32 constant ETHEREUM_EID = 30101;
    // solhint-disable-next-line state-visibility
    uint32 constant SCROLL_EID = 30214;

    // solhint-disable-next-line state-visibility
    address constant ETHEREUM_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    // solhint-disable-next-line state-visibility
    address constant SCROLL_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    // solhint-disable-next-line state-visibility
    address constant BASE_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;

    // solhint-disable-next-line state-visibility
    address constant ETHEREUM_LAYER_ZERO_DVN = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b;
    // solhint-disable-next-line state-visibility
    address constant SCROLL_LAYER_ZERO_DVN = 0xbe0d08a85EeBFCC6eDA0A843521f7CBB1180D2e2;
    // solhint-disable-next-line state-visibility
    address constant BASE_LAYER_ZERO_DVN = 0x9e059a54699a285714207b43B055483E78FAac25;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer Address:", deployer);

        address scrollSender = deployScrollSender();
        address ethSender = deployEthereumSender();
        address baseReceiver = deployBaseReceiver();
        setSenderPeer("scroll", scrollSender, baseReceiver);
        setSenderPeer("ethereum", ethSender, baseReceiver);
        setReceiverPeer(SCROLL_EID, baseReceiver, scrollSender);
        setReceiverPeer(ETHEREUM_EID, baseReceiver, ethSender);
        setupSenderConfig("scroll", SCROLL_ENDPOINT, scrollSender, BASE_EID, SCROLL_LAYER_ZERO_DVN);
        setupSenderConfig("ethereum", ETHEREUM_ENDPOINT, ethSender, BASE_EID, ETHEREUM_LAYER_ZERO_DVN);
        setupReceiverConfig(BASE_ENDPOINT, baseReceiver, SCROLL_EID, BASE_LAYER_ZERO_DVN);
        setupReceiverConfig(BASE_ENDPOINT, baseReceiver, ETHEREUM_EID, BASE_LAYER_ZERO_DVN);

        prepareBaseToken(baseReceiver);
    }

    function setupReceiverConfig(address endpoint, address receiverAddress, uint32 srcEid, address dvn) private {
        vm.createSelectFork("base");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        ConfigureReceiverOApp configureReceiver = new ConfigureReceiverOApp();
        configureReceiver.setupConfig(endpoint, receiverAddress, srcEid, dvn);
        vm.stopBroadcast();
    }

    function setupSenderConfig(
        string memory chainName,
        address endpoint,
        address senderAddress,
        uint32 dstEid,
        address dvn
    ) private {
        vm.createSelectFork(chainName);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        ConfigureSenderOApp configureSender = new ConfigureSenderOApp();
        configureSender.setupConfig(endpoint, senderAddress, dstEid, dvn);
        vm.stopBroadcast();
    }

    function prepareBaseToken(address receiverAddress) private {
        vm.createSelectFork("base");
        uint256 adminPrivateKey = vm.envUint("BASE_OLD_TOKEN_ADMIN_PRIVATE_KEY");
        vm.startBroadcast(adminPrivateKey);
        IAccessControl accessControl = IAccessControl(vm.envAddress("BASE_OLD_TOKEN"));
        accessControl.grantRole(keccak256("MINTER_ROLE"), receiverAddress);
        vm.stopBroadcast();

        uint256 treasuryPrivateKey = vm.envUint("BASE_OLD_TOKEN_TREASURY_PRIVATE_KEY");
        vm.startBroadcast(treasuryPrivateKey);
        IERC20 token = IERC20(vm.envAddress("BASE_OLD_TOKEN"));
        token.safeTransfer(receiverAddress, vm.envUint("BASE_OLD_TOKEN_TRANSFER_AMOUNT_FROM_TREASURY"));
        vm.stopBroadcast();
    }

    function setReceiverPeer(uint32 senderEid, address receiverAddress, address senderAddress) private {
        vm.createSelectFork("base");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        ReceiverBridgeOApp receiver = ReceiverBridgeOApp(receiverAddress);
        receiver.setPeer(senderEid, bytes32(uint256(uint160(senderAddress))));
        vm.stopBroadcast();
    }

    function setSenderPeer(string memory chainName, address senderAddress, address baseReceiver) private {
        vm.createSelectFork(chainName);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        SenderBridgeOApp sender = SenderBridgeOApp(senderAddress);
        sender.setPeer(BASE_EID, bytes32(uint256(uint160(baseReceiver))));
        vm.stopBroadcast();
    }

    function deployScrollSender() private returns (address) {
        vm.createSelectFork("scroll");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        DeploySenderBridge deploySender = new DeploySenderBridge();
        address sender = deploySender.deploy(
            SCROLL_ENDPOINT,
            vm.envAddress("SCROLL_DELEGATE"),
            vm.envAddress("SCROLL_OWNER"),
            vm.envAddress("SCROLL_OLD_TOKEN"),
            BASE_EID
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
        vm.createSelectFork("base");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        DeployReceiverBridge deployReceiver = new DeployReceiverBridge();
        address receiver = deployReceiver.deploy(
            BASE_ENDPOINT, vm.envAddress("BASE_DELEGATE"), vm.envAddress("BASE_OWNER"), vm.envAddress("BASE_OLD_TOKEN")
        );
        vm.stopBroadcast();
        return receiver;
    }
}
