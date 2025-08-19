// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {MainnetBridgeOApp} from "../src/MainnetBridgeOApp.sol";
import {IMainnetBridgeOApp} from "../src/interfaces/IMainnetBridgeOApp.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Origin} from "@layerzerolabs/oapp/contracts/oapp/OAppReceiver.sol";
import {
    MessagingParams,
    MessagingFee,
    MessagingReceipt
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract MockEndpoint {
    function setDelegate(address) external {}

    function quote(MessagingParams calldata, address) external pure returns (MessagingFee memory) {
        return MessagingFee({nativeFee: 0.01 ether, lzTokenFee: 0});
    }

    function send(MessagingParams calldata, /*_params*/ address /*_refundAddress*/ )
        external
        payable
        returns (MessagingReceipt memory)
    {
        MessagingFee memory fee = MessagingFee({nativeFee: msg.value, lzTokenFee: 0});
        return MessagingReceipt({guid: bytes32(0), nonce: 1, fee: fee});
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
        MainnetBridgeOApp(_oapp).lzReceive(
            Origin({srcEid: _srcEid, sender: _sender, nonce: _nonce}),
            _guid,
            _message,
            address(this),
            _extraData
        );
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

contract MainnetBridgeOAppTest is Test {
    MainnetBridgeOApp public mainnetBridge;
    MockINTMAXToken public INTMAX;
    MockEndpoint public mockEndpoint;
    address public owner = address(0x1);
    address public srcUser = address(0x2);
    address public recipient = address(0x3);
    uint32 public constant SRC_EID = 30184; // Base
    bytes32 public srcSender;

    function setUp() public {
        INTMAX = new MockINTMAXToken();
        srcSender = bytes32(uint256(uint160(address(0x4)))); // Mock Base OApp address
        mockEndpoint = new MockEndpoint();

        mainnetBridge = new MainnetBridgeOApp(address(mockEndpoint), address(INTMAX), owner, SRC_EID, srcSender);

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

    function test_LzReceiveRevertBadSrcEid() public {
        uint256 amount = 100 * 1e18;
        bytes memory payload = abi.encode(recipient, amount, srcUser);

        vm.expectRevert(IMainnetBridgeOApp.BadSrcEid.selector);
        mockEndpoint.lzReceive(payable(address(mainnetBridge)), 999, srcSender, 1, bytes32(0), payload, bytes("")); // Wrong source EID
    }

    function test_LzReceiveRevertBadSender() public {
        uint256 amount = 100 * 1e18;
        bytes memory payload = abi.encode(recipient, amount, srcUser);

        bytes32 wrongSender = bytes32(uint256(uint160(address(0x999))));

        vm.expectRevert(); // OnlyPeer error from LayerZero OApp
        mockEndpoint.lzReceive(payable(address(mainnetBridge)), SRC_EID, wrongSender, 1, bytes32(0), payload, bytes("")); // Wrong sender
    }

    function test_LzReceiveRevertRecipientZero() public {
        uint256 amount = 100 * 1e18;
        bytes memory payload = abi.encode(address(0), amount, srcUser); // Zero recipient

        vm.expectRevert(IMainnetBridgeOApp.RecipientZero.selector);
        mockEndpoint.lzReceive(payable(address(mainnetBridge)), SRC_EID, srcSender, 1, bytes32(0), payload, bytes(""));
    }
}
