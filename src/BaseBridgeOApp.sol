// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessagingFee} from "@layerzerolabs/oapp/contracts/oapp/OApp.sol";
import {OAppSender, OAppCore} from "@layerzerolabs/oapp/contracts/oapp/OAppSender.sol";
import {IBaseBridgeOApp} from "./interfaces/IBaseBridgeOApp.sol";

// TODO upgradable reentrancy　、ethが戻ってくるという裏をとる、
// 受信側で必要なガスの量を指定した方が良いでしょうか?
// リトライ/スタック時の運用方法について記載していただけますと幸いです。
// ethはユーザに戻るらしい。receiveイランのちゃうか。
contract BaseBridgeOApp is OAppSender, IBaseBridgeOApp {
    using SafeERC20 for IERC20;

    IERC20 private immutable _TOKEN;
    uint32 private immutable _DST_EID;

    mapping(address => uint256) private _bridgedAmount;

    constructor(address _endpoint, address _delegate, address _owner, address _token, uint32 _dstEid)
        OAppCore(_endpoint, _delegate)
        Ownable(_owner)
    {
        _TOKEN = IERC20(_token);
        // https://docs.layerzero.network/v2/concepts/glossary#endpoint-id
        _DST_EID = _dstEid;
    }

    function bridgedAmount(address user) external view returns (uint256) {
        return _bridgedAmount[user];
    }

    function bridgeTo(address recipient) external payable {
        require(recipient != address(0), RecipientZero());

        uint256 current = _TOKEN.balanceOf(_msgSender());
        uint256 prev = _bridgedAmount[_msgSender()];
        require(current > prev, BalanceLessThanBridged());
        uint256 delta = current - prev;
        require(delta > 0, NoDelta());
        _bridgedAmount[_msgSender()] = current;

        bytes memory payload = abi.encode(recipient, delta, _msgSender());
        // see https://docs.layerzero.network/v2/tools/sdks/options#evm-solidity
        bytes memory options = bytes("");
        MessagingFee memory fee = _quote(_DST_EID, payload, options, false /* only Ethereum */ );
        // TODO きっちりにしたほうがいいのでは。
        require(msg.value >= fee.nativeFee, InsufficientNativeFee());
        _lzSend(
            _DST_EID,
            payload,
            options,
            fee,
            payable(_msgSender()) /* If the fee is overcharged, the fee reverts back to the user */
        );

        emit BridgeRequested(_msgSender(), recipient, delta, fee.nativeFee);
    }
}
