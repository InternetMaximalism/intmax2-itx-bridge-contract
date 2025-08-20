// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OAppReceiver, OAppCore, Origin} from "@layerzerolabs/oapp/contracts/oapp/OAppReceiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IMainnetBridgeOApp} from "./interfaces/IMainnetBridgeOApp.sol";

// Not to be UPGRADABLE because there are no internal variables 
// and there is a token rescue function in case something goes wrong.
contract MainnetBridgeOApp is OAppReceiver, IMainnetBridgeOApp {
    using SafeERC20 for IERC20;

    IERC20 private immutable _TOKEN;
    uint32 private immutable _SRC_EID;
    bytes32 private immutable _SRC_SENDER;

    constructor(
        address _endpoint,
        address _delegate,
        address _owner,
        address _token,
        uint32 _srcEid,
        bytes32 _srcSender
    ) OAppCore(_endpoint, _delegate) Ownable(_owner) {
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
        require(_origin.srcEid == _SRC_EID, BadSrcEid());
        // For compatibility, decode the same payload and validate source
        (address recipient, uint256 amount, address srcUser) = abi.decode(_message, (address, uint256, address));

        require(_origin.sender == _SRC_SENDER, BadSender());
        require(recipient != address(0), RecipientZero());

        _TOKEN.safeTransfer(recipient, amount);
        emit BridgeFulfilled(srcUser, recipient, amount);
    }

    function withdrawTokens(address to, uint256 amount) external onlyOwner {
        _TOKEN.safeTransfer(to, amount);
    }
}
