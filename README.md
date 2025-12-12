# INTMAX2 ITX Bridge Contract

![License](https://img.shields.io/badge/License-MIT-blue.svg)
![Solidity](https://img.shields.io/badge/Solidity-0.8.31-363636.svg)
![LayerZero](https://img.shields.io/badge/LayerZero-V2-orange.svg)

Implementation of the ITX token bridge from Ethereum/Scroll to Base using LayerZero v2.

## 🌉 Architecture

```mermaid
graph LR
    User((User)) --> |1. bridgeTo| Sender["SenderBridgeOApp<br>(Source: Ethereum/Scroll)"]
    Sender --> |2. Verify & Send| LZ[LayerZero Endpoint]
    LZ --> |3. Receive| Receiver["ReceiverBridgeOApp<br>(Dest: Base)"]
    Receiver --> |4. Transfer ITX| Recipient((Recipient))
```

- **Sender OApp**: Calculates `delta` (Current Balance - Bridged Amount) and sends the message.
- **Receiver OApp**: Receives the message and transfers the specified amount of ITX tokens from its own balance on Base.

## 🚀 Deployment Guide (Mainnet)

This project includes an automated script that handles deployment, peer configuration, DVN setup, and token funding across all chains (Ethereum, Scroll, Base).

### 1. Prerequisites

Ensure you have [Foundry](https://book.getfoundry.sh/) installed.

### 2. Configure .env

Create a `.env` file with the following variables. This script uses `vm.createSelectFork`, so you must provide RPC URLs in `foundry.toml` or via environment variables if configured.

```ini
# Deployer
PRIVATE_KEY=0x... # Must have funds on Ethereum, Scroll, and Base

# --- Endpoints & EIDs (LayerZero V2) ---
# These constants are defined in the script, but ensure your foundry.toml has rpc_endpoints.

# --- Sender Configuration (Ethereum) ---
ETHEREUM_DELEGATE=0x...
ETHEREUM_OWNER=0x...
ETHEREUM_OLD_TOKEN=0x... # Old ITX on Ethereum

# --- Sender Configuration (Scroll) ---
SCROLL_DELEGATE=0x...
SCROLL_OWNER=0x...
SCROLL_OLD_TOKEN=0x... # Old ITX on Scroll

# --- Receiver Configuration (Base) ---
BASE_DELEGATE=0x...
BASE_OWNER=0x...
BASE_OLD_TOKEN=0x... # ITX on Base

# --- Token Setup (Base) ---
# To automatically fund the receiver and grant roles:
BASE_OLD_TOKEN_ADMIN_PRIVATE_KEY=0x... # Key with admin role on Base Token
BASE_OLD_TOKEN_TREASURY_PRIVATE_KEY=0x... # Key with funds to transfer to Receiver
BASE_OLD_TOKEN_TRANSFER_AMOUNT_FROM_TREASURY=500000000000000000000000 # e.g. 500,000 ITX
```

### 3. Run the Automated Script

This command will:
1.  Deploy `SenderBridgeOApp` on Ethereum and Scroll.
2.  Deploy `ReceiverBridgeOApp` on Base.
3.  Configure Peers (bidirectional trust).
4.  Configure DVNs (LayerZero verification).
5.  Grant `MINTER_ROLE` to the Receiver on Base.
6.  Fund the Receiver with ITX tokens on Base.

```bash
forge script script/DeployAndAllSetupMainnet.s.sol:DeployAndAllSetupMainnet --broadcast --verify
```

> **Note:** The script switches chains automatically. Ensure your `PRIVATE_KEY` has ETH for gas on all three chains.
>
> **Configuration Note:** The script configures the OApps to use the **LayerZero Labs DVN** with **15 block confirmations** by default. To change these settings, please modify `script/DeployAndAllSetupMainnet.s.sol`, `script/ConfigureSenderOApp.s.sol`, and `script/ConfigureReceiverOApp.s.sol`.

## 💻 Usage (Bridging)

Once deployed, users can bridge tokens from Ethereum or Scroll to Base.

1.  **Quote Fee**: Check the Native fee required.
    ```bash
    # Run on Source Chain (Ethereum or Scroll)
    cast call <SENDER_OAPP> "quoteBridge()(uint256 nativeFee, uint256 zroFee)" --from <USER> --rpc-url <SOURCE_RPC>
    ```

2.  **Execute Bridge**: Send tokens.
    ```bash
    # Run on Source Chain (Ethereum or Scroll)
    cast send <SENDER_OAPP> "bridgeTo(address)" <RECIPIENT> --value <NATIVE_FEE> --rpc-url <SOURCE_RPC> --private-key <USER_KEY>
    ```

## 🛠 Development Commands

```bash
# Build
forge build

# Test
forge test

# Format & Lint
forge fmt
npm run lint:fix
```