# GEMINI.md - AI Agent Context & Instructions

This file serves as the primary context and instruction set for AI agents (e.g., Gemini) working on the `intmax2-itx-bridge-contract` project.
At the start of a session, please read this file to understand the project scope, architecture, and coding standards.

## 1. Project Overview
- **Name:** Intmax2 ITX Bridge Contract
- **Purpose:** A token bridge from Ethereum/Scroll (Source) to Base (Destination) using LayerZero v2.
- **Core Mechanism:** **"Proof of Holding"**. Unlike traditional Lock & Mint or Burn & Mint bridges, the Sender contract on the source chain calculates the "Delta" (increase in user balance since last bridge) and sends a message to Base. No burning or locking occurs on the source chain. On Base, the Receiver contract adds vesting allowance to the recipient via the Vesting contract, allowing them to create vesting plans and claim tokens over time.
- **Stack:** Solidity 0.8.33, Foundry, LayerZero v2 (OApp), OpenZeppelin Upgradeable.

## 2. Architecture & Key Files
- **`src/SenderBridgeOApp.sol` (Source: Ethereum/Scroll):**
  - The core Sender contract.
  - **Upgradeable** (UUPS).
  - Uses **Unstructured Storage** pattern manually (via assembly slots) to manage state.
  - **Crucial:** Checks `TOKEN.balanceOf(user)` vs `bridgedAmount[user]` to determine the transferable amount.
- **`src/ReceiverBridgeOApp.sol` (Dest: Base):**
  - The Receiver contract.
  - **Non-Upgradeable** (Immutable logic).
  - Integrates with the Vesting contract on Base and adds vesting allowance to recipients upon receiving a valid LayerZero message.
  - **Important:** Does not hold tokens directly. Token distribution is managed by the Vesting contract.
- **`src/interfaces/IVesting.sol`:**
  - Temporary interface for the Vesting contract.
  - Defines `addBridgeAllowance(address user, uint256 amount)` function.
  - **Note:** This is a temporary interface. Once https://github.com/InternetMaximalism/intmax2-itx-vesting-contract is released, install it via `forge install` and use the official interface.
- **`test/Integration.t.sol`:**
  - End-to-end integration tests using MockEndpointV2.
- **`test/mocks/MockVesting.sol`:**
  - Mock implementation of the Vesting contract for testing.
  - Implements `addBridgeAllowance()` and `getAllowance()` functions.
- **`foundry.toml`:**
  - Configuration file. Explicitly sets `solc = "0.8.33"`.

## 3. Coding Standards & Constraints
- **Solidity Version:** Strictly `0.8.33`.
- **Storage Layout (Critical):**
  - Do **NOT** use the Solidity 0.8.29+ `layout at` syntax in `SenderBridgeOApp`. It causes inheritance issues with test mocks.
  - Maintain the existing **Unstructured Storage** pattern using `struct SenderBridgeOAppStorage` and assembly slot management.
- **Inheritance:** `SenderBridgeOApp` inherits `OAppSenderUpgradeable`, `ReentrancyGuardUpgradeable`, `UUPSUpgradeable`. Be mindful of storage collisions.
- **Style:** Adhere to OpenZeppelin and standard Foundry formatting.

## 4. Development Workflow (Instructions for AI)
When asked to modify code, follow this strict cycle:

1.  **Analyze:** Read the target files and associated tests (`test/`).
2.  **Plan:** Briefly explain the intended changes.
3.  **Implement:** Apply changes using available tools.
4.  **Verify:**
    - Run `forge build` to ensure no compilation errors.
    - Run `forge test` to ensure regressions are avoided.
    - If new features are added, create corresponding tests.
5.  **Format:** Run `forge fmt` or `yes | npm run lint:fix` to ensure code style consistency.

## 5. Known Issues & Notes
- **Forge-std Warnings:** You may see numerous Solc warnings from dependencies (e.g. `lib/forge-std`); this repo ignores common warning codes via `foundry.toml` (`ignored_error_codes`).
- **Compiler Version:** If checksum/version mismatches occur for solc 0.8.33, ensure your Foundry installation has the configured compiler available (e.g. run `foundryup`).
- **Vesting Contract Integration:**
  - `ReceiverBridgeOApp` depends on the Vesting contract being deployed first.
  - After deploying `ReceiverBridgeOApp`, the Vesting contract owner must call `IVesting.setBridge(receiverBridgeAddress, true)` to authorize it.
  - The temporary `IVesting.sol` interface will be replaced once the official vesting contract package is published.
- **Bridge Fee Precision (Critical):**
  - When calling `bridgeTo()`, the `msg.value` must be the **exact** amount returned by `quoteBridge()`.
  - The `OAppSenderUpgradeable._payNative()` function checks `msg.value == fee.nativeFee`, NOT `msg.value >= fee.nativeFee`.
  - Sending more ETH than the quoted fee will cause a `NotEnoughNative(uint256)` revert.
  - Example workflow:
    ```bash
    # 1. Get exact fee
    FEE=$(cast call <SENDER_OAPP> "quoteBridge()(uint256,uint256)" --from <USER> --rpc-url <RPC> | head -1)
    # 2. Use exact fee in bridgeTo
    cast send <SENDER_OAPP> "bridgeTo(address)" <RECIPIENT> --value $FEE --private-key <KEY> --rpc-url <RPC>
    ```

---
**Language:** While this file is in English, please interact with the user in **Japanese** unless requested otherwise.
