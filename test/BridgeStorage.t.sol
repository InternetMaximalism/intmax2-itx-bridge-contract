// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {BridgeStorage} from "../src/BridgeStorage.sol";
import {IBridgeStorage} from "../src/interfaces/IBridgeStorage.sol";

contract BridgeStorageTest is Test {
    BridgeStorage public bridgeStorage;
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public nonOwner = address(0x4);

    function setUp() public {
        bridgeStorage = new BridgeStorage(owner);
    }

    function test_ConstructorSetsOwner() public view {
        assertEq(bridgeStorage.owner(), owner);
    }

    function test_SetBridgedAmountSuccess() public {
        uint256 amount = 1000 * 1e18;

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit IBridgeStorage.BridgedAmountUpdated(user1, amount);

        bridgeStorage.setBridgedAmount(user1, amount);

        assertEq(bridgeStorage.getBridgedAmount(user1), amount);
    }

    function test_SetBridgedAmountMultipleUsers() public {
        uint256 amount1 = 1000 * 1e18;
        uint256 amount2 = 2000 * 1e18;

        vm.prank(owner);
        bridgeStorage.setBridgedAmount(user1, amount1);

        vm.prank(owner);
        bridgeStorage.setBridgedAmount(user2, amount2);

        assertEq(bridgeStorage.getBridgedAmount(user1), amount1);
        assertEq(bridgeStorage.getBridgedAmount(user2), amount2);
    }

    function test_SetBridgedAmountUpdateExisting() public {
        uint256 initialAmount = 1000 * 1e18;
        uint256 updatedAmount = 1500 * 1e18;

        // Set initial amount
        vm.prank(owner);
        bridgeStorage.setBridgedAmount(user1, initialAmount);
        assertEq(bridgeStorage.getBridgedAmount(user1), initialAmount);

        // Update amount
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit IBridgeStorage.BridgedAmountUpdated(user1, updatedAmount);

        bridgeStorage.setBridgedAmount(user1, updatedAmount);
        assertEq(bridgeStorage.getBridgedAmount(user1), updatedAmount);
    }

    function test_SetBridgedAmountRevertNotOwner() public {
        uint256 amount = 1000 * 1e18;

        vm.prank(nonOwner);
        vm.expectRevert();
        bridgeStorage.setBridgedAmount(user1, amount);
    }

    function test_GetBridgedAmountDefaultZero() public view {
        assertEq(bridgeStorage.getBridgedAmount(user1), 0);
        assertEq(bridgeStorage.getBridgedAmount(user2), 0);
    }

    function test_TransferStorageOwnershipSuccess() public {
        address newOwner = address(0x999);

        vm.prank(owner);
        bridgeStorage.transferStorageOwnership(newOwner);

        assertEq(bridgeStorage.owner(), newOwner);

        // Verify new owner can call setBridgedAmount
        uint256 amount = 500 * 1e18;
        vm.prank(newOwner);
        bridgeStorage.setBridgedAmount(user1, amount);

        assertEq(bridgeStorage.getBridgedAmount(user1), amount);
    }

    function test_TransferStorageOwnershipRevertNotOwner() public {
        address newOwner = address(0x999);

        vm.prank(nonOwner);
        vm.expectRevert();
        bridgeStorage.transferStorageOwnership(newOwner);
    }

    function test_TransferStorageOwnershipRevertInvalidAddress() public {
        vm.prank(owner);
        vm.expectRevert(IBridgeStorage.InvalidAddress.selector);
        bridgeStorage.transferStorageOwnership(address(0));
    }

    function test_TransferStorageOwnershipOldOwnerLosesAccess() public {
        address newOwner = address(0x999);
        uint256 amount = 1000 * 1e18;

        // Transfer ownership
        vm.prank(owner);
        bridgeStorage.transferStorageOwnership(newOwner);

        // Old owner should not be able to call setBridgedAmount anymore
        vm.prank(owner);
        vm.expectRevert();
        bridgeStorage.setBridgedAmount(user1, amount);

        // But new owner should be able to
        vm.prank(newOwner);
        bridgeStorage.setBridgedAmount(user1, amount);
        assertEq(bridgeStorage.getBridgedAmount(user1), amount);
    }

    function test_SetBridgedAmountZero() public {
        uint256 initialAmount = 1000 * 1e18;

        // Set initial amount
        vm.prank(owner);
        bridgeStorage.setBridgedAmount(user1, initialAmount);
        assertEq(bridgeStorage.getBridgedAmount(user1), initialAmount);

        // Reset to zero
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit IBridgeStorage.BridgedAmountUpdated(user1, 0);

        bridgeStorage.setBridgedAmount(user1, 0);
        assertEq(bridgeStorage.getBridgedAmount(user1), 0);
    }

    function test_SetBridgedAmountMaxValue() public {
        uint256 maxAmount = type(uint256).max;

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit IBridgeStorage.BridgedAmountUpdated(user1, maxAmount);

        bridgeStorage.setBridgedAmount(user1, maxAmount);
        assertEq(bridgeStorage.getBridgedAmount(user1), maxAmount);
    }
}
