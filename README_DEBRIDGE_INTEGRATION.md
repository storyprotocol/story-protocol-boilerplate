# deBridge + Story Protocol Integration

> **Cross-chain royalty payments for IP assets made simple**

This repository demonstrates how to integrate [deBridge DLN](https://dln.debridge.finance/) with [Story Protocol](https://storyprotocol.xyz/) to enable cross-chain royalty payments for intellectual property assets.

## 🚀 Overview

Enable users to pay royalties for Story Protocol IP assets from **any supported blockchain** to Story mainnet using deBridge as the cross-chain bridge infrastructure.

### The Flow
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Ethereum  │    │   deBridge  │    │   Story     │    │  Royalty    │
│     User    │───▶│     DLN     │───▶│  Mainnet    │───▶│   Payment   │
│  (ETH/USDC) │    │ (Swap+Bridge) │    │ (WIP Token) │    │  Complete   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

1. **User initiates payment** on source chain (e.g., Ethereum) with any supported token
2. **deBridge swaps and bridges** tokens to Story mainnet as WIP tokens
3. **Auto-approval**: deBridge ExternalCallExecutor automatically approves WIP to RoyaltyModule
4. **Hook execution**: Direct call to `RoyaltyModule.payRoyaltyOnBehalf()` completes payment

## ✨ Key Features

- **🔗 Cross-chain**: Pay from Ethereum, Polygon, BSC, or any deBridge-supported chain
- **🎯 Simple integration**: No complex orchestration - direct contract calls
- **⚡ Auto-approval**: No manual token approvals needed
- **🛡️ Production-ready**: Uses real Story Protocol mainnet contracts
- **📊 Gas-optimized**: Direct calls without unnecessary middleware

## 🏗️ Technical Architecture

### Core Components

| Component | Address | Description |
|-----------|---------|-------------|
| **RoyaltyModule** | `0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086` | Story Protocol royalty payment contract |
| **WIP Token** | `0x1514000000000000000000000000000000000000` | Wrapped IP token on Story mainnet |
| **deBridge DLN** | Various | Cross-chain liquidity network |

### Integration Pattern

```solidity
// ✅ Simplified approach - no Multicall3 needed!
{
  "type": "evm_transaction_call",
  "data": {
    "to": "0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086",  // RoyaltyModule
    "calldata": "0xd2577f3b...",                          // payRoyaltyOnBehalf()
    "gas": 0                                              // Auto-estimate
  }
}
```

### Why No Multicall3?

deBridge's `ExternalCallExecutor` automatically handles token approvals:

```solidity
// From deBridge ExternalCallExecutor.onERC20Received()
if (_transferredAmount != 0) {
    _customApprove(_token, executionData.to, _transferredAmount);
}
// Then executes our hook directly
```

## 🧪 Testing

### Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone and setup
git clone <repository>
cd story-protocol-boilerplate
forge install
```

### Run Integration Test

```bash
# Test complete cross-chain royalty payment flow
forge test --match-test test_crossChainRoyaltyPayment -vv
```

### Expected Output

```
✅ deBridge API correctly processes hook payload
✅ Transaction estimation succeeds with gas: ~420,000
✅ Order ID generated for cross-chain execution
✅ Hook contains payRoyaltyOnBehalf selector (0xd2577f3b)
✅ WIP token address confirmed in response
```

## 📋 Integration Guide

### 1. Construct Hook Payload

```typescript
const hookPayload = {
  type: "evm_transaction_call",
  data: {
    to: "0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086", // RoyaltyModule
    calldata: encodeFunctionData({
      abi: royaltyModuleAbi,
      functionName: "payRoyaltyOnBehalf",
      args: [
        ipAssetId,      // IP asset receiving royalties
        "0x0",          // External payer
        wipTokenAddress, // WIP token
        paymentAmount   // Amount in WIP
      ]
    }),
    gas: 0 // Auto-estimate
  }
};
```

### 2. Create deBridge Order

```typescript
const apiUrl = `https://dln.debridge.finance/v1.0/dln/order/create-tx?` +
  `srcChainId=1&` +                                    // Ethereum
  `srcChainTokenIn=0x0000000000000000000000000000000000000000&` + // ETH
  `srcChainTokenInAmount=${amount}&` +
  `dstChainId=100000013&` +                           // Story mainnet
  `dstChainTokenOut=0x1514000000000000000000000000000000000000&` + // WIP
  `dstChainTokenOutAmount=auto&` +
  `senderAddress=${userAddress}&` +
  `dlnHook=${encodeURIComponent(JSON.stringify(hookPayload))}`;

const response = await fetch(apiUrl);
const order = await response.json();
```

### 3. Execute Transaction

Submit the transaction returned by deBridge API to initiate cross-chain royalty payment.

## 🌐 Supported Networks

### Source Chains (Pay from)
- Ethereum mainnet
- Polygon
- BNB Chain  
- Arbitrum
- Optimism
- Avalanche
- [View all supported chains](https://docs.debridge.finance/the-core-protocol/fees#supported-chains)

### Destination Chain
- **Story Protocol mainnet** (Chain ID: 100000013)

## 🎯 Use Cases

### For Content Creators
- **Global royalty collection**: Accept payments from any blockchain
- **Simplified UX**: Users pay with familiar tokens (ETH, USDC, etc.)
- **Automatic conversion**: No manual token swapping required

### For dApps & Platforms
- **Enhanced accessibility**: Support users across all major chains
- **Reduced friction**: One integration supports multi-chain payments
- **Better retention**: Users don't need Story mainnet setup

### For Story Protocol Ecosystem
- **Increased adoption**: Lower barriers to IP asset monetization
- **Network effects**: More payment volume from diverse sources
- **Developer experience**: Simple, documented integration pattern

## 📚 Resources

- **Story Protocol Docs**: https://docs.storyprotocol.xyz/
- **deBridge DLN Docs**: https://docs.debridge.finance/
- **Test Implementation**: [`test/6_DebridgeHook.t.sol`](./test/6_DebridgeHook.t.sol)
- **API Reference**: https://dln.debridge.finance/

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Test your changes (`forge test`)
4. Commit your changes (`git commit -m 'feat: add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Story Protocol Team** for the robust IP infrastructure
- **deBridge Team** for the elegant cross-chain solution and technical guidance
- **Foundry** for the excellent testing framework

---

**Ready to integrate?** Check out our [test implementation](./test/6_DebridgeHook.t.sol) for a complete working example! 