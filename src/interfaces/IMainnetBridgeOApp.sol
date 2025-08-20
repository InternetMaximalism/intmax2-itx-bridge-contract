// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Origin} from "@layerzerolabs/oapp/contracts/oapp/OAppReceiver.sol";

interface IMainnetBridgeOApp {
    /// @dev Thrown when the source endpoint ID is invalid
    error BadSrcEid();

    /// @dev Thrown when the sender address is invalid
    error BadSender();

    /// @dev Thrown when recipient address is zero
    error RecipientZero();

    /// @dev Thrown when an invalid address is provided
    error InvalidAddress();

    /// @dev Thrown when an invalid amount is provided
    error InvalidAmount();

    /**
     * @dev Emitted when a bridge request is fulfilled on the destination chain
     * @param srcUser The original user who initiated the bridge on source chain
     * @param recipient The recipient who received the tokens
     * @param amount The amount of tokens transferred
     */
    event BridgeFulfilled(address indexed srcUser, address indexed recipient, uint256 amount);

    /**
     * @dev Emitted when tokens are withdrawn by owner
     * @param to The address that received the withdrawn tokens
     * @param amount The amount of tokens withdrawn
     */
    event TokensWithdrawn(address indexed to, uint256 amount);

    /**
     * @notice Withdraw tokens from the contract (owner only)
     * @param to The address to send tokens to
     * @param amount The amount of tokens to withdraw
     * @dev Only callable by contract owner
     * @dev Validates that 'to' is not zero address and amount is greater than 0
     */
    function withdrawTokens(address to, uint256 amount) external;

    /**
     * @notice Manually retry a failed LayerZero message
     * @param _origin The origin information of the message
     * @param _guid The globally unique identifier of the message
     * @param _message The message payload
     * @param _extraData Additional data for the retry
     * @dev Used when a message fails to execute and needs manual intervention
     */
    function manualRetry(Origin calldata _origin, bytes32 _guid, bytes calldata _message, bytes calldata _extraData)
        external;

    /**
     * @notice Clear a stuck LayerZero message (owner only)
     * @param _origin The origin information of the message
     * @param _guid The globally unique identifier of the message
     * @param _message The message payload to clear
     * @dev Only callable by contract owner
     * @dev Used to clear messages that cannot be retried and need to be skipped
     */
    function clearMessage(Origin calldata _origin, bytes32 _guid, bytes calldata _message) external;

    /**
     * @notice Check if a payload is stored on the LayerZero endpoint
     * @param srcEid The source endpoint ID
     * @param sender The sender address on source chain
     * @param nonce The message nonce
     * @param guid The globally unique identifier of the message
     * @param message The message payload
     * @return True if the payload is stored, false otherwise
     * @dev Used to verify if a message failed execution and is stored for retry
     */
    function hasStoredPayload(uint32 srcEid, bytes32 sender, uint64 nonce, bytes32 guid, bytes calldata message)
        external
        view
        returns (bool);
}
