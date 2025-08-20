// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IMainnetBridgeOApp {
    error BadSrcEid();
    error BadSender();
    error RecipientZero();
    error InvalidAddress();
    error InvalidAmount();

    event BridgeFulfilled(address indexed srcUser, address indexed recipient, uint256 amount);
    event TokensWithdrawn(address indexed to, uint256 amount);
    function withdrawTokens(address to, uint256 amount) external;
}
