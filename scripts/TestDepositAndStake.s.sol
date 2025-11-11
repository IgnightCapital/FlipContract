// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {StableWrapper} from "../src/StableWrapper.sol";
import {StreamVault} from "../src/StreamVault.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TestDepositAndStake
 * @notice Test script for depositAndStake functionality
 * @dev This script tests the full flow: approve -> depositAndStake -> check balances
 *
 * Usage:
 * forge script scripts/TestDepositAndStake.s.sol --rpc-url $RPC_URL --broadcast -vvv
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer/user private key
 * - ASSET_ADDRESS: Address of the underlying token (MockERC20 in test mode)
 * - WRAPPER_ADDRESS: Address of StableWrapper contract
 * - VAULT_ADDRESS: Address of StreamVault contract
 * - DEPOSIT_AMOUNT: Amount to deposit (in whole tokens, e.g., 1000 for 1000 USDC)
 */
contract TestDepositAndStake is Script {
    function run() public {
        // Load configuration
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(userPrivateKey);

        address assetAddress = vm.envAddress("ASSET_ADDRESS");
        address payable wrapperAddress = payable(vm.envAddress("WRAPPER_ADDRESS"));
        address payable vaultAddress = payable(vm.envAddress("VAULT_ADDRESS"));
        uint256 depositAmount = vm.envUint("DEPOSIT_AMOUNT");

        MockERC20 asset = MockERC20(assetAddress);
        StableWrapper wrapper = StableWrapper(wrapperAddress);
        StreamVault vault = StreamVault(vaultAddress);

        uint8 decimals = asset.decimals();
        uint256 amount = depositAmount * 10**decimals;

        console2.log("==============================================");
        console2.log("Test: depositAndStake");
        console2.log("==============================================");
        console2.log("User:", user);
        console2.log("Asset:", assetAddress);
        console2.log("Wrapper:", wrapperAddress);
        console2.log("Vault:", vaultAddress);
        console2.log("Deposit Amount:", depositAmount, "tokens");
        console2.log("");

        // Check initial balances
        console2.log("--- Initial Balances ---");
        uint256 userAssetBalance = asset.balanceOf(user);
        uint256 userWrapperBalance = wrapper.balanceOf(user);
        uint256 userVaultShares = vault.balanceOf(user);
        console2.log("User asset balance:", userAssetBalance / 10**decimals, "tokens");
        console2.log("User wrapper balance:", userWrapperBalance / 10**decimals, "tokens");
        console2.log("User vault shares:", userVaultShares / 10**decimals, "shares");
        console2.log("");

        if (userAssetBalance < amount) {
            console2.log("ERROR: Insufficient asset balance");
            console2.log("Required:", amount / 10**decimals, "tokens");
            console2.log("Available:", userAssetBalance / 10**decimals, "tokens");
            revert("Insufficient balance");
        }

        // Check if user is whitelisted
        bool isWhitelisted = vault.isWhitelisted(user);
        console2.log("User whitelisted:", isWhitelisted);
        if (!isWhitelisted) {
            console2.log("WARNING: User is not whitelisted. Adding to whitelist...");
        }
        console2.log("");

        vm.startBroadcast(userPrivateKey);

        // Add to whitelist if needed (only owner can do this, so this will fail if user is not owner)
        if (!isWhitelisted) {
            try vault.addToWhitelist(user) {
                console2.log("User added to whitelist");
            } catch {
                console2.log("ERROR: Failed to add user to whitelist (not owner)");
                console2.log("Please ask the vault owner to whitelist your address");
                vm.stopBroadcast();
                revert("User not whitelisted");
            }
        }

        // Step 1: Approve wrapper to spend user's assets
        // Note: depositAndStake calls wrapper.depositToVault which transfers assets from user to wrapper
        console2.log("--- Step 1: Approving Wrapper ---");
        uint256 currentAllowance = asset.allowance(user, wrapperAddress);
        console2.log("Current allowance to wrapper:", currentAllowance / 10**decimals, "tokens");

        if (currentAllowance < amount) {
            console2.log("Approving", amount / 10**decimals, "tokens to wrapper...");
            asset.approve(wrapperAddress, amount);
            console2.log("Approval successful");
        } else {
            console2.log("Sufficient allowance already exists");
        }
        console2.log("");

        // Step 2: DepositAndStake
        console2.log("--- Step 2: Deposit and Stake ---");
        console2.log("Calling depositAndStake with amount:", amount / 10**decimals, "tokens");
        console2.log("Creditor:", user);

        vault.depositAndStake(uint104(amount), user);
        console2.log("depositAndStake successful!");
        console2.log("");

        vm.stopBroadcast();

        // Check final balances
        console2.log("--- Final Balances ---");
        uint256 finalUserAssetBalance = asset.balanceOf(user);
        uint256 finalUserWrapperBalance = wrapper.balanceOf(user);
        uint256 finalUserVaultShares = vault.balanceOf(user);
        uint256 vaultWrapperBalance = wrapper.balanceOf(vaultAddress);

        console2.log("User asset balance:", finalUserAssetBalance / 10**decimals, "tokens");
        console2.log("User wrapper balance:", finalUserWrapperBalance / 10**decimals, "tokens");
        console2.log("User vault shares:", finalUserVaultShares / 10**decimals, "shares");
        console2.log("Vault wrapper balance:", vaultWrapperBalance / 10**decimals, "tokens");
        console2.log("");

        // Show stake receipt info
        console2.log("--- Stake Receipt Info ---");
        (uint16 receiptRound, uint104 stakeAmount, uint128 unredeemedShares) = vault.stakeReceipts(user);
        (uint16 currentRound, uint128 totalPending) = vault.vaultState();
        console2.log("Current round:", currentRound);
        console2.log("Receipt round:", receiptRound);
        console2.log("Pending stake amount:", stakeAmount / 10**decimals, "tokens");
        console2.log("Unredeemed shares:", unredeemedShares / 10**decimals, "shares");
        console2.log("Total pending:", totalPending / 10**decimals, "tokens");
        console2.log("");

        // Summary
        console2.log("==============================================");
        console2.log("Test Complete!");
        console2.log("==============================================");
        console2.log("Assets transferred:", (userAssetBalance - finalUserAssetBalance) / 10**decimals, "tokens");
        console2.log("Wrapper tokens in vault:", vaultWrapperBalance / 10**decimals, "tokens");
        console2.log("Pending stake:", stakeAmount / 10**decimals, "tokens");
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Wait for owner to call rollToNextRound()");
        console2.log("2. Your shares will be minted in the next round");
        console2.log("3. You will start earning yield in the round after that");
        console2.log("==============================================");
    }
}
