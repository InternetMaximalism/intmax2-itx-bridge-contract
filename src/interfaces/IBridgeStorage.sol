// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IBridgeStorage {
    /// @dev Thrown when an invalid address (zero address) is provided
    error InvalidAddress();

    /**
     * @dev Emitted when a user's bridged amount is updated
     * @param user The user whose bridged amount was updated
     * @param amount The new bridged amount
     */
    event BridgedAmountUpdated(address indexed user, uint256 amount);

    /**
     * @notice Set the bridged amount for a user
     * @param user The user address
     * @param amount The bridged amount to set
     * @dev Only callable by the contract owner
     */
    function setBridgedAmount(address user, uint256 amount) external;

    /**
     * @notice Get the bridged amount for a user
     * @param user The user address to query
     * @return The total amount bridged by the user
     */
    function getBridgedAmount(address user) external view returns (uint256);

    /**
     * @notice Transfer ownership of the storage contract to a new owner
     * @param newOwner The address of the new owner
     * @dev Only callable by the current contract owner
     * @dev Reverts if newOwner is the zero address
     */
    function transferStorageOwnership(address newOwner) external;
}
