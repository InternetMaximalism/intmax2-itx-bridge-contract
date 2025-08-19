// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IBaseBridgeOApp {
    error RecipientZero();
    error NoDelta();
    error BalanceLessThanBridged();
    error InsufficientNativeFee();

    event BridgeRequested(address indexed user, address indexed recipient, uint256 amount, uint256 nativeFee);

    function bridgeTo(address recipient) external payable;
}
