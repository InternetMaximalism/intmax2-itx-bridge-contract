// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IVesting} from "../../src/interfaces/IVesting.sol";

contract MockVesting is IVesting {
    mapping(address => uint256) public allowances;

    function addBridgeAllowance(address user, uint256 amount) external override {
        allowances[user] += amount;
    }

    function getAllowance(address user) external view returns (uint256) {
        return allowances[user];
    }
}
