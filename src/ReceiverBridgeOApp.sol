// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OAppReceiver, OAppCore, Origin} from "@layerzerolabs/oapp/contracts/oapp/OAppReceiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IReceiverBridgeOApp} from "./interfaces/IReceiverBridgeOApp.sol";

// Not to be UPGRADABLE because there are no internal variables
// and there is a token rescue function in case something goes wrong.
contract ReceiverBridgeOApp is OAppReceiver, IReceiverBridgeOApp {
    using SafeERC20 for IERC20;

    IERC20 private immutable _TOKEN;

    constructor(address _endpoint, address _delegate, address _owner, address _token)
        OAppCore(_endpoint, _delegate)
        Ownable(_owner)
    {
        _TOKEN = IERC20(_token);
    }

    // Implement OAppReceiver internal hook and forward to mockLzReceive for testing.
    function _lzReceive(
        Origin calldata, /*_origin*/
        bytes32, /*_guid*/
        bytes calldata _message,
        address, /*_executor*/
        bytes calldata /*_extraData*/
    )
        internal
        virtual
        override
    {
        // For compatibility, decode the same payload and validate source
        (address recipient, uint256 amount, address srcUser) = abi.decode(_message, (address, uint256, address));

        require(recipient != address(0), RecipientZero());

        _TOKEN.safeTransfer(recipient, amount);
        emit BridgeFulfilled(srcUser, recipient, amount);
    }

    // Not payable because the _lzReceive function does not handle eth
    function manualRetry(Origin calldata _origin, bytes32 _guid, bytes calldata _message, bytes calldata _extraData)
        external
    {
        endpoint.lzReceive(_origin, address(this), _guid, _message, _extraData);
    }

    function clearMessage(Origin calldata _origin, bytes32 _guid, bytes calldata _message) external onlyOwner {
        endpoint.clear(address(this), _origin, _guid, _message);
    }

    function withdrawTokens(address to, uint256 amount) external onlyOwner {
        require(to != address(0), InvalidAddress());
        require(amount > 0, InvalidAmount());
        _TOKEN.safeTransfer(to, amount);
        emit TokensWithdrawn(to, amount);
    }

    function hasStoredPayload(uint32 srcEid, bytes32 sender, uint64 nonce, bytes32 guid, bytes calldata message)
        external
        view
        returns (bool)
    {
        bytes memory payload = abi.encodePacked(guid, message);
        bytes32 payloadHash = keccak256(payload);
        return endpoint.inboundPayloadHash(address(this), srcEid, sender, nonce) == payloadHash;
    }
}
