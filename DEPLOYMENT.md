# Stream V2 Deployment Guide

This guide explains how to deploy the Stream V2 protocol (StableWrapper and StreamVault) to Ethereum or other EVM-compatible chains.

## Prerequisites

1. **Foundry** installed ([installation guide](https://book.getfoundry.sh/getting-started/installation))
2. **Private key** with sufficient ETH for deployment
3. **RPC URL** for the target network
4. **Etherscan API key** for contract verification (optional but recommended)

## Step 1: Setup Environment

1. Copy the example environment file:
```bash
cp .env.example .env
```

2. Edit `.env` and configure the required parameters:

### Required Parameters

- `PRIVATE_KEY`: Your deployer wallet private key (without 0x prefix)
- `ASSET_ADDRESS`: Address of the underlying token (USDC, WETH, WBTC, etc.)
- `DECIMALS`: Token decimals (6 for USDC, 18 for WETH, 8 for WBTC)
- `ASSET_SYMBOL`: Symbol for naming (e.g., "USD", "ETH", "BTC")
- `LZ_ENDPOINT`: LayerZero V2 endpoint for your chain
- `VAULT_CAP`: Maximum vault capacity in whole tokens
- `MIN_SUPPLY`: Minimum initial deposit in whole tokens

### Example Configuration (Ethereum USDC)

```bash
PRIVATE_KEY=your_private_key_here
ASSET_ADDRESS=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
DECIMALS=6
ASSET_SYMBOL=USD
LZ_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c
VAULT_CAP=10000000
MIN_SUPPLY=1000
ETHEREUM_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR-API-KEY
ETHERSCAN_API_KEY=your_etherscan_api_key
```

## Step 2: Verify Configuration

Before deploying, verify your configuration:

```bash
# Check your deployer address
cast wallet address --private-key $PRIVATE_KEY

# Check deployer balance
cast balance $(cast wallet address --private-key $PRIVATE_KEY) --rpc-url $ETHEREUM_RPC_URL

# Verify asset token exists
cast call $ASSET_ADDRESS "symbol()(string)" --rpc-url $ETHEREUM_RPC_URL
cast call $ASSET_ADDRESS "decimals()(uint8)" --rpc-url $ETHEREUM_RPC_URL
```

## Step 3: Deploy Contracts

### Dry Run (Simulation)

Test the deployment without broadcasting transactions:

```bash
forge script scripts/Deploy.s.sol --rpc-url $ETHEREUM_RPC_URL
```

### Deploy to Network

Deploy and broadcast transactions:

```bash
forge script scripts/Deploy.s.sol \
  --rpc-url $ETHEREUM_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

**Note:** Remove `--verify` if you want to verify contracts manually later.

### Save Deployment Addresses

The deployment script will output:
```
==============================================
Deployment Complete
==============================================
Asset: 0x...
StableWrapper: 0x...
StreamVault: 0x...
Owner: 0x...
==============================================
```

Save these addresses for future reference!

## Step 4: Verify Contracts (if not done during deployment)

If you didn't use `--verify` during deployment:

```bash
# Verify StableWrapper
forge verify-contract \
  <WRAPPER_ADDRESS> \
  src/StableWrapper.sol:StableWrapper \
  --constructor-args $(cast abi-encode "constructor(address,string,string,uint8,address,address,address)" $ASSET_ADDRESS "Stream USD" "streamUSD" 6 $KEEPER_ADDRESS $LZ_ENDPOINT $DELEGATE_ADDRESS) \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --chain-id 1

# Verify StreamVault
forge verify-contract \
  <VAULT_ADDRESS> \
  src/StreamVault.sol:StreamVault \
  --constructor-args $(cast abi-encode "constructor(string,string,address,address,address,(uint8,uint256,uint256))" "Staked Stream USD" "xUSD" $WRAPPER_ADDRESS $LZ_ENDPOINT $DELEGATE_ADDRESS "(6,10000000000000,1000000000)") \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --chain-id 1
```

## Step 5: Post-Deployment Configuration

### Configure LayerZero (for cross-chain)

If deploying on multiple chains, configure LayerZero peers:

```bash
# Example: Set Arbitrum as peer for Ethereum deployment
forge script scripts/SetPeersArbitrum.s.sol \
  --rpc-url $ETHEREUM_RPC_URL \
  --broadcast
```

See LayerZero documentation for complete setup.

## Common Deployment Scenarios

### Ethereum Mainnet - USDC Vault

```bash
# .env configuration
ASSET_ADDRESS=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
DECIMALS=6
ASSET_SYMBOL=USD
LZ_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c
VAULT_CAP=10000000
MIN_SUPPLY=1000

# Deploy
forge script scripts/Deploy.s.sol --rpc-url $ETHEREUM_RPC_URL --broadcast --verify
```

### Arbitrum - USDC Vault

```bash
# .env configuration
ASSET_ADDRESS=0xaf88d065e77c8cC2239327C5EDb3A432268e5831
DECIMALS=6
ASSET_SYMBOL=USD
LZ_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c
VAULT_CAP=10000000
MIN_SUPPLY=1000

# Deploy
forge script scripts/Deploy.s.sol --rpc-url $ARBITRUM_RPC_URL --broadcast --verify
```

### Ethereum Mainnet - WBTC Vault

```bash
# .env configuration
ASSET_ADDRESS=0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599
DECIMALS=8
ASSET_SYMBOL=BTC
LZ_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c
VAULT_CAP=1000
MIN_SUPPLY=0.1

# Deploy
forge script scripts/Deploy.s.sol --rpc-url $ETHEREUM_RPC_URL --broadcast --verify
```

## Testing Deployment

After deployment, test the basic flow:

```bash
# 1. Approve StableWrapper to spend your tokens
cast send $ASSET_ADDRESS "approve(address,uint256)" $WRAPPER_ADDRESS 1000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $ETHEREUM_RPC_URL

# 2. Deposit and stake via StreamVault
cast send $VAULT_ADDRESS "depositAndStake(address,uint256)" $YOUR_ADDRESS 1000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $ETHEREUM_RPC_URL

# 3. Check your stake receipt
cast call $VAULT_ADDRESS "stakeReceipts(address)(uint16,uint104,uint128)" $YOUR_ADDRESS \
  --rpc-url $ETHEREUM_RPC_URL
```

## LayerZero Endpoint Addresses

| Network | Chain ID | LayerZero Endpoint |
|---------|----------|-------------------|
| Ethereum | 1 | `0x1a44076050125825900e736c501f859c50fE728c` |
| Arbitrum | 42161 | `0x1a44076050125825900e736c501f859c50fE728c` |
| Optimism | 10 | `0x1a44076050125825900e736c501f859c50fE728c` |
| Base | 8453 | `0x1a44076050125825900e736c501f859c50fE728c` |
| Polygon | 137 | `0x1a44076050125825900e736c501f859c50fE728c` |

## Troubleshooting

### "Gas estimation failed"
- Ensure you have enough ETH for gas
- Check that the asset address is correct
- Verify LayerZero endpoint is correct for your chain

### "Verification failed"
- Make sure to use the exact constructor arguments
- Wait a few minutes after deployment before verifying
- Try manual verification on Etherscan

### "Transaction reverted"
- Check that all addresses in .env are correct
- Ensure asset token exists at the specified address
- Verify decimals match the actual token decimals

## Security Checklist

Before production deployment:

- [ ] Audit all smart contracts
- [ ] Test deployment on testnet first
- [ ] Verify all contract addresses
- [ ] Set up monitoring and alerts
- [ ] Document emergency procedures
- [ ] Test withdrawal flow
- [ ] Configure LayerZero properly
- [ ] Set appropriate vault caps and limits
- [ ] Verify owner/keeper addresses

## Support

For issues or questions:
- Check the [main README](./README.md)
- Review [CLAUDE.md](./CLAUDE.md) for development guidance
- Open an issue on GitHub
