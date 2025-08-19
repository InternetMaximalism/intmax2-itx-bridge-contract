// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {BaseBridgeOApp} from "../src/BaseBridgeOApp.sol";
import {IBaseBridgeOApp} from "../src/interfaces/IBaseBridgeOApp.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
}

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

    function transfer(address, uint256) external pure override returns (bool) {
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

contract BaseBridgeOAppTest is Test {
    BaseBridgeOApp public baseBridge;
    MockINTMAXToken public INTMAX;
    address public owner = address(0x1);
    address public user = address(0x2);
    address public recipient = address(0x3);
    uint32 public constant DST_EID = 30101; // Ethereum Mainnet

    function setUp() public {
        INTMAX = new MockINTMAXToken();
        MockEndpoint endpoint = new MockEndpoint();

        baseBridge = new BaseBridgeOApp(
            address(endpoint), // mock endpoint
            address(INTMAX),
            owner,
            owner,
            DST_EID
        );
        // Set peer so OAppCore._getPeerOrRevert won't revert during tests
        bytes32 peer = bytes32(uint256(uint160(owner)));
        vm.prank(owner);
        baseBridge.setPeer(DST_EID, peer);

        INTMAX.setBalance(user, 1000 * 1e18);
        vm.deal(user, 10 ether);
    }

    function test_BridgeToSuccess() public {
        vm.prank(user);
        baseBridge.bridgeTo{value: 0.01 ether}(recipient);

        assertEq(baseBridge.bridgedAmount(user), 1000 * 1e18);
    }

    function test_BridgeToRevertRecipientZero() public {
        vm.prank(user);
        vm.expectRevert(IBaseBridgeOApp.RecipientZero.selector);
        baseBridge.bridgeTo{value: 0.01 ether}(address(0));
    }

    function test_BridgeToRevertNoDelta() public {
        vm.prank(user);
        baseBridge.bridgeTo{value: 0.01 ether}(recipient);

        vm.prank(user);
        vm.expectRevert(IBaseBridgeOApp.NoDelta.selector);
        baseBridge.bridgeTo{value: 0.01 ether}(recipient);
    }

    function test_BridgeToRevertBalanceLessThanBridged() public {
        vm.prank(user);
        baseBridge.bridgeTo{value: 0.01 ether}(recipient);

        INTMAX.setBalance(user, 500 * 1e18);

        vm.prank(user);
        vm.expectRevert(IBaseBridgeOApp.BalanceLessThanBridged.selector);
        baseBridge.bridgeTo{value: 0.01 ether}(recipient);
    }

    function test_BridgeToPartialAmount() public {
        vm.prank(user);
        baseBridge.bridgeTo{value: 0.01 ether}(recipient);

        INTMAX.setBalance(user, 1500 * 1e18);

        vm.prank(user);
        baseBridge.bridgeTo{value: 0.01 ether}(recipient);

        assertEq(baseBridge.bridgedAmount(user), 1500 * 1e18);
    }
}
