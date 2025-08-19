// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OApp, MessagingFee} from "@layerzerolabs/oapp/contracts/oapp/OApp.sol";
import {Origin} from "@layerzerolabs/oapp/contracts/oapp/OAppReceiver.sol";
import {IBaseBridgeOApp} from "./interfaces/IBaseBridgeOApp.sol";

contract BaseBridgeOApp is OApp, IBaseBridgeOApp {
    using SafeERC20 for IERC20;

    IERC20 private immutable _TOKEN;
    uint32 private immutable _DST_EID;

    mapping(address => uint256) private _bridgedAmount;

    constructor(address _endpoint, address _token, address _delegate, uint32 _dstEid)
        OApp(_endpoint, _delegate)
        Ownable(_delegate)
    {
        _TOKEN = IERC20(_token);
        _DST_EID = _dstEid;
    }

    function bridgedAmount(address user) external view returns (uint256) {
        return _bridgedAmount[user];
    }

    function bridgeTo(address recipient) external payable {
        if (recipient == address(0)) revert RecipientZero();

        uint256 current = _TOKEN.balanceOf(msg.sender);
        uint256 prev = _bridgedAmount[msg.sender];

        if (current < prev) revert BalanceLessThanBridged();

        uint256 delta = current - prev;
        if (delta == 0) revert NoDelta();
        bytes memory payload = abi.encode(recipient, delta, msg.sender);
        bytes memory options = bytes("");
        MessagingFee memory fee = _quote(_DST_EID, payload, options, false);
        if (msg.value < fee.nativeFee) revert InsufficientNativeFee();
        _lzSend(_DST_EID, payload, options, fee, payable(msg.sender));
        _bridgedAmount[msg.sender] = current;

        emit BridgeRequested(msg.sender, recipient, delta, fee.nativeFee);
    }

    // Implement the internal receiver hook required by OAppReceiver.
    function _lzReceive(
        Origin calldata, /*_origin*/
        bytes32, /*_guid*/
        bytes calldata, /*_message*/
        address, /*_executor*/
        bytes calldata /*_extraData*/
    ) internal virtual override {
        // This BaseBridgeOApp is primarily a sender mock; no receive logic is needed here.
    }

    receive() external payable {}
}
