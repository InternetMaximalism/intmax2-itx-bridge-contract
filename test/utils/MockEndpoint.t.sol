// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oapp/contracts/oapp/OApp.sol";
import {Origin} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract MockEndpointV2 {
    uint32 public eid;
    mapping(address => bool) public delegates;
    mapping(uint32 => address) public defaultSendLibrary;
    mapping(uint32 => address) public defaultReceiveLibrary;
    mapping(uint32 => mapping(address => bytes32)) public peers;

    // For Mainnet test variant
    mapping(address => mapping(uint32 => mapping(bytes32 => mapping(uint64 => bytes32)))) public inboundPayloadHash;
    mapping(address => bool) public cleared;

    // Last packet capture for tests
    uint32 public lastDstEid;
    address public lastSender;
    bytes32 public lastReceiver;
    bytes public lastMessage;
    uint256 public lastFeeNative;

    event PacketSent(uint32 dstEid, address sender, bytes32 receiver, bytes message, MessagingFee fee);

    constructor(uint32 _eid) {
        eid = _eid;
    }

    function setDelegate(address _delegate) external {
        delegates[_delegate] = true;
    }

    // Compatibility shims: accept raw params as bytes when MessagingParams type isn't available
    // Typed struct matching OApp MessagingParams ABI
    // solhint-disable-next-line gas-struct-packing
    struct MessagingParams {
        uint32 dstEid;
        bytes32 receiver;
        bytes message;
        bytes options;
        bool payInLzToken;
    }

    // Preferred ABI-compatible functions used by OApp
    function quote(MessagingParams calldata, address) external pure returns (MessagingFee memory) {
        return MessagingFee({nativeFee: 0.01 ether, lzTokenFee: 0});
    }

    function send(
        MessagingParams calldata _params,
        address /* _refundAddress */
    )
        external
        payable
        returns (MessagingReceipt memory)
    {
        MessagingFee memory fee = MessagingFee({nativeFee: msg.value, lzTokenFee: 0});

        lastSender = msg.sender;
        lastMessage = _params.message;
        lastFeeNative = fee.nativeFee;
        lastDstEid = _params.dstEid;
        lastReceiver = _params.receiver;

        emit PacketSent(lastDstEid, msg.sender, lastReceiver, lastMessage, fee);
        return MessagingReceipt({guid: keccak256(abi.encode(_params, block.timestamp)), nonce: 1, fee: fee});
    }

    // Backwards-compatible bytes variants (kept for other tests)
    function quote(bytes calldata, address) external pure returns (MessagingFee memory) {
        return MessagingFee({nativeFee: 0.01 ether, lzTokenFee: 0});
    }

    function send(
        bytes calldata _params,
        address /* _refundAddress */
    )
        external
        payable
        returns (MessagingReceipt memory)
    {
        MessagingFee memory fee = MessagingFee({nativeFee: msg.value, lzTokenFee: 0});

        // When called with bytes, capture raw bytes as payload
        lastSender = msg.sender;
        lastMessage = _params;
        lastFeeNative = fee.nativeFee;

        emit PacketSent(lastDstEid, msg.sender, lastReceiver, lastMessage, fee);
        return MessagingReceipt({guid: keccak256(abi.encode(_params, block.timestamp)), nonce: 1, fee: fee});
    }

    function lzReceive(
        address payable _oapp,
        uint32 _srcEid,
        bytes32 _sender,
        uint64 _nonce,
        bytes32 _guid,
        bytes calldata _message,
        bytes calldata _extraData
    ) external payable {
        // For receiver tests: forward to the OApp's public lzReceive entrypoint.
        Origin memory origin = Origin({srcEid: _srcEid, sender: _sender, nonce: _nonce});

        // Call the target OApp's lzReceive(Origin, bytes32, bytes, address, bytes)
        // Use low-level call to avoid importing the full OAppReceiver interface.
        (bool ok, bytes memory ret) = _oapp.call{value: msg.value}(
            abi.encodeWithSignature(
                "lzReceive((uint32,bytes32,uint64),bytes32,bytes,address,bytes)",
                origin,
                _guid,
                _message,
                address(this),
                _extraData
            )
        );

        if (!ok) {
            /* solhint-disable no-inline-assembly, gas-custom-errors */
            if (ret.length > 0) {
                assembly {
                    let retval_size := mload(ret)
                    revert(add(32, ret), retval_size)
                }
            }
            revert("lzReceive forward failed");
            /* solhint-enable no-inline-assembly, gas-custom-errors */
        }
    }

    function lzReceive(
        // OAppReceiver-style invocation from other tests / manualRetry
        Origin calldata _origin,
        address _receiver,
        bytes32 _guid,
        bytes calldata _message,
        bytes calldata _extraData
    ) external payable {
        // Forward to the receiver's lzReceive entrypoint
        (bool ok, bytes memory ret) = _receiver.call{value: msg.value}(
            abi.encodeWithSignature(
                "lzReceive((uint32,bytes32,uint64),bytes32,bytes,address,bytes)",
                _origin,
                _guid,
                _message,
                address(this),
                _extraData
            )
        );

        if (!ok) {
            /* solhint-disable no-inline-assembly, gas-custom-errors */
            if (ret.length > 0) {
                assembly {
                    let retval_size := mload(ret)
                    revert(add(32, ret), retval_size)
                }
            }
            revert("lzReceive forward failed");
            /* solhint-enable no-inline-assembly, gas-custom-errors */
        }
    }

    function setDefaultSendLibrary(uint32 _dstEid, address _newLib) external {
        defaultSendLibrary[_dstEid] = _newLib;
    }

    function setDefaultReceiveLibrary(uint32 _dstEid, address _newLib, uint256) external {
        defaultReceiveLibrary[_dstEid] = _newLib;
    }

    function setInboundPayloadHash(address _receiver, uint32 _srcEid, bytes32 _sender, uint64 _nonce, bytes32 _hash)
        external
    {
        inboundPayloadHash[_receiver][_srcEid][_sender][_nonce] = _hash;
    }

    function clear(address _oapp, Origin calldata, bytes32, bytes calldata) external {
        cleared[_oapp] = true;
    }
}
