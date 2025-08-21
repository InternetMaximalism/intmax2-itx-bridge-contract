// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IBridgeStorage} from "./interfaces/IBridgeStorage.sol";

/**
 * @title BridgeStorage
 * @notice Storage contract for bridge-related data
 * @dev This contract stores bridged amounts separately from the main bridge logic
 *      to enable upgradeability of the BaseBridgeOApp contract
 */
contract BridgeStorage is Ownable, IBridgeStorage {
    /// @dev Mapping of user addresses to their total bridged amounts
    mapping(address => uint256) private _bridgedAmount;

    /**
     * @notice Constructor sets the initial owner
     * @param _owner The address that will own this contract
     */
    constructor(address _owner) Ownable(_owner) {}

    function setBridgedAmount(address user, uint256 amount) external onlyOwner {
        _bridgedAmount[user] = amount;
        emit BridgedAmountUpdated(user, amount);
    }

    function getBridgedAmount(address user) external view returns (uint256) {
        return _bridgedAmount[user];
    }

    function transferStorageOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), InvalidAddress());
        _transferOwnership(newOwner);
    }
}
