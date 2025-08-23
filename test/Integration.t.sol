// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {BaseBridgeOApp} from "../src/BaseBridgeOApp.sol";
import {MainnetBridgeOApp} from "../src/MainnetBridgeOApp.sol";
import {BridgeStorage} from "../src/BridgeStorage.sol";
import {IBaseBridgeOApp} from "../src/interfaces/IBaseBridgeOApp.sol";
import {IMainnetBridgeOApp} from "../src/interfaces/IMainnetBridgeOApp.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oapp/contracts/oapp/OApp.sol";
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
    BaseBridgeOApp public baseBridge;
    MainnetBridgeOApp public mainnetBridge;
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
        baseBridge = new BaseBridgeOApp(
            address(baseEndpoint),
            owner,
            owner,
            address(baseToken),
            MAINNET_EID
        );

        mainnetBridge = new MainnetBridgeOApp(
            address(mainnetEndpoint),
            owner,
            owner,
            address(mainnetToken)
        );

        // Setup BaseBridge with storage
        vm.prank(owner);
        baseBridge.setBridgeStorage(address(bridgeStorage));
        
        vm.prank(owner);
        bridgeStorage.transferOwnership(address(baseBridge));

        // Setup peer connections
        vm.prank(owner);
        baseBridge.setPeer(MAINNET_EID, bytes32(uint256(uint160(address(mainnetBridge)))));
        
        vm.prank(owner);
        mainnetBridge.setPeer(BASE_EID, bytes32(uint256(uint160(address(baseBridge)))));

        // Setup user balances
        baseToken.setBalance(user, 1000 * 1e18);
        mainnetToken.setBalance(address(mainnetBridge), 10000 * 1e18);
        
        vm.deal(user, 10 ether);
    }

    function test_EndToEndBridgeFlow() public {
        // 1. User bridges tokens from Base to Mainnet
        vm.prank(user);
        MessagingFee memory fee = baseBridge.quoteBridge();
        
        vm.prank(user);
        baseBridge.bridgeTo{value: fee.nativeFee}(recipient);

        // 2. Verify bridge storage updated
        assertEq(baseBridge.bridgedAmount(user), 1000 * 1e18);

        // 3. Simulate LayerZero message delivery
        bytes memory payload = abi.encode(recipient, 1000 * 1e18, user);
        Origin memory origin = Origin({
            srcEid: BASE_EID,
            sender: bytes32(uint256(uint160(address(baseBridge)))),
            nonce: 1
        });

        // 4. Verify mainnet side receives and processes message
        uint256 recipientBalanceBefore = mainnetToken.balanceOf(recipient);
        
        vm.prank(address(mainnetEndpoint));
        mainnetBridge.lzReceive(origin, bytes32(0), payload, address(0), "");
        
        assertEq(mainnetToken.balanceOf(recipient), recipientBalanceBefore + 1000 * 1e18);
    }

    function test_MultipleBridgeOperations() public {
        // First bridge
        vm.prank(user);
        baseBridge.bridgeTo{value: 0.01 ether}(recipient);
        assertEq(baseBridge.bridgedAmount(user), 1000 * 1e18);

        // Increase user balance
        baseToken.setBalance(user, 1500 * 1e18);
        
        // Second bridge (partial amount)
        vm.prank(user);
        baseBridge.bridgeTo{value: 0.01 ether}(recipient);
        assertEq(baseBridge.bridgedAmount(user), 1500 * 1e18);
    }

    function test_CrossChainErrorRecovery() public {
        // Setup a scenario where message execution fails
        bytes memory payload = abi.encode(address(0), 1000 * 1e18, user); // Invalid recipient
        Origin memory origin = Origin({
            srcEid: BASE_EID,
            sender: bytes32(uint256(uint160(address(baseBridge)))),
            nonce: 1
        });

        // Simulate stored payload scenario
        vm.expectRevert(IMainnetBridgeOApp.RecipientZero.selector);
        vm.prank(address(mainnetEndpoint));
        mainnetBridge.lzReceive(origin, bytes32(uint256(1)), payload, address(0), "");

        // Test manual retry with corrected payload
        bytes memory correctedPayload = abi.encode(recipient, 1000 * 1e18, user);
        mainnetBridge.manualRetry(origin, bytes32(uint256(1)), correctedPayload, "");
        
        assertEq(mainnetToken.balanceOf(recipient), 1000 * 1e18);
    }

    function test_OwnershipTransferFlow() public {
        address newOwner = address(0x999);
        
        // Transfer BaseBridge ownership
        vm.prank(owner);
        baseBridge.transferOwnership(newOwner);
        
        // Transfer MainnetBridge ownership  
        vm.prank(owner);
        mainnetBridge.transferOwnership(newOwner);
        
        // Verify new owner can perform admin functions
        vm.prank(newOwner);
        baseBridge.setGasLimit(300000);
        
        assertEq(baseBridge.gasLimit(), 300000);
    }
}