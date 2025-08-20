// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oapp/contracts/oapp/OApp.sol";

interface IBaseBridgeOApp {
    error RecipientZero();
    error NoDelta();
    error BalanceLessThanBridged();
    error InsufficientNativeFee();

    event BridgeRequested(address indexed recipient, uint256 amount, address indexed user, MessagingReceipt receipt);

    function quoteBridge(address recipient) external view returns (MessagingFee memory fee);

    function bridgeTo(address recipient) external payable;
    function bridgedAmount(address user) external view returns (uint256);
}
