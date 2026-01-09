// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {ReceiverBridgeOApp} from "../src/ReceiverBridgeOApp.sol";
import {IReceiverBridgeOApp} from "../src/interfaces/IReceiverBridgeOApp.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Origin} from "@layerzerolabs/oapp/contracts/oapp/OAppReceiver.sol";
import {
    MessagingParams,
    MessagingFee,
    MessagingReceipt
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {MockVesting} from "./mocks/MockVesting.sol";

// Enhanced MockEndpoint with more realistic LayerZero functionality
contract MockEndpointV2 {
    uint32 public eid;
    mapping(address => mapping(uint32 => mapping(bytes32 => mapping(uint64 => bytes32)))) public inboundPayloadHash;
    mapping(address => bool) public cleared;
    mapping(address => bool) public delegates;
    mapping(uint32 => address) public defaultSendLibrary;
    mapping(uint32 => address) public defaultReceiveLibrary;

    event PacketSent(uint32 dstEid, address sender, bytes32 receiver, bytes message, MessagingFee fee);

    constructor(uint32 _eid) {
        eid = _eid;
    }

    function setDelegate(address _delegate) external {
        delegates[_delegate] = true;
    }

    function quote(MessagingParams calldata, address) external pure returns (MessagingFee memory) {
        return MessagingFee({nativeFee: 0.01 ether, lzTokenFee: 0});
    }

    function send(
        MessagingParams calldata _params,
        address /* _refundAddress */
    )
        external
        payable
        returns (MessagingReceipt memory)
    {
        MessagingFee memory fee = MessagingFee({nativeFee: msg.value, lzTokenFee: 0});
        emit PacketSent(_params.dstEid, msg.sender, _params.receiver, _params.message, fee);
        return MessagingReceipt({guid: keccak256(abi.encode(_params, block.timestamp)), nonce: 1, fee: fee});
    }

    function lzReceive(
        Origin calldata _origin,
        address _receiver,
        bytes32 _guid,
        bytes calldata _message,
        bytes calldata _extraData
    ) external {
        // Call the OApp's lzReceive function
        ReceiverBridgeOApp(_receiver).lzReceive(_origin, _guid, _message, address(this), _extraData);
    }

    function lzReceive(
        address payable _oapp,
        uint32 _srcEid,
        bytes32 _sender,
        uint64 _nonce,
        bytes32 _guid,
        bytes calldata _message,
        bytes calldata _extraData
    ) external {
        // Call the OApp's lzReceive function
        ReceiverBridgeOApp(_oapp)
            .lzReceive(
                Origin({srcEid: _srcEid, sender: _sender, nonce: _nonce}), _guid, _message, address(this), _extraData
            );
    }

    function clear(
        address _oapp,
        Origin calldata,
        /* _origin */
        bytes32,
        /* _guid */
        bytes calldata /* _message */
    )
        external
    {
        cleared[_oapp] = true;
    }

    function setInboundPayloadHash(address _receiver, uint32 _srcEid, bytes32 _sender, uint64 _nonce, bytes32 _hash)
        external
    {
        inboundPayloadHash[_receiver][_srcEid][_sender][_nonce] = _hash;
    }
}

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

contract ReceiverBridgeOAppTest is Test {
    ReceiverBridgeOApp public receiverBridge;
    MockVesting public vesting;
    MockEndpointV2 public mockEndpoint;
    address public owner = address(0x1);
    address public srcUser = address(0x2);
    address public recipient = address(0x3);
    uint32 public constant SRC_EID = 30184; // Base
    bytes32 public srcSender;

    function setUp() public {
        vesting = new MockVesting();
        srcSender = bytes32(uint256(uint160(address(0x4)))); // Mock Base OApp address
        mockEndpoint = new MockEndpointV2(2); // Mainnet EID

        receiverBridge = new ReceiverBridgeOApp(
            address(mockEndpoint), // endpoint
            owner, // delegate
            owner, // owner
            address(vesting) // vesting contract
        );

        // Set peer so OAppCore._getPeerOrRevert won't revert during tests
        vm.prank(owner);
        receiverBridge.setPeer(SRC_EID, srcSender);

        // Set peer for test error EID 999 to allow our custom error testing
        vm.prank(owner);
        receiverBridge.setPeer(999, srcSender);

        // No need to set balance for receiverBridge as it now uses vesting allowance
    }

    function test_LzReceiveSuccess() public {
        uint256 amount = 100 * 1e18;
        bytes memory payload = abi.encode(recipient, amount, srcUser);

        uint256 recipientAllowanceBefore = vesting.getAllowance(recipient);

        mockEndpoint.lzReceive(payable(address(receiverBridge)), SRC_EID, srcSender, 1, bytes32(0), payload, bytes(""));

        uint256 recipientAllowanceAfter = vesting.getAllowance(recipient);
        assertEq(recipientAllowanceAfter - recipientAllowanceBefore, amount);
    }

    function test_LzReceiveRevertRecipientZero() public {
        uint256 amount = 100 * 1e18;
        bytes memory payload = abi.encode(address(0), amount, srcUser); // Zero recipient

        vm.expectRevert(IReceiverBridgeOApp.RecipientZero.selector);
        mockEndpoint.lzReceive(payable(address(receiverBridge)), SRC_EID, srcSender, 1, bytes32(0), payload, bytes(""));
    }

    function test_ManualRetry() public {
        uint256 amount = 100 * 1e18;
        bytes memory message = abi.encode(recipient, amount, srcUser);
        Origin memory origin = Origin({srcEid: SRC_EID, sender: srcSender, nonce: 1});
        bytes32 guid = bytes32(uint256(1));
        bytes memory extraData = bytes("");

        uint256 recipientAllowanceBefore = vesting.getAllowance(recipient);

        receiverBridge.manualRetry(origin, guid, message, extraData);

        uint256 recipientAllowanceAfter = vesting.getAllowance(recipient);
        assertEq(recipientAllowanceAfter - recipientAllowanceBefore, amount);
    }

    function test_ClearMessage() public {
        Origin memory origin = Origin({srcEid: SRC_EID, sender: srcSender, nonce: 1});
        bytes32 guid = bytes32(uint256(1));
        bytes memory message = abi.encode(recipient, 100 * 1e18, srcUser);

        vm.prank(owner);
        receiverBridge.clearMessage(origin, guid, message);

        assertTrue(mockEndpoint.cleared(address(receiverBridge)));
    }

    function test_HasStoredPayload() public {
        uint256 amount = 100 * 1e18;
        bytes memory message = abi.encode(recipient, amount, srcUser);
        bytes32 guid = bytes32(uint256(1));

        bytes memory payload = abi.encodePacked(guid, message);
        bytes32 payloadHash = keccak256(payload);

        // Set the stored payload hash in mock endpoint
        mockEndpoint.setInboundPayloadHash(address(receiverBridge), SRC_EID, srcSender, 1, payloadHash);

        bool hasPayload = receiverBridge.hasStoredPayload(SRC_EID, srcSender, 1, guid, message);
        assertTrue(hasPayload);
    }

    function test_HasStoredPayloadFalse() public view {
        uint256 amount = 100 * 1e18;
        bytes memory message = abi.encode(recipient, amount, srcUser);
        bytes32 guid = bytes32(uint256(1));

        bool hasPayload = receiverBridge.hasStoredPayload(SRC_EID, srcSender, 1, guid, message);
        assertFalse(hasPayload);
    }

    // withdrawTokens tests removed as ReceiverBridgeOApp no longer holds tokens.
    // The vesting contract manages all token operations.
}
