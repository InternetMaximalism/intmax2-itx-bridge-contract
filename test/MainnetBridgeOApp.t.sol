// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {MainnetBridgeOApp} from "../src/MainnetBridgeOApp.sol";
import {IMainnetBridgeOApp} from "../src/interfaces/IMainnetBridgeOApp.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Origin} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {MockEndpointV2} from "./utils/MockEndpoint.t.sol";

contract MockINTMAXToken is IERC20 {
    mapping(address => uint256) private _balances;
    address public pool;

    constructor() {
        pool = address(this);
        _balances[pool] = 1000000 * 1e18;
    }

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

    function transferFrom(address, address, uint256) external pure override returns (bool) {
        return true;
    }
}

// Token mock that reverts on transfer to simulate token failure
contract RevertingToken is IERC20 {
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

    function transfer(address, uint256) external pure override returns (bool) {
        revert("transfer failed");
    }

    function allowance(address, address) external pure override returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure override returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure override returns (bool) {
        return true;
    }
}

contract MainnetBridgeOAppTest is Test {
    MainnetBridgeOApp public mainnetBridge;
    MockINTMAXToken public INTMAX;
    MockEndpointV2 public mockEndpoint;
    address public owner = address(0x1);
    address public srcUser = address(0x2);
    address public recipient = address(0x3);
    uint32 public constant SRC_EID = 30184; // Base
    bytes32 public srcSender;

    function setUp() public {
        INTMAX = new MockINTMAXToken();
        srcSender = bytes32(uint256(uint160(address(0x4)))); // Mock Base OApp address
        mockEndpoint = new MockEndpointV2(2); // Mainnet EID

        mainnetBridge = new MainnetBridgeOApp(
            address(mockEndpoint), // endpoint
            owner, // delegate
            owner, // owner
            address(INTMAX) // token
        );

        // Set peer so OAppCore._getPeerOrRevert won't revert during tests
        vm.prank(owner);
        mainnetBridge.setPeer(SRC_EID, srcSender);

        // Set peer for test error EID 999 to allow our custom error testing
        vm.prank(owner);
        mainnetBridge.setPeer(999, srcSender);

        // Set balance for mainnet bridge for distribution
        INTMAX.setBalance(address(mainnetBridge), 10000 * 1e18);
    }

    function test_LzReceiveSuccess() public {
        uint256 amount = 100 * 1e18;
        bytes memory payload = abi.encode(recipient, amount, srcUser);

        uint256 recipientBalanceBefore = INTMAX.balanceOf(recipient);

        mockEndpoint.lzReceive(payable(address(mainnetBridge)), SRC_EID, srcSender, 1, bytes32(0), payload, bytes(""));

        uint256 recipientBalanceAfter = INTMAX.balanceOf(recipient);
        assertEq(recipientBalanceAfter - recipientBalanceBefore, amount);
    }

    function test_LzReceiveRevertRecipientZero() public {
        uint256 amount = 100 * 1e18;
        bytes memory payload = abi.encode(address(0), amount, srcUser); // Zero recipient

        vm.expectRevert(IMainnetBridgeOApp.RecipientZero.selector);
        mockEndpoint.lzReceive(payable(address(mainnetBridge)), SRC_EID, srcSender, 1, bytes32(0), payload, bytes(""));
    }

    function test_ManualRetry() public {
        uint256 amount = 100 * 1e18;
        bytes memory message = abi.encode(recipient, amount, srcUser);
        Origin memory origin = Origin({srcEid: SRC_EID, sender: srcSender, nonce: 1});
        bytes32 guid = bytes32(uint256(1));
        bytes memory extraData = bytes("");

        uint256 recipientBalanceBefore = INTMAX.balanceOf(recipient);

        mainnetBridge.manualRetry(origin, guid, message, extraData);

        uint256 recipientBalanceAfter = INTMAX.balanceOf(recipient);
        assertEq(recipientBalanceAfter - recipientBalanceBefore, amount);
    }

    function test_ClearMessage() public {
        Origin memory origin = Origin({srcEid: SRC_EID, sender: srcSender, nonce: 1});
        bytes32 guid = bytes32(uint256(1));
        bytes memory message = abi.encode(recipient, 100 * 1e18, srcUser);

        vm.prank(owner);
        mainnetBridge.clearMessage(origin, guid, message);

        assertTrue(mockEndpoint.cleared(address(mainnetBridge)));
    }

    function test_HasStoredPayload() public {
        uint256 amount = 100 * 1e18;
        bytes memory message = abi.encode(recipient, amount, srcUser);
        bytes32 guid = bytes32(uint256(1));

        bytes memory payload = abi.encodePacked(guid, message);
        bytes32 payloadHash = keccak256(payload);

        // Set the stored payload hash in mock endpoint
        mockEndpoint.setInboundPayloadHash(address(mainnetBridge), SRC_EID, srcSender, 1, payloadHash);

        bool hasPayload = mainnetBridge.hasStoredPayload(SRC_EID, srcSender, 1, guid, message);
        assertTrue(hasPayload);
    }

    function test_HasStoredPayloadFalse() public view {
        uint256 amount = 100 * 1e18;
        bytes memory message = abi.encode(recipient, amount, srcUser);
        bytes32 guid = bytes32(uint256(1));

        bool hasPayload = mainnetBridge.hasStoredPayload(SRC_EID, srcSender, 1, guid, message);
        assertFalse(hasPayload);
    }

    function test_WithdrawTokensSuccess() public {
        uint256 amount = 1000 * 1e18;
        address to = address(0x5);

        uint256 toBalanceBefore = INTMAX.balanceOf(to);
        uint256 contractBalanceBefore = INTMAX.balanceOf(address(mainnetBridge));

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit IMainnetBridgeOApp.TokensWithdrawn(to, amount);
        mainnetBridge.withdrawTokens(to, amount);

        uint256 toBalanceAfter = INTMAX.balanceOf(to);
        uint256 contractBalanceAfter = INTMAX.balanceOf(address(mainnetBridge));

        assertEq(toBalanceAfter - toBalanceBefore, amount);
        assertEq(contractBalanceBefore - contractBalanceAfter, amount);
    }

    function test_WithdrawTokensRevertInvalidAddress() public {
        uint256 amount = 1000 * 1e18;

        vm.prank(owner);
        vm.expectRevert(IMainnetBridgeOApp.InvalidAddress.selector);
        mainnetBridge.withdrawTokens(address(0), amount);
    }

    function test_WithdrawTokensRevertInvalidAmount() public {
        address to = address(0x5);

        vm.prank(owner);
        vm.expectRevert(IMainnetBridgeOApp.InvalidAmount.selector);
        mainnetBridge.withdrawTokens(to, 0);
    }

    function test_LzReceiveTokenTransferRevert() public {
        // Deploy a new bridge with reverting token
        RevertingToken rtoken = new RevertingToken();
        MockEndpointV2 endpoint2 = new MockEndpointV2(2);
        MainnetBridgeOApp bridge = new MainnetBridgeOApp(address(endpoint2), owner, owner, address(rtoken));

        // Set peer and payload
        bytes32 sender = bytes32(uint256(uint160(address(0x4))));
        vm.prank(owner);
        bridge.setPeer(SRC_EID, sender);

        bytes memory payload = abi.encode(recipient, 100 * 1e18, srcUser);

        // lzReceive should revert because token.transfer reverts
        vm.expectRevert();
        endpoint2.lzReceive(payable(address(bridge)), SRC_EID, sender, 1, bytes32(0), payload, bytes(""));
    }
}
