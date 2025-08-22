# Deployment Guide

This guide explains how to deploy the Base Bridge and Mainnet Bridge contracts using environment variables for configuration.

## Prerequisites

1. **Create environment file**: Copy `.env.example` to `.env` and fill in your values:
   ```bash
   cp .env.example .env
   ```

2. **Required environment variables**:
   - `PRIVATE_KEY`: Your deployment private key (without 0x prefix)
   - Network-specific configurations (see below)

## Environment Variables

### Base Bridge Configuration
- `BASE_ENDPOINT`: LayerZero V2 endpoint address for Base network
- `BASE_TOKEN`: ITX token address on Base network  
- `BASE_DST_EID`: Destination endpoint ID (Ethereum/Sepolia)

### Mainnet Bridge Configuration
- `MAINNET_ENDPOINT`: LayerZero V2 endpoint address for Ethereum network
- `MAINNET_TOKEN`: ITX token address on Ethereum network
- `MAINNET_SRC_EID`: Source endpoint ID (Base network)
- `MAINNET_SRC_SENDER` or `BASE_BRIDGE_ADDRESS`: Source sender configuration

### Optional Configuration
- `GAS_LIMIT`: Gas limit for LayerZero execution (default: 200000)

## Deployment Steps

### 1. Deploy Base Bridge

```bash
# Set up your .env file first
forge script script/DeployBaseBridge.s.sol:DeployBaseBridge --rpc-url <BASE_RPC_URL> --broadcast --verify
```

### 2. Update Configuration

After deploying BaseBridge, update your `.env` file with the deployed address:
```bash
BASE_BRIDGE_ADDRESS=0x1234567890123456789012345678901234567890
```

### 3. Deploy Mainnet Bridge

```bash
forge script script/DeployMainnetBridge.s.sol:DeployMainnetBridge --rpc-url <MAINNET_RPC_URL> --broadcast --verify
```

## Example .env Configuration

### Testnet (Base Sepolia ↔ Ethereum Sepolia)
```bash
PRIVATE_KEY=your_private_key_here

# Base Sepolia
BASE_ENDPOINT=0x6EDCE65403992e310A62460808c4b910D972f10f
BASE_TOKEN=0x2699CD7f883DecC464171a7A92f4CcC4eF220fa2
BASE_DST_EID=40161

# Ethereum Sepolia
MAINNET_ENDPOINT=0x6EDCE65403992e310A62460808c4b910D972f10f
MAINNET_TOKEN=0xA78B3d7db31EC214a33c5C383B606DA8B87DF41F
MAINNET_SRC_EID=40245

# Set after BaseBridge deployment
BASE_BRIDGE_ADDRESS=0x1234567890123456789012345678901234567890

GAS_LIMIT=200000
```

### Mainnet (Base ↔ Ethereum)
```bash
PRIVATE_KEY=your_private_key_here

# Base Mainnet
BASE_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c
BASE_TOKEN=0x1234567890123456789012345678901234567890  # Your ITX token on Base
BASE_DST_EID=30101  # Ethereum Mainnet EID

# Ethereum Mainnet
MAINNET_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c
MAINNET_TOKEN=0x1234567890123456789012345678901234567890  # Your ITX token on Ethereum
MAINNET_SRC_EID=30184  # Base Mainnet EID

BASE_BRIDGE_ADDRESS=0x1234567890123456789012345678901234567890

GAS_LIMIT=300000
```

## Verification

After deployment, verify the contracts are configured correctly:

1. **Check Base Bridge**:
   - Verify `bridgeStorage` is set
   - Verify `gasLimit` is configured
   - Verify ownership is correct

2. **Check Mainnet Bridge**:
   - Verify source sender is set correctly
   - Verify token balances for distribution

3. **Set up LayerZero peer connections** (if not done automatically):
   ```solidity
   baseBridge.setPeer(dstEid, mainnetBridgeBytes32Address);
   mainnetBridge.setPeer(srcEid, baseBridgeBytes32Address);
   ```

## Troubleshooting

### Common Issues

1. **"No source sender set"**: Make sure either `BASE_BRIDGE_ADDRESS` or `MAINNET_SRC_SENDER` is set in your `.env`

2. **Gas estimation failed**: Check that your account has enough ETH for deployment

3. **Invalid endpoint**: Verify the LayerZero endpoint addresses for your target networks

4. **Token address errors**: Ensure the token addresses are correct for each network

### LayerZero Endpoint IDs

- **Ethereum Mainnet**: 30101
- **Base Mainnet**: 30184
- **Ethereum Sepolia**: 40161
- **Base Sepolia**: 40245

### LayerZero V2 Endpoints

- **Ethereum Mainnet/Sepolia**: 0x1a44076050125825900e736c501f859c50fE728c
- **Base Mainnet/Sepolia**: 0x1a44076050125825900e736c501f859c50fE728c (check LayerZero docs for latest)