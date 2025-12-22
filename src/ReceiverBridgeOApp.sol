// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OAppReceiver, OAppCore, Origin} from "@layerzerolabs/oapp/contracts/oapp/OAppReceiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IReceiverBridgeOApp} from "./interfaces/IReceiverBridgeOApp.sol";

// Not to be UPGRADABLE because there are no internal variables
// and there is a token rescue function in case something goes wrong.
contract ReceiverBridgeOApp is OAppReceiver, IReceiverBridgeOApp {
    using SafeERC20 for IERC20;

    // slither-disable-next-line naming-convention
    IERC20 private immutable TOKEN;

    constructor(address endpoint, address delegate, address owner, address token)
        OAppCore(endpoint, delegate)
        Ownable(owner)
    {
        TOKEN = IERC20(token);
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

        TOKEN.safeTransfer(recipient, amount);
        emit BridgeFulfilled(srcUser, recipient, amount);
    }

    // Not payable because the _lzReceive function does not handle eth
    function manualRetry(Origin calldata origin, bytes32 guid, bytes calldata message, bytes calldata extraData)
        external
    {
        endpoint.lzReceive(origin, address(this), guid, message, extraData);
    }

    function clearMessage(Origin calldata origin, bytes32 guid, bytes calldata message) external onlyOwner {
        endpoint.clear(address(this), origin, guid, message);
    }

    function withdrawTokens(address to, uint256 amount) external onlyOwner {
        require(to != address(0), InvalidAddress());
        require(amount > 0, InvalidAmount());
        TOKEN.safeTransfer(to, amount);
        emit TokensWithdrawn(to, amount);
    }

    function hasStoredPayload(uint32 srcEid, bytes32 sender, uint64 nonce, bytes32 guid, bytes calldata message)
        external
        view
        returns (bool)
    {
        bytes memory payload = abi.encodePacked(guid, message);
        bytes32 payloadHash;
        /* solhint-disable no-inline-assembly */
        // slither-disable-start assembly
        assembly ("memory-safe") {
            payloadHash := keccak256(add(payload, 0x20), mload(payload))
        }
        // slither-disable-end assembly
        /* solhint-enable no-inline-assembly */
        return endpoint.inboundPayloadHash(address(this), srcEid, sender, nonce) == payloadHash;
    }
}
