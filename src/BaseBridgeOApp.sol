// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oapp/contracts/oapp/OApp.sol";
import {OAppSender, OAppCore} from "@layerzerolabs/oapp/contracts/oapp/OAppSender.sol";
import {IBaseBridgeOApp} from "./interfaces/IBaseBridgeOApp.sol";
import {IBridgeStorage} from "./interfaces/IBridgeStorage.sol";

contract BaseBridgeOApp is OAppSender, ReentrancyGuard, IBaseBridgeOApp {
    using SafeERC20 for IERC20;

    IERC20 private immutable TOKEN;
    uint32 private immutable DST_EID;
    IBridgeStorage private bridgeStorage;

    constructor(address _endpoint, address _delegate, address _owner, address _token, uint32 _dstEid)
        OAppCore(_endpoint, _delegate)
        Ownable(_owner)
    {
        TOKEN = IERC20(_token);
        // https://docs.layerzero.network/v2/concepts/glossary#endpoint-id
        DST_EID = _dstEid;
    }

    function bridgedAmount(address user) external view returns (uint256) {
        return bridgeStorage.getBridgedAmount(user);
    }

    /**
     * @notice Get the estimated fee for bridging
     * @return fee The estimated messaging fee
     */
    function quoteBridge() external view returns (MessagingFee memory fee) {
        (, uint256 delta) = _getCurrentAndDelta();

        bytes memory payload = abi.encode(address(1), delta, _msgSender());
        bytes memory options = bytes("");

        return _quote(DST_EID, payload, options, false);
    }

    function setBridgeStorage(address _bridgeStorage) external onlyOwner {
        require(_bridgeStorage != address(0), InvalidBridgeStorage());
        bridgeStorage = IBridgeStorage(_bridgeStorage);
    }

    function transferStorageOwnership(address newOwner) external onlyOwner {
        bridgeStorage.transferStorageOwnership(newOwner);
    }

    function bridgeTo(address recipient) external payable nonReentrant {
        require(recipient != address(0), RecipientZero());

        (uint256 current, uint256 delta) = _getCurrentAndDelta();
        bridgeStorage.setBridgedAmount(_msgSender(), current);

        bytes memory payload = abi.encode(recipient, delta, _msgSender());
        // see https://docs.layerzero.network/v2/tools/sdks/options#evm-solidity
        bytes memory options = bytes("");
        MessagingFee memory fee = _quote(DST_EID, payload, options, false /* only Ethereum */ );
        require(msg.value >= fee.nativeFee, InsufficientNativeFee());
        MessagingReceipt memory receipt = _lzSend(
            DST_EID,
            payload,
            options,
            fee,
            payable(_msgSender()) /* If the fee is overcharged, the fee reverts back to the user */
        );
        emit BridgeRequested(recipient, delta, _msgSender(), receipt);
    }

    function _getCurrentAndDelta() private view returns (uint256 current, uint256 delta) {
        current = TOKEN.balanceOf(_msgSender());
        uint256 prev = bridgeStorage.getBridgedAmount(_msgSender());
        require(current > prev, BalanceLessThanBridged());
        delta = current - prev;
        require(delta > 0, NoDelta());
    }
}
