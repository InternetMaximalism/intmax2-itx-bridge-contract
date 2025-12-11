// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oapp/contracts/oapp/OApp.sol";

interface ISenderBridgeOApp {
    /// @dev Thrown when recipient address is zero
    error RecipientZero();

    /// @dev Thrown when there's no delta between current and previous balance
    error NoDelta();

    /// @dev Thrown when current balance is less than previously bridged amount
    error BalanceLessThanBridged();

    /// @dev Thrown when insufficient native fee is provided for bridging
    error InsufficientNativeFee();

    /**
     * @dev Emitted when the gas limit for LayerZero execution is updated
     * @param oldLimit The previous gas limit value
     * @param newLimit The new gas limit value
     */
    event GasLimitUpdated(uint128 oldLimit, uint128 newLimit);

    /**
     * @dev Emitted when a bridge request is initiated
     * @param recipient The recipient address on destination chain
     * @param amount The amount of tokens being bridged
     * @param user The user initiating the bridge
     * @param receipt The LayerZero messaging receipt containing guid and nonce
     */
    event BridgeRequested(address indexed recipient, uint256 amount, address indexed user, MessagingReceipt receipt);

    /**
     * @dev Emitted when the bridged amount for a user is updated
     * @param user The user address
     * @param amount The new total bridged amount
     */
    event BridgedAmountUpdated(address indexed user, uint256 amount);

    /**
     * @notice Set the gas limit for LayerZero message execution on the destination chain
     * @param _gasLimit The new gas limit value (must be greater than 0)
     * @dev Only callable by contract owner
     * @dev Emits GasLimitUpdated event
     */
    function setGasLimit(uint128 _gasLimit) external;
    /**
     * @notice Get the estimated fee for bridging
     * @return fee The estimated messaging fee required for the bridge transaction
     */
    function quoteBridge() external view returns (MessagingFee memory fee);

    /**
     * @notice Bridge tokens to a recipient on the destination chain
     * @param recipient The recipient address on destination chain
     * @dev Requires sufficient native fee to be sent with the transaction
     * @dev Only bridges the delta between current balance and previously bridged amount
     */
    function bridgeTo(address recipient) external payable;

    /**
     * @notice Get the total amount of tokens bridged by a user
     * @param user The user address to query
     * @return The total amount of tokens bridged by the user
     */
    function bridgedAmount(address user) external view returns (uint256);
}
