// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {SenderBridgeOApp} from "../src/SenderBridgeOApp.sol";
import {ReceiverBridgeOApp} from "../src/ReceiverBridgeOApp.sol";
import {BridgeStorage} from "../src/BridgeStorage.sol";
import {IReceiverBridgeOApp} from "../src/interfaces/IReceiverBridgeOApp.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MessagingFee} from "@layerzerolabs/oapp/contracts/oapp/OApp.sol";
import {Origin} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {MockEndpointV2} from "./utils/MockEndpoint.t.sol";

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
 */
contract IntegrationTest is Test {
    SenderBridgeOApp public senderBridge;
    ReceiverBridgeOApp public receiverBridge;
    BridgeStorage public bridgeStorage;
    MockINTMAXToken public baseToken;
    MockINTMAXToken public mainnetToken;
    MockEndpointV2 public baseEndpoint;
    MockEndpointV2 public mainnetEndpoint;

    address public owner = address(0x1);
    address public user = address(0x2);
    address public recipient = address(0x3);

    uint32 public constant BASE_EID = 84532;
    uint32 public constant MAINNET_EID = 11155111;

    function setUp() public {
        // Deploy tokens
        baseToken = new MockINTMAXToken();
        mainnetToken = new MockINTMAXToken();

        // Deploy mock endpoints
        baseEndpoint = new MockEndpointV2(BASE_EID);
        mainnetEndpoint = new MockEndpointV2(MAINNET_EID);

        // Deploy BridgeStorage
        bridgeStorage = new BridgeStorage(owner);

        // Deploy bridge contracts
        senderBridge = new SenderBridgeOApp(address(baseEndpoint), owner, owner, address(baseToken), MAINNET_EID);

        receiverBridge = new ReceiverBridgeOApp(address(mainnetEndpoint), owner, owner, address(mainnetToken));

        // Setup BaseBridge with storage
        vm.prank(owner);
        senderBridge.setBridgeStorage(address(bridgeStorage));

        vm.prank(owner);
        bridgeStorage.transferOwnership(address(senderBridge));

        // Setup peer connections
        vm.prank(owner);
        senderBridge.setPeer(MAINNET_EID, bytes32(uint256(uint160(address(receiverBridge)))));

        vm.prank(owner);
        receiverBridge.setPeer(BASE_EID, bytes32(uint256(uint160(address(senderBridge)))));

        // Setup user balances
        baseToken.setBalance(user, 1000 * 1e18);
        mainnetToken.setBalance(address(receiverBridge), 10000 * 1e18);

        vm.deal(user, 10 ether);
    }

    function test_EndToEndBridgeFlow() public {
        // 1. User bridges tokens from Base to Mainnet
        vm.prank(user);
        MessagingFee memory fee = senderBridge.quoteBridge();

        vm.prank(user);
        senderBridge.bridgeTo{value: fee.nativeFee}(recipient);

        assertEq(senderBridge.bridgedAmount(user), 1000 * 1e18);

        // 3. Simulate LayerZero message delivery
        bytes memory payload = abi.encode(recipient, 1000 * 1e18, user);
        Origin memory origin = Origin(BASE_EID, bytes32(uint256(uint160(address(senderBridge)))), 1);

        // 4. Verify mainnet side receives and processes message
        uint256 recipientBalanceBefore = mainnetToken.balanceOf(recipient);

        vm.prank(address(mainnetEndpoint));
        receiverBridge.lzReceive(origin, bytes32(0), payload, address(0), "");

        assertEq(mainnetToken.balanceOf(recipient), recipientBalanceBefore + 1000 * 1e18);
    }

    function test_MultipleBridgeOperations() public {
        vm.prank(user);
        senderBridge.bridgeTo{value: 0.01 ether}(recipient);
        assertEq(senderBridge.bridgedAmount(user), 1000 * 1e18);

        // Increase user balance
        baseToken.setBalance(user, 1500 * 1e18);

        // Second bridge (partial amount)
        vm.prank(user);
        senderBridge.bridgeTo{value: 0.01 ether}(recipient);
        assertEq(senderBridge.bridgedAmount(user), 1500 * 1e18);
    }

    function test_CrossChainErrorRecovery() public {
        // Setup a scenario where message execution fails
        bytes memory payload = abi.encode(address(0), 1000 * 1e18, user); // Invalid recipient
        Origin memory origin = Origin(BASE_EID, bytes32(uint256(uint160(address(senderBridge)))), 1);

        // Simulate stored payload scenario
        vm.expectRevert(IReceiverBridgeOApp.RecipientZero.selector);
        vm.prank(address(mainnetEndpoint));
        receiverBridge.lzReceive(origin, bytes32(0), payload, address(0), "");

        // Test manual retry with corrected payload
        bytes memory correctedPayload = abi.encode(recipient, 1000 * 1e18, user);
        receiverBridge.manualRetry(origin, bytes32(0), correctedPayload, "");

        assertEq(mainnetToken.balanceOf(recipient), 1000 * 1e18);
    }

    function test_OwnershipTransferFlow() public {
        address newOwner = address(0x999);

        // Transfer BaseBridge ownership
        vm.prank(owner);
        senderBridge.transferOwnership(newOwner);

        // Transfer MainnetBridge ownership
        vm.prank(owner);
        receiverBridge.transferOwnership(newOwner);

        // Verify new owner can perform admin functions
        vm.prank(newOwner);
        senderBridge.setGasLimit(300000);

        assertEq(senderBridge.gasLimit(), 300000);
    }
}
