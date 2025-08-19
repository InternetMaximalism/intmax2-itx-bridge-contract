// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OApp, Origin} from "@layerzerolabs/oapp/contracts/oapp/OApp.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IMainnetBridgeOApp} from "./interfaces/IMainnetBridgeOApp.sol";

contract MainnetBridgeOApp is OApp, IMainnetBridgeOApp {
    using SafeERC20 for IERC20;

    IERC20 private immutable _TOKEN;
    uint32 private immutable _SRC_EID;
    bytes32 private immutable _SRC_SENDER;

    constructor(address _endpoint, address _token, address _delegate, uint32 _srcEid, bytes32 _srcSender)
        OApp(_endpoint, _delegate)
        Ownable(_delegate)
    {
        _TOKEN = IERC20(_token);
        _SRC_EID = _srcEid;
        _SRC_SENDER = _srcSender;
    }

    // Implement OAppReceiver internal hook and forward to mockLzReceive for testing.
    function _lzReceive(
        Origin calldata _origin,
        bytes32, /*_guid*/
        bytes calldata _message,
        address, /*_executor*/
        bytes calldata /*_extraData*/
    ) internal virtual override {
        if (_origin.srcEid != _SRC_EID) revert BadSrcEid();
        // For compatibility, decode the same payload and validate source
        (address recipient, uint256 amount, address srcUser) = abi.decode(_message, (address, uint256, address));

        if (_origin.sender != _SRC_SENDER) revert BadSender();
        if (recipient == address(0)) revert RecipientZero();

        _TOKEN.safeTransfer(recipient, amount);
        emit BridgeFulfilled(srcUser, recipient, amount);
    }

    receive() external payable {}
}
