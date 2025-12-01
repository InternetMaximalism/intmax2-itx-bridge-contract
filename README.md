# INTMAX2 ITX Bridge Contract

Implementation of ITX token bridge between L2s (Base, Scroll) and Ethereum using LayerZero v2.

## Overview

- **Sender OApp side (Base, Scroll)**: Checks the balance of non-transferable INTMAX Token and sends only the difference to Ethereum side.
- **Receiver OApp side (Ethereum)**: Receives messages from L2 side and transfers ITX tokens to specified addresses.

## Setup Guide
### 1. deploy ReceiverBridgeOApp on Ethereum
```bash
# set L1_ENDPOINT and L1_TOKEN and PRIVATE_KEY to .env file
# L1_ENDPOINT:Ethereum LayerZero Endpoint address
#             https://docs.layerzero.network/v2/deployments/chains/ethereum
# L1_TOKEN:Ethereum old ITX token address
# PRIVATE_KEY:deployer private key
forge script script/DeployReceiverBridge.s.sol:DeployReceiverBridge --rpc-url <ETH_RPC>
  --broadcast --etherscan-api-key <ETHERSCAN_API_KEY> --verify
```

### 2. deploy SenderBridgeOApp on L2 (Base, Scroll)
```bash
# set L2_ENDPOINT and L2_TOKEN and L2_DST_EID and PRIVATE_KEY to .env file
# L2_ENDPOINT:Base or Scroll LayerZero Endpoint address
#             https://docs.layerzero.network/v2/deployments/chains/base
#             https://docs.layerzero.network/v2/deployments/chains/scroll
# L2_TOKEN:L2 old ITX token address
# L2_DST_EID:Ethereum EID
#             https://docs.layerzero.network/v2/deployments/chains/ethereum
# PRIVATE_KEY:deployer private key
# For Base
forge script script/DeploySenderBridge.s.sol:DeploySenderBridge --rpc-url <BASE_RPC>
  --broadcast --etherscan-api-key <ETHERSCAN_API_KEY> --verify
# For Scroll
forge script script/DeploySenderBridge.s.sol:DeploySenderBridge --rpc-url <SCROLL_RPC>
  --broadcast --etherscan-api-key <ETHERSCAN_API_KEY> --verify
```

### 3. Peer Configuration (Bidirectional)

Connect L2 Sender and L1 Receiver by setting peers on both sides.

#### Sender (Base/Scroll) -> Receiver (Ethereum)
```bash
cast send <SENDER_OAPP_ADDRESS> "setPeer(uint32,bytes32)" <ETHEREUM_EID> <RECEIVER_ADDRESS_BYTES32> --rpc-url <L2_RPC> --private-key $PRIVATE_KEY
```

#### Receiver (Ethereum) -> Sender (Base/Scroll)
```bash
# For Base
cast send <RECEIVER_OAPP_ADDRESS> "setPeer(uint32,bytes32)" <BASE_EID> <BASE_SENDER_ADDRESS_BYTES32> --rpc-url <ETH_RPC> --private-key $PRIVATE_KEY

# For Scroll (EID: 30214)
cast send <RECEIVER_OAPP_ADDRESS> "setPeer(uint32,bytes32)" <SCROLL_EID> <SCROLL_SENDER_ADDRESS_BYTES32> --rpc-url <ETH_RPC> --private-key $PRIVATE_KEY
```

### 4. DVN Configuration (Sender Side)

**Critical for Mainnet:** At only mainnet, you must explicitly configure the DVN (Decentralized Verifier Network) on the Sender OApp. Default configurations may not work.

Use the provided script `script/ConfigureOApp.s.sol` to set up the DVN (e.g., LayerZero/Polyhedra DVN).

```
Detailed explanation of each field in the UlnConfig (Ultra Light Node Config) struct for LayerZero v2

struct UlnConfig {
    uint64 confirmations;
    uint8 requiredDVNCount;
    uint8 optionalDVNCount;
    uint8 optionalDVNThreshold;
    address[] requiredDVNs;
    address[] optionalDVNs;
}

1. confirmations (uint64)

Specifies the number of block confirmations to wait on the source chain.
	•	Meaning:
After a transaction is processed on the source chain, this defines how many additional blocks must be mined before the message is eligible for verification.
	•	Purpose:
This is a protection against chain reorganizations (reorgs).
If a reorg occurs and the transaction disappears, waiting for confirmations ensures that the system does not verify a message that may later be invalidated.
	•	Typical values:
Common values are 15 or 20.
For finality chains like Ethereum, this is often set to a depth considered safe.
Setting it to 0 allows immediate verification but increases reorg risk.

⸻

2. requiredDVNCount (uint8)

Specifies the number of required DVNs.
	•	Meaning:
Among the DVNs listed in requiredDVNs, this value defines how many must sign the message.
In most cases it should be equal to the full length of the list.
	•	Constraint:
Must match requiredDVNs.length.
	•	Role:
A message is considered verifiable only if all required DVNs (based on this count) approve it.

⸻

3. optionalDVNCount (uint8)

Specifies the total number of optional DVNs.
	•	Meaning:
This value indicates how many DVNs are listed in optionalDVNs.
	•	Constraint:
Must match optionalDVNs.length.

⸻

4. optionalDVNThreshold (uint8)

Specifies the minimum number of optional DVNs that must sign.
	•	Meaning:
From the optionalDVNs list, at least this many DVNs must sign for the message to be accepted.
	•	Examples:
If optionalDVNCount = 3 and optionalDVNThreshold = 1,
then any 1 of the 3 optional DVNs can sign to fulfill the requirement.
	•	Role:
This improves availability and decentralization.
Even if one DVN goes down, others can still satisfy the threshold.

⸻

5. requiredDVNs (address[])

A list of mandatory DVNs whose signatures are always required.
	•	Meaning:
Every DVN in this list must sign the message (as dictated by requiredDVNCount).
	•	Importance:
All these DVNs must participate; otherwise, verification cannot complete.
	•	Typical usage:
Often configured with one highly trusted DVN such as:
[LayerZero_Labs_DVN]

⸻

6. optionalDVNs (address[])

A list of optional DVNs that may sign the message.
	•	Meaning:
DVNs in this list contribute signatures only as needed to satisfy the optionalDVNThreshold.
	•	Role:
Enables flexible configurations—adding redundancy or decentralizing trust.
	•	Example:
You can register multiple optional DVNs such as:
	•	Google Cloud DVN
	•	Polyhedra DVN
And require signatures from only 1 or 2 of them.

```

```bash
# set L2_SENDER_OAPP and L2_DVN_ADDRESS and PRIVATE_KEY to .env file
# L2_SENDER_OAPP:Deployed SenderBridgeOApp address on L2
# L2_DVN_ADDRESS:DVN address for the target chain
#                https://docs.layerzero.network/v2/deployments/dvn-addresses
# PRIVATE_KEY:deployer private key
# Example for Base
export BASE_RPC=https://mainnet.base.org
forge script script/ConfigureOApp.s.sol:ConfigureBaseOApp --rpc-url $BASE_RPC --private-key $PRIVATE_KEY --broadcast
# Example for Scroll
export SCROLL_RPC=https://mainnet.scroll.io
forge script script/ConfigureOApp.s.sol:ConfigureScrollOApp --rpc-url $SCROLL_RPC --private-key $PRIVATE_KEY --broadcast
```

*Note: Ensure the script is updated with the correct DVN address and EID for the target chain.*


### 5. Receiver OApp Configuration (Ethereum)

The Receiver contract must hold ITX tokens and have the `MINTER_ROLE` to transfer them (due to ITX token logic).

1.  **Grant MINTER_ROLE**: Admin grants `MINTER_ROLE` to ReceiverBridgeOApp.
    ```bash
    cast send <ITX_TOKEN_ADDRESS> "grantRole(bytes32,address)" <MINTER_ROLE_HASH> <RECEIVER_OAPP_ADDRESS> --rpc-url <ETH_RPC> --private-key $PRIVATE_KEY
    ```
2.  **Fund Receiver**: Transfer ITX tokens to the ReceiverBridgeOApp address.
    ```bash
    cast send <ITX_TOKEN_ADDRESS> "transfer(address,uint256)" <RECEIVER_OAPP_ADDRESS> <AMOUNT> --rpc-url <ETH_RPC> --private-key $PRIVATE_KEY
    ```

## Usage

### Bridging Tokens

To bridge tokens from L2 to Ethereum:

1.  **Quote Fee**: Estimate the native fee (ETH) required for the bridge.
    ```bash
    cast call <SENDER_OAPP_ADDRESS> "quoteBridge()(uint256 nativeFee, uint256 zroFee)" --from <USER_ADDRESS> --rpc-url <L2_RPC>
    ```

2.  **Execute Bridge**: Call `bridgeTo` with the estimated fee.
    ```bash
    cast send <SENDER_OAPP_ADDRESS> "bridgeTo(address)" <RECIPIENT_ADDRESS> --value <NATIVE_FEE> --rpc-url <L2_RPC> --private-key <USER_PRIVATE_KEY>
    ```

## Development

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