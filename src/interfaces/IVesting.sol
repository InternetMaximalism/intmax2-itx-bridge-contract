// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IVesting
 * @notice Temporary interface for the Vesting contract.
 * @dev This is a temporary interface created for development purposes.
 *      Once https://github.com/InternetMaximalism/intmax2-itx-vesting-contract is released,
 *      this file should be removed and replaced with:
 *      forge install InternetMaximalism/intmax2-itx-vesting-contract
 *      and import the official IVesting interface instead.
 */
interface IVesting {
    /// @notice Add vesting allowance from bridge.
    /// @param user The user receiving the allowance.
    /// @param amount The amount to add.
    function addBridgeAllowance(address user, uint256 amount) external;
}
