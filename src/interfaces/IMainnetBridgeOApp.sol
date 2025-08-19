// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IMainnetBridgeOApp {
    error BadSrcEid();
    error BadSender();
    error RecipientZero();

    event BridgeFulfilled(address indexed srcUser, address indexed recipient, uint256 amount);
}
