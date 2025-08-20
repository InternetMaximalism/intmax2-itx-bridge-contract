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

# リトライ/スタック時の運用方法
## ステータス監視
BaseBridgeOAppのBridgeRequestedというイベントにguidが含まれているため、これを監視することでリトライやスタックの状態を確認できます。guidは送信ごとに一意であり、イベントが発火した際に確認できます。
正常終了のものはDELIVERED。
例えば24時間経ってもVERIFIEDだったり、いきなりFAILEDになったりする場合は、何らかの問題が発生している可能性があるので、対応を行います。
nonceの順番が重要になってくるので、フロントを一旦止めてメンテナンスに入る、などの対応が必要かも。。。

```
GET https://scan.layerzero-api.com/v1/messages/${guid}
GET https://scan-testnet.layerzero-api.com/v1/messages/${guid}

# GUIDでメッセージを取得
# 以下の文字列のいずれかが入る：
# 'INFLIGHT'　送信中...
# 'CONFIRMING'　確認中...
# 'DELIVERED' メッセージ配信完了
# 'VERIFIED'　検証済み（実行待ち）
# 'FAILED'　送信失敗
# 'PAYLOAD_STORED'　実行失敗 - 再試行が必要
# 'BLOCKED'　ブロック中 - 前のメッセージの問題を解決する必要
```

正常な流れは
INFLIGHT→CONFIRMING→VERIFIED→DELIVERED

## 緊急対応
FAILED->リトライ不可、クリアして直接トークンを送るなど手動対応。
24時間(時間は運用相談)経ってもINFLIGHT、CONFIRMING：ほぼないが、もし発生したらLayerZero運営に連絡
24時間(時間は運用相談)経ってもVERIFIED->Executorの問題。手動リトライ。
PAYLOAD_STORED-> DVNによる検証は完了したが、_lzReceive()の実行でrevert、hasStoredPayloadを実行し、trueならばmanualRetry、そうでなければパラメータが間違っている可能性大きい
BLOCKED->前のnonceのメッセージが処理されていないため配信ブロック、前のメッセージをクリアするなり、manualRetryしたりする

manualRetry->MainnetBridgeOAppのmanualRetry関数
    // messageはbaseで使用したもの
    // extra dataはapiで取得

クリア->MainnetBridgeOAppのclear関数
hasStoredPayloa->MainnetBridgeOAppのhasStoredPayload関数

        // receipt
// struct MessagingReceipt {
//     bytes32 guid;
//     uint64 nonce;
//     MessagingFee fee;
// }
// struct Origin {
//     uint32 srcEid; // baseのeid
//     bytes32 sender; // baseのoappのアドレス
//     uint64 nonce; // nonce
// }

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
