# INTMAX2 ITX Bridge Contract

Implementation of ITX token bridge between various L2s (Base, Scroll) and Ethereum using LayerZero v2.

## Overview

- **Sender OApp side (e.g., Base, Scroll)**: Checks the balance of non-transferable INTMAX Token and sends only the difference to Ethereum side
- **Receiver OApp side (Ethereum)**: Receives messages from Base side and transfers ITX tokens to specified addresses

## Contract Architecture

### Sender OApp (e.g., Base, Scroll)- `SenderBridgeOApp.sol`: Bridge contract on Sender OApp side (send-only)
- `BridgeStorage.sol`: External storage to record users' bridged amounts
- Compares user's INTMAX Token balance with cumulative bridged amount and sends only the increment

### Receiver OApp (Ethereum)
- `ReceiverBridgeOApp.sol`: Bridge contract on Receiver OApp side (receive-only)
- Receives messages from Base side and distributes ITX tokens

## Main Features

### Sender OApp Side Functions
- `bridgeTo(address recipient)`: Bridge ITX tokens to specified address
- `quoteBridge()`: Estimate fees required for bridging
- `setGasLimit(uint128 _gasLimit)`: Set LayerZero execution gas limit
- `setBridgeStorage(address _bridgeStorage)`: Set external storage

### Receiver OApp Side Functions
- `_lzReceive()`: Receive and process messages from LayerZero
- `manualRetry()`: Manual retry for failed messages
- `clearMessage()`: Clear problematic messages

## Deployment

### Environment Variables Setup

Copy `.env.example` to create `.env` file and configure the following settings:

```bash
# deploy
PRIVATE_KEY=0xyour_private_key_here

## base
BASE_ENDPOINT=0x6EDCE65403992e310A62460808c4b910D972f10f
BASE_TOKEN=0xC79BB8DB83950b9c5AE5dF2E56bb502968EE6dB5
BASE_DST_EID=11155111

## mainnet
MAINNET_ENDPOINT=0x6EDCE65403992e310A62460808c4b910D972f10f
MAINNET_TOKEN=0xA78B3d7db31EC214a33c5C383B606DA8B87DF41F
```

**Configuration Values:**
- `PRIVATE_KEY`: Private key for deployment (0x prefix required)
- `BASE_ENDPOINT`: LayerZero Endpoint for Sender OApp (e.g., Base Sepolia, Scroll Sepolia)
- `BASE_TOKEN`: ITX token address on Sender OApp (e.g., Base Sepolia, Scroll Sepolia)  
- `BASE_DST_EID`: Destination Endpoint ID (e.g., Ethereum Sepolia = 11155111)
- `MAINNET_ENDPOINT`: LayerZero Endpoint for Receiver OApp (Ethereum Sepolia)
- `MAINNET_TOKEN`: ITX token address on Receiver OApp (Ethereum Sepolia)

### Sender OApp (e.g., Base Sepolia, Scroll Sepolia) Deployment

```bash
forge script script/DeploySenderBridge.s.sol:DeploySenderBridge --rpc-url https://sepolia.base.org --broadcast --etherscan-api-key $BASESCAN_API_KEY --verify
```

### Receiver OApp (Ethereum Sepolia) Deployment

```bash
forge script script/DeployReceiverBridge.s.sol:DeployReceiverBridge --rpc-url https://sepolia.rpc.thirdweb.com --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify
```

## Setup

### 1. Peer Configuration

Bidirectional peer connections must be configured:
Execute setPeer function on each side.
Specify the EID and OApp address of the communication partner.
OApp address must be specified in bytes32 format.

#### SenderBridgeOApp Side (e.g., Base Sepolia)
```bash
# Peer setting with ReceiverBridgeOApp
cast send <SenderBridgeOApp_address> \
  "setPeer(uint32,bytes32)" \
  <ReceiverOApp_eid> \
  <ReceiverBridgeOApp_address_bytes32> \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY
```

#### ReceiverBridgeOApp Side (Ethereum Sepolia)
```bash
# Peer setting with SenderBridgeOApp
cast send <ReceiverBridgeOApp_address> \
  "setPeer(uint32,bytes32)" \
  <SenderOApp_eid> \
  <SenderBridgeOApp_address_bytes32> \
  --rpc-url https://sepolia.rpc.thirdweb.com \
  --private-key $PRIVATE_KEY
```

## Testing

```bash
forge test
```

### Test Coverage
- Sender OApp side: Normal bridging, error handling, gas limit setting, external storage
- Receiver OApp side: Message reception, source verification, manual retry

## Deployed Addresses

### Testnet (Sepolia Network)
- **SenderBridgeOApp** (Base Sepolia): `0x5312f4968901Ec9d4fc43d2b0e437041614B14A2`
- **BridgeStorage** (Base Sepolia): `0x871fAee277bC6D7A695566F6f60C22CD9d8714Ef`
- **ReceiverBridgeOApp** (Ethereum Sepolia): `0x6B9eFE6980665B8462059D97C36674e26bc49298`

## Message Monitoring

### Status Monitoring

Get GUID from `BridgeRequested` event when executing `bridgeTo`, and monitor via LayerZero Scan API:

```bash
# Testnet
GET https://scan-testnet.layerzero-api.com/v1/messages/guid/{guid}

# Mainnet  
GET https://scan.layerzero-api.com/v1/messages/guid/{guid}
```

Check status in `data[0]["status"]["name"]` of API response:

### Message Status Types
- `INFLIGHT`: Sending
- `DELIVERED`: Delivery complete (normal completion)
- `PAYLOAD_STORED`: Execution failed, retry required
- `BLOCKED`: Previous message is stuck
- `FAILED`: Send failed

### Normal Flow
`INFLIGHT` → `DELIVERED`

## Emergency Response

### PAYLOAD_STORED (Execution Failed)
```bash
# Manual retry
cast send <ReceiverBridgeOApp_address> \
  "manualRetry((uint32,bytes32,uint64),bytes32,bytes,bytes)" \
  "(srcEid,sender,nonce)" \
  "guid" \
  "message" \
  "extraData" \
  --rpc-url https://sepolia.rpc.thirdweb.com \
  --private-key $PRIVATE_KEY
```

### BLOCKED (Message Blocked)
```bash
# Message clear (owner only)
cast send <ReceiverBridgeOApp_address> \
  "clearMessage((uint32,bytes32,uint64),bytes32,bytes)" \
  "(srcEid,sender,nonce)" \
  "guid" \
  "message" \
  --rpc-url https://sepolia.rpc.thirdweb.com \
  --private-key $PRIVATE_KEY
```

## Security Features

- Strict source verification (srcEid + sender address)
- Prevention of excessive sending through balance checks  
- Prevention of sending to zero address
- Access control (owner-only functions)
- Reentrancy attack protection
- Upgrade compatibility through external storage pattern

## Technical Specifications

- **Solidity**: 0.8.30
- **LayerZero**: v2
- **OpenZeppelin**: Ownable, SafeERC20, ReentrancyGuard
- **Default Gas Limit**: 200,000 (configurable)

## Development Commands

### Build
```bash
forge build
```

### Test
```bash
forge test
```

### Format
```bash
forge fmt
```

### Lint
```bash
npm install
npm run lint:fix
```

## LayerZero Endpoint IDs

- **Base Sepolia**: 84532
- **Ethereum Sepolia**: 11155111
- **Base Mainnet**: 184
- **Ethereum Mainnet**: 30101