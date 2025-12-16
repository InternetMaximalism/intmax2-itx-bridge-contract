// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ReentrancyGuardUpgradeable} from "@openzeppelin-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import {
    OAppSenderUpgradeable,
    OAppCoreUpgradeable
} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppSenderUpgradeable.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp/contracts/oapp/libs/OptionsBuilder.sol";
import {Initializable} from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ISenderBridgeOApp} from "./interfaces/ISenderBridgeOApp.sol";

// Removed explicit OwnableUpgradeable inheritance as it is inherited via OAppSenderUpgradeable -> OAppCoreUpgradeable
contract SenderBridgeOApp is
    Initializable,
    OAppSenderUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    ISenderBridgeOApp
{
    using SafeERC20 for IERC20;

    IERC20 public immutable TOKEN;
    uint32 public immutable DST_EID;

    struct SenderBridgeOAppStorage {
        mapping(address => uint256) bridgedAmount;
        uint128 gasLimit;
    }

    // keccak256(abi.encode(uint256(keccak256("intmax2-itx-bridge-contract.storage.SenderBridgeOApp")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SENDER_BRIDGE_OAPP_STORAGE_LOCATION =
        0xfc9baf85f941428a20b85d2a866e8a37b69970d9f5c3455eed42ca3379599c00;

    function _getSenderBridgeOAppStorage() internal pure returns (SenderBridgeOAppStorage storage $) {
        /* solhint-disable no-inline-assembly */
        assembly {
            $.slot := SENDER_BRIDGE_OAPP_STORAGE_LOCATION
        }
        /* solhint-enable no-inline-assembly */
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _endpoint, address _token, uint32 _dstEid) OAppCoreUpgradeable(_endpoint) {
        TOKEN = IERC20(_token);
        DST_EID = _dstEid;
        _disableInitializers();
    }

    function initialize(address _delegate, address _owner) public initializer {
        __OAppSender_init(_delegate);
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        SenderBridgeOAppStorage storage $ = _getSenderBridgeOAppStorage();
        $.gasLimit = 200000;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice Set the gas limit for LayerZero message execution on the destination chain
     * @param _gasLimit The new gas limit value (must be greater than 0)
     * @dev Only callable by contract owner
     * @dev Emits GasLimitUpdated event
     */
    function setGasLimit(uint128 _gasLimit) external onlyOwner {
        SenderBridgeOAppStorage storage $ = _getSenderBridgeOAppStorage();
        uint128 oldLimit = $.gasLimit;
        $.gasLimit = _gasLimit;
        emit GasLimitUpdated(oldLimit, _gasLimit);
    }

    function gasLimit() external view returns (uint128) {
        SenderBridgeOAppStorage storage $ = _getSenderBridgeOAppStorage();
        return $.gasLimit;
    }

    function bridgedAmount(address user) external view returns (uint256) {
        SenderBridgeOAppStorage storage $ = _getSenderBridgeOAppStorage();
        return $.bridgedAmount[user];
    }

    /**
     * @notice Get the estimated fee for bridging
     * @return fee The estimated messaging fee
     */
    function quoteBridge() external view returns (MessagingFee memory fee) {
        (, uint256 delta) = _getCurrentAndDelta();

        bytes memory payload = abi.encode(address(1), delta, _msgSender());
        bytes memory options = _getDefaultOptions();

        return _quote(DST_EID, payload, options, false);
    }

    function bridgeTo(address recipient) external payable nonReentrant {
        require(recipient != address(0), RecipientZero());

        (uint256 current, uint256 delta) = _getCurrentAndDelta();

        // Update local state directly
        SenderBridgeOAppStorage storage $ = _getSenderBridgeOAppStorage();
        $.bridgedAmount[_msgSender()] = current;
        emit BridgedAmountUpdated(_msgSender(), current);

        bytes memory payload = abi.encode(recipient, delta, _msgSender());
        // see https://docs.layerzero.network/v2/tools/sdks/options#evm-solidity
        bytes memory options = _getDefaultOptions();
        MessagingFee memory fee = _quote(
            DST_EID,
            payload,
            options,
            false /* only Ethereum */
        );
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
        SenderBridgeOAppStorage storage $ = _getSenderBridgeOAppStorage();
        uint256 prev = $.bridgedAmount[_msgSender()];
        require(current > prev, BalanceLessThanBridged());
        delta = current - prev;
        require(delta > 0, NoDelta());
    }

    /**
     * @dev Internal function to generate LayerZero execution options with the current gas limit
     * @return The encoded options for LayerZero message execution
     */
    function _getDefaultOptions() private view returns (bytes memory) {
        SenderBridgeOAppStorage storage $ = _getSenderBridgeOAppStorage();
        return OptionsBuilder.addExecutorLzReceiveOption(OptionsBuilder.newOptions(), $.gasLimit, 0);
    }
}
