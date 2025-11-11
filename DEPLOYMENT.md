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
- `TEST_MODE`: Set to `true` for test deployment with MockERC20, `false` for production
- `DECIMALS`: Token decimals (6 for USDC, 18 for WETH, 8 for WBTC)
- `ASSET_SYMBOL`: Symbol for naming (e.g., "USD", "ETH", "BTC")
- `VAULT_CAP`: Maximum vault capacity in whole tokens
- `MIN_SUPPLY`: Minimum initial deposit in whole tokens

### Required Only for Production Mode (TEST_MODE=false)

- `ASSET_ADDRESS`: Address of the underlying token (USDC, WETH, WBTC, etc.)

### Example Configuration (Ethereum USDC - Production)

```bash
PRIVATE_KEY=your_private_key_here
TEST_MODE=false
ASSET_ADDRESS=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
DECIMALS=6
ASSET_SYMBOL=USD
VAULT_CAP=10000000
MIN_SUPPLY=1000
ETHEREUM_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR-API-KEY
ETHERSCAN_API_KEY=your_etherscan_api_key
```

### Example Configuration (Testnet - Test Mode)

```bash
PRIVATE_KEY=your_private_key_here
TEST_MODE=true
DECIMALS=6
ASSET_SYMBOL=USD
VAULT_CAP=1000000
MIN_SUPPLY=100
ETHEREUM_TEST_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR-API-KEY
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

### Option A: Test Mode (with MockERC20)

For testing on testnet or local network, you can use test mode to automatically deploy a MockERC20:

```bash
# In .env, set:
TEST_MODE=true
# ASSET_ADDRESS not needed (will be auto-deployed)
DECIMALS=6
ASSET_SYMBOL=USD
VAULT_CAP=1000000
MIN_SUPPLY=100
# Optional:
# MOCK_MINT_AMOUNT=10000000 # Amount of tokens to mint to deployer

# Test mode deployment to Sepolia
forge script scripts/Deploy.s.sol \
  --rpc-url $ETHEREUM_TEST_RPC_URL \
  --broadcast
```

This will:
1. Deploy MockERC20 with the specified decimals and symbol
2. Mint tokens to your deployer address (default: 10,000,000 tokens)
3. Deploy StableWrapper using the mock token
4. Deploy StreamVault and set it as keeper
5. Output all deployed contract addresses

### Option B: Production Mode (with real tokens)

For production deployment using real tokens (USDC, WETH, etc.):

```bash
# In .env, set:
TEST_MODE=false
ASSET_ADDRESS=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48  # Real USDC
DECIMALS=6
ASSET_SYMBOL=USD
VAULT_CAP=10000000
MIN_SUPPLY=1000
```

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
Mode: TEST or PRODUCTION
Asset: 0x...
StableWrapper: 0x...
StreamVault: 0x...
Owner: 0x...
==============================================
```

**Important:** Save these addresses to your `.env` file for use in test scripts:
```bash
ASSET_ADDRESS=0x...
WRAPPER_ADDRESS=0x...
VAULT_ADDRESS=0x...
```

These addresses are required for running test scripts like `TestDepositAndStake.s.sol` and `TestWhitelistRestriction.s.sol`.

## Step 4: Verify Contracts (if not done during deployment)

If you didn't use `--verify` during deployment:

```bash
# Get constructor arguments from your .env
WRAPPER_NAME="Stream USD"  # or value from WRAPPER_NAME env var
WRAPPER_SYMBOL="streamUSD"  # or value from WRAPPER_SYMBOL env var
VAULT_NAME="Staked Stream USD"  # or value from VAULT_NAME env var
VAULT_SYMBOL="xUSD"  # or value from VAULT_SYMBOL env var

# Verify StableWrapper
forge verify-contract \
  $WRAPPER_ADDRESS \
  src/StableWrapper.sol:StableWrapper \
  --constructor-args $(cast abi-encode "constructor(address,string,string,uint8,address)" $ASSET_ADDRESS "$WRAPPER_NAME" "$WRAPPER_SYMBOL" $DECIMALS $DEPLOYER_ADDRESS) \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --chain-id 1

# Verify StreamVault
# Note: VaultParams is (uint8 decimals, uint104 cap, uint56 minimumSupply)
forge verify-contract \
  $VAULT_ADDRESS \
  src/StreamVault.sol:StreamVault \
  --constructor-args $(cast abi-encode "constructor(string,string,address,(uint8,uint104,uint56))" "$VAULT_NAME" "$VAULT_SYMBOL" $WRAPPER_ADDRESS "($DECIMALS,$CAP_IN_WEI,$MIN_SUPPLY_IN_WEI)") \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --chain-id 1
```

**Note:** Make sure to replace `$CAP_IN_WEI` and `$MIN_SUPPLY_IN_WEI` with the actual values in wei (VAULT_CAP * 10^DECIMALS and MIN_SUPPLY * 10^DECIMALS).

## Step 4: Post-Deployment Testing

After deployment, you can test the basic functionality using the provided test scripts.

## Common Deployment Scenarios

### Ethereum Mainnet - USDC Vault

```bash
# .env configuration
TEST_MODE=false
ASSET_ADDRESS=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
DECIMALS=6
ASSET_SYMBOL=USD
VAULT_CAP=10000000
MIN_SUPPLY=1000

# Deploy
forge script scripts/Deploy.s.sol --rpc-url $ETHEREUM_RPC_URL --broadcast --verify
```

### Arbitrum - USDC Vault

```bash
# .env configuration
TEST_MODE=false
ASSET_ADDRESS=0xaf88d065e77c8cC2239327C5EDb3A432268e5831
DECIMALS=6
ASSET_SYMBOL=USD
VAULT_CAP=10000000
MIN_SUPPLY=1000

# Deploy
forge script scripts/Deploy.s.sol --rpc-url $ARBITRUM_RPC_URL --broadcast --verify
```

### Ethereum Mainnet - WBTC Vault

```bash
# .env configuration
TEST_MODE=false
ASSET_ADDRESS=0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599
DECIMALS=8
ASSET_SYMBOL=BTC
VAULT_CAP=1000
MIN_SUPPLY=0.1

# Deploy
forge script scripts/Deploy.s.sol --rpc-url $ETHEREUM_RPC_URL --broadcast --verify
```

## Testing Deployment

After deployment, you have two options for testing:

### Option 1: Using Test Scripts (Recommended)

The project includes ready-to-use test scripts:

#### Test 1: Basic Deposit and Stake

```bash
# Make sure your .env has the deployed addresses:
# ASSET_ADDRESS=0x...
# WRAPPER_ADDRESS=0x...
# VAULT_ADDRESS=0x...
# DEPOSIT_AMOUNT=1000

forge script scripts/TestDepositAndStake.s.sol \
  --rpc-url $ETHEREUM_TEST_RPC_URL \
  --broadcast \
  -vvv
```

This script will:
1. Check balances
2. Approve wrapper to spend tokens
3. Call depositAndStake
4. Show stake receipt and final balances

#### Test 2: Whitelist Restriction

```bash
forge script scripts/TestWhitelistRestriction.s.sol \
  --rpc-url $ETHEREUM_TEST_RPC_URL \
  --broadcast \
  -vvv
```

This script will:
1. Create a new random wallet
2. Transfer tokens to it
3. Attempt depositAndStake without whitelist (should fail)
4. Add wallet to whitelist
5. Attempt depositAndStake again (should succeed)

### Option 2: Manual Testing with Cast

If you prefer manual testing:

```bash
# 1. Add your address to whitelist (owner only)
cast send $VAULT_ADDRESS "addToWhitelist(address)" $YOUR_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $ETHEREUM_RPC_URL

# 2. Approve wrapper to spend your tokens
cast send $ASSET_ADDRESS "approve(address,uint256)" $WRAPPER_ADDRESS 1000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $ETHEREUM_RPC_URL

# 3. Deposit and stake via StreamVault
cast send $VAULT_ADDRESS "depositAndStake(uint104,address)" 1000000000 $YOUR_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $ETHEREUM_RPC_URL

# 4. Check your stake receipt
cast call $VAULT_ADDRESS "stakeReceipts(address)(uint16,uint104,uint128)" $YOUR_ADDRESS \
  --rpc-url $ETHEREUM_RPC_URL

# 5. Check vault state
cast call $VAULT_ADDRESS "vaultState()(uint16,uint128)" \
  --rpc-url $ETHEREUM_RPC_URL
```

## Troubleshooting

### "Gas estimation failed"
- Ensure you have enough ETH for gas
- Check that the asset address is correct
- If in production mode, verify the asset token exists at ASSET_ADDRESS

### "Verification failed"
- Make sure to use the exact constructor arguments
- Wait a few minutes after deployment before verifying
- Try manual verification on Etherscan
- Double-check the constructor argument encoding (especially VaultParams struct)

### "Transaction reverted" during deployment
- Check that all addresses in .env are correct
- Ensure asset token exists at the specified address (for production mode)
- Verify decimals match the actual token decimals
- Make sure VAULT_CAP and MIN_SUPPLY are reasonable values

### "NotWhitelisted" error during testing
- The vault has whitelist restrictions enabled by default
- Add your address to the whitelist first:
  ```bash
  cast send $VAULT_ADDRESS "addToWhitelist(address)" $YOUR_ADDRESS --private-key $PRIVATE_KEY --rpc-url $RPC_URL
  ```
- Or use the TestWhitelistRestriction.s.sol script to test this functionality

### "Insufficient balance" during test scripts
- In test mode, make sure MockERC20 minted enough tokens to your address
- Check balance: `cast call $ASSET_ADDRESS "balanceOf(address)(uint256)" $YOUR_ADDRESS --rpc-url $RPC_URL`
- For production mode, ensure you have the underlying tokens in your wallet

## Security Checklist

Before production deployment:

- [ ] Audit all smart contracts
- [ ] Test deployment on testnet first (use TEST_MODE=true)
- [ ] Run all test scripts successfully on testnet
- [ ] Verify all contract addresses on block explorer
- [ ] Test the full flow: deposit → stake → roll round → unstake → withdraw
- [ ] Set appropriate vault caps and limits (VAULT_CAP, MIN_SUPPLY)
- [ ] Verify owner/keeper addresses are correct
- [ ] Set up whitelist for authorized users
- [ ] Test whitelist restrictions work correctly
- [ ] Set up monitoring and alerts for contract events
- [ ] Document emergency procedures and owner responsibilities
- [ ] Ensure private keys are securely stored (never commit to git)

## Support

For issues or questions:
- Check the [main README](./README.md)
- Review [CLAUDE.md](./CLAUDE.md) for development guidance
- Open an issue on GitHub
