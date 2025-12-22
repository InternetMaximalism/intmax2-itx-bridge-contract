# GEMINI.md - AI Agent Context & Instructions

This file serves as the primary context and instruction set for AI agents (e.g., Gemini) working on the `intmax2-itx-bridge-contract` project.
At the start of a session, please read this file to understand the project scope, architecture, and coding standards.

## 1. Project Overview
- **Name:** Intmax2 ITX Bridge Contract
- **Purpose:** A token bridge from Ethereum/Scroll (Source) to Base (Destination) using LayerZero v2.
- **Core Mechanism:** **"Proof of Holding"**. Unlike traditional Lock & Mint or Burn & Mint bridges, the Sender contract on the source chain calculates the "Delta" (increase in user balance since last bridge) and sends a message to Base. No burning or locking occurs on the source chain.
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
  - Holds ITX tokens on Base and transfers them to recipients upon receiving a valid LayerZero message.
- **`test/Integration.t.sol`:**
  - End-to-end integration tests using MockEndpointV2.
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

---
**Language:** While this file is in English, please interact with the user in **Japanese** unless requested otherwise.
