# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Stream V2 is a DeFi yield vault protocol that wraps underlying tokens and allows users to stake them to earn yield. The protocol consists of two main contracts (StreamVault and StableWrapper) that work together and implements LayerZero V2's OFT (Omnichain Fungible Token) standard for cross-chain bridging.

## Development Commands

### Foundry (Primary)
```bash
# Build contracts
forge build

# Run all tests
forge test

# Run specific test file
forge test --match-path test/StreamVault/Stake.t.sol

# Run specific test function
forge test --match-test testStake

# Run tests with gas reporting
forge test --gas-report

# Clean build artifacts
forge clean
```

### Hardhat (Alternative)
```bash
# Compile contracts
npm run compile
# or
npx hardhat compile

# Run tests
npm run test
# or
npx hardhat test

# Clean artifacts
npm run clean
```

### Deployment
Deployment scripts are in `scripts/` directory and use Foundry's script system:
```bash
forge script scripts/Deploy.s.sol --rpc-url <RPC_URL> --broadcast --verify
```

## Architecture

### Core Contract Relationship

The protocol has a two-tier architecture:

1. **StableWrapper** (`src/StableWrapper.sol`) - Token wrapper contract
   - Wraps underlying assets (USDC, WETH, etc.) 1:1 into Stream wrapped tokens
   - Manages delayed withdrawals with epoch-based timing
   - Only the StreamVault (keeper) can deposit when `allowIndependence = false` (default)
   - Implements OFT for cross-chain bridging via LayerZero
   - Underlying assets are withdrawn by owner for off-chain yield farming

2. **StreamVault** (`src/StreamVault.sol`) - Staking vault contract
   - Users stake Stream wrapped tokens to receive non-rebasing share tokens
   - Share tokens represent proportional ownership of the vault
   - Implements OFT for cross-chain bridging via LayerZero
   - Operates on daily rounds where yield is distributed

**Flow**: User deposits underlying token → StableWrapper wraps it → StreamVault auto-stakes it → User receives shares → Yield distributed on round roll

### Timing and Epochs

- **Vault staking/unstaking**: Instant, but no yield earned for entry/exit rounds
- **Wrapper withdrawals**: 1 epoch (24 hour) delay after initiating withdrawal
- **Yield distribution**: Once per day via `rollToNextRound()` keeper call
- **Round mechanics**: Users stake in round N, shares minted start of round N+1, yield starts accruing in round N+2

### LayerZero Integration

Both StableWrapper and StreamVault extend `src/layerzero/OFT.sol` which implements LayerZero's OFT standard. This enables:
- Cross-chain bridging of wrapped tokens and vault shares
- Configuration via enforced options (see `scripts/SetEnforcedOptions*.s.sol`)
- Peer setup across chains (see `scripts/SetPeers*.s.sol`)

### Key State Variables

**StableWrapper**:
- `currentEpoch`: Tracks withdrawal timing
- `allowIndependence`: Controls auto-staking (false = forced auto-stake)
- `keeper`: Address of StreamVault contract
- `withdrawalReceipts`: Tracks pending withdrawals per user

**StreamVault**:
- `vaultState.round`: Current round number
- `stakeReceipts`: Tracks pending stakes (shares not yet minted)
- `roundPricePerShare`: Historical price per share for each round
- `stableWrapper`: Address of the wrapper contract

### Share Math

The `src/lib/ShareMath.sol` library handles critical calculations:
- Converting asset amounts to shares based on `pricePerShare`
- Share amounts are rounded DOWN to prevent inflation attacks
- Users should avoid staking very small amounts (< 1 share after rounding)

### Test Structure

Tests are organized by contract and function:
- `test/StableWrapper/` - StableWrapper tests by function
- `test/StreamVault/` - StreamVault tests by function
- `test/StableWrapper/Base.t.sol` and `test/StreamVault/Base.t.sol` - Shared test setup

Each test file tests a specific function in isolation.

## Critical Implementation Details

### Auto-staking Mechanism
When `allowIndependence = false` (default):
- Only StreamVault can call `depositToVault()` on StableWrapper
- All deposits automatically stake into vault
- Users cannot hold unwrapped Stream tokens independently
- Withdrawals are queued automatically via `unstakeAndWithdraw()`

### Yield Distribution Flow
On `rollToNextRound(yieldAmount)`:
1. Mints shares for pending stakes from previous round
2. If `yieldAmount > 0`: Calls `stableWrapper.permissionedMint()` to mint wrapped tokens into vault
3. If `yieldAmount < 0`: Calls `stableWrapper.permissionedBurn()` to burn wrapped tokens from vault
4. Updates `pricePerShare` for the round
5. Increments round number

### Withdrawal Timing Edge Case
If a user initiates multiple withdrawals across different epochs, ALL funds only become available after the LATEST epoch completes. Example:
- Initiate 100 tokens withdrawal in epoch 1
- Initiate 50 tokens withdrawal in epoch 2
- Must wait until end of epoch 2 to withdraw all 150 tokens

### Round Entry/Exit Rules
- Stake in round N → shares minted start of round N+1 → yield starts round N+2
- Unstake in round N → no yield for round N
- Can use `instantUnstake()` if staking and unstaking in same round

## Important Files

- `src/StableWrapper.sol` - Token wrapper with delayed withdrawals
- `src/StreamVault.sol` - Yield vault with share-based accounting
- `src/lib/ShareMath.sol` - Share calculation logic
- `src/lib/Vault.sol` - Struct definitions for vault state
- `src/layerzero/OFT.sol` - LayerZero OFT implementation
- `mocks/MockERC20.sol` - Mock ERC20 token for testing

## Dependencies

- Solidity 0.8.22
- Foundry for testing and deployment
- Hardhat as alternative build system
- OpenZeppelin contracts v4.6.0 and v5.0.2 (upgradeable)
- LayerZero V2 OFT contracts (@layerzerolabs/oft-evm)
- Node.js >= 18.16.0
