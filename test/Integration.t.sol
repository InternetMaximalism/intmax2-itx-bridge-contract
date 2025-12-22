// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {SenderBridgeOApp} from "../src/SenderBridgeOApp.sol";
import {ReceiverBridgeOApp} from "../src/ReceiverBridgeOApp.sol";
import {IReceiverBridgeOApp} from "../src/interfaces/IReceiverBridgeOApp.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MessagingFee} from "@layerzerolabs/oapp/contracts/oapp/OApp.sol";
import {Origin} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {MockEndpointV2} from "./utils/MockEndpoint.t.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockINTMAXToken is IERC20 {
    mapping(address => uint256) private _balances;

    function setBalance(address account, uint256 amount) external {
        _balances[account] = amount;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function totalSupply() external pure override returns (uint256) {
        return 1000000 * 1e18;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        return true;
    }

    function allowance(address, address) external pure override returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure override returns (bool) {
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        _balances[from] -= amount;
        _balances[to] += amount;
        return true;
    }
}

/**
 * @title Integration Tests
 * @notice End-to-end integration tests for the complete bridge system
 * @dev Scenario: User bridges from Ethereum/Scroll (Source) to Base (Dest)
 */
contract IntegrationTest is Test {
    SenderBridgeOApp public senderBridge;
    ReceiverBridgeOApp public receiverBridge;
    MockINTMAXToken public sourceToken; // e.g., Ethereum
    MockINTMAXToken public destToken; // e.g., Base
    MockEndpointV2 public sourceEndpoint;
    MockEndpointV2 public destEndpoint;

    address public owner = address(0x1);
    address public user = address(0x2);
    address public recipient = address(0x3);

    uint32 public constant SOURCE_EID = 101; // Ethereum EID
    uint32 public constant DEST_EID = 102; // Base EID

    function setUp() public {
        sourceToken = new MockINTMAXToken();
        destToken = new MockINTMAXToken();
        sourceEndpoint = new MockEndpointV2(SOURCE_EID);
        destEndpoint = new MockEndpointV2(DEST_EID);

        _deploySenderBridge();
        _deployReceiverBridge();
        _setupPeers();

        // User starts with tokens on Source chain
        sourceToken.setBalance(user, 1000 * 1e18);

        // Receiver bridge holds tokens on Dest chain
        destToken.setBalance(address(receiverBridge), 10000 * 1e18);

        vm.deal(user, 10 ether);
    }

    function _deploySenderBridge() internal {
        // Deploy Sender on Source Chain, pointing to Dest Chain EID
        SenderBridgeOApp senderImpl = new SenderBridgeOApp(address(sourceEndpoint), address(sourceToken), DEST_EID);
        ERC1967Proxy senderProxy = new ERC1967Proxy(address(senderImpl), "");
        senderBridge = SenderBridgeOApp(address(senderProxy));

        vm.prank(address(senderProxy));
        senderBridge.initialize(owner, owner);
    }

    function _deployReceiverBridge() internal {
        // Deploy Receiver on Dest Chain
        receiverBridge = new ReceiverBridgeOApp(address(destEndpoint), owner, owner, address(destToken));
    }

    function _setupPeers() internal {
        bytes32 receiverPeer = bytes32(uint256(uint160(address(receiverBridge))));
        bytes32 senderPeer = bytes32(uint256(uint160(address(senderBridge))));

        // Sender (Source) -> Receiver (Dest)
        vm.prank(senderBridge.owner());
        senderBridge.setPeer(DEST_EID, receiverPeer);

        // Receiver (Dest) -> Sender (Source)
        vm.prank(owner);
        receiverBridge.setPeer(SOURCE_EID, senderPeer);
    }

    function test_EndToEndBridgeFlow() public {
        // 1. User bridges tokens from Source to Dest
        vm.prank(user);
        MessagingFee memory fee = senderBridge.quoteBridge();

        vm.prank(user);
        senderBridge.bridgeTo{value: fee.nativeFee}(recipient);

        assertEq(senderBridge.bridgedAmount(user), 1000 * 1e18);

        // 2. Simulate LayerZero message delivery
        bytes memory payload = abi.encode(recipient, 1000 * 1e18, user);
        Origin memory origin =
            Origin({srcEid: SOURCE_EID, sender: bytes32(uint256(uint160(address(senderBridge)))), nonce: 1});

        // 3. Verify Dest side receives and processes message
        uint256 recipientBalanceBefore = destToken.balanceOf(recipient);

        vm.prank(address(destEndpoint));
        receiverBridge.lzReceive(origin, bytes32(0), payload, address(0), "");

        assertEq(destToken.balanceOf(recipient), recipientBalanceBefore + 1000 * 1e18);
    }

    function test_MultipleBridgeOperations() public {
        vm.prank(user);
        senderBridge.bridgeTo{value: 0.01 ether}(recipient);
        assertEq(senderBridge.bridgedAmount(user), 1000 * 1e18);

        // Increase user balance on Source
        sourceToken.setBalance(user, 1500 * 1e18);

        // Second bridge (partial amount)
        vm.prank(user);
        senderBridge.bridgeTo{value: 0.01 ether}(recipient);
        assertEq(senderBridge.bridgedAmount(user), 1500 * 1e18);
    }

    function test_CrossChainErrorRecovery() public {
        // Setup a scenario where message execution fails
        bytes memory payload = abi.encode(address(0), 1000 * 1e18, user); // Invalid recipient
        Origin memory origin =
            Origin({srcEid: SOURCE_EID, sender: bytes32(uint256(uint160(address(senderBridge)))), nonce: 1});

        // Simulate stored payload scenario on Dest
        vm.expectRevert(IReceiverBridgeOApp.RecipientZero.selector);
        vm.prank(address(destEndpoint));
        receiverBridge.lzReceive(origin, bytes32(0), payload, address(0), "");

        // Test manual retry with corrected payload
        bytes memory correctedPayload = abi.encode(recipient, 1000 * 1e18, user);
        receiverBridge.manualRetry(origin, bytes32(0), correctedPayload, "");

        assertEq(destToken.balanceOf(recipient), 1000 * 1e18);
    }

    function test_OwnershipTransferFlow() public {
        address newOwner = address(0x999);

        // Transfer Sender ownership
        vm.prank(owner);
        senderBridge.transferOwnership(newOwner);

        // Transfer Receiver ownership
        vm.prank(owner);
        receiverBridge.transferOwnership(newOwner);

        // Verify new owner can perform admin functions
        vm.prank(newOwner);
        senderBridge.setGasLimit(300000);

        assertEq(senderBridge.gasLimit(), 300000);
    }
}
