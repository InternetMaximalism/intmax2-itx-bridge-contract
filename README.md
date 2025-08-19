# INTMAX2 ITX Bridge Contract

LayerZeroを使用したBase↔Mainnet ITXトークンブリッジの実装。

## 概要

- **Base側**: 非transferableなINTMAXTokenLの残高を確認し、差分のみをMainnet側に送信
- **Mainnet側**: Base側からのメッセージを受信し、指定されたアドレスにITXトークンを送金

## コントラクト構成

### Base側
- `BaseBridgeOApp.sol`: Base上のブリッジコントラクト（送信専用）
- ユーザーのINTMAXTokenL残高と累計bridge量を比較し、増分のみを送信

### Mainnet側  
- `MainnetBridgeOApp.sol`: Mainnet上のブリッジコントラクト（受信専用）
- Base側からのメッセージを受信し、ITXトークンを配布

## 主要機能

### Base側機能
- `bridgeTo(address recipient)`: 指定されたアドレスにITXトークンをブリッジ
- 残高チェック、差分計算、LayerZero経由での送信

### Mainnet側機能
- `mockLzReceive()`: LayerZeroからのメッセージ受信（テスト用）
- 送信元検証、トークン配布

## テスト

```bash
forge test
```

### テスト内容
- Base側: 正常なブリッジ、エラーハンドリング、部分的な増分処理
- Mainnet側: メッセージ受信、送信元検証、エラーハンドリング

## デプロイ

### Base Sepolia
```bash
forge script script/DeployBaseBridge.s.sol:DeployBaseBridge --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
```

### Sepolia  
```bash
BASE_BRIDGE_ADDRESS=<deployed_base_bridge_address> forge script script/DeployMainnetBridge.s.sol:DeployMainnetBridge --rpc-url $SEPOLIA_RPC_URL --broadcast
```

## 設定

### 環境変数
- `PRIVATE_KEY`: デプロイ用秘密鍵
- `BASE_SEPOLIA_RPC_URL`: Base Sepolia RPC URL
- `SEPOLIA_RPC_URL`: Sepolia RPC URL  
- `BASE_BRIDGE_ADDRESS`: デプロイ済みBaseブリッジアドレス

### コントラクトアドレス

#### Mainnet
- Base: `0xf95117e3a5B7968703CeD3B66A9CbE0Bc9e1D8bf`
- Ethereum: `0xe24e207c6156241cAfb41D025B3b5F0677114C81`

#### Testnet
- Base Sepolia: `0x2699CD7f883DecC464171a7A92f4CcC4eF220fa2`
- Sepolia: `0xA78B3d7db31EC214a33c5C383B606DA8B87DF41F`

## 実装上の注意点

1. **送信元検証**: Mainnet側では送信元チェーンIDとOAppアドレスの両方を検証
2. **ガス設定**: 受信側で必要なガス量を適切に設定する必要がある
3. **リトライ/スタック**: LayerZero V2のリトライ機能を活用
4. **Peer設定**: 両サイドでPeerアドレスを正しく設定する必要がある

## セキュリティ考慮事項

- 送信元の厳格な検証（srcEid + sender address）
- 残高チェックによる過剰送信の防止  
- ゼロアドレスへの送信防止
- 権限制御（owner-only functions）

## Foundry Usage

### Build
```shell
$ forge build
```

### Test
```shell
$ forge test
```

### Format
```shell
$ forge fmt
```
