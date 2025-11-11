// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {StableWrapper} from "../src/StableWrapper.sol";
import {StreamVault} from "../src/StreamVault.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

/**
 * @title TestWhitelistRestriction
 * @notice Test script to verify whitelist restriction works correctly
 * @dev This script:
 *      1. Creates a new random wallet
 *      2. Transfers test tokens from owner to new wallet
 *      3. Attempts depositAndStake with non-whitelisted wallet (should fail)
 *      4. Adds wallet to whitelist
 *      5. Attempts depositAndStake again (should succeed)
 *
 * Usage:
 * forge script scripts/TestWhitelistRestriction.s.sol --rpc-url $RPC_URL --broadcast -vvv
 */
contract TestWhitelistRestriction is Script {
    function run() public {
        // Load configuration
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(ownerPrivateKey);

        address assetAddress = vm.envAddress("ASSET_ADDRESS");
        address payable wrapperAddress = payable(vm.envAddress("WRAPPER_ADDRESS"));
        address payable vaultAddress = payable(vm.envAddress("VAULT_ADDRESS"));
        uint256 depositAmount = vm.envUint("DEPOSIT_AMOUNT");

        MockERC20 asset = MockERC20(assetAddress);
        StableWrapper wrapper = StableWrapper(wrapperAddress);
        StreamVault vault = StreamVault(vaultAddress);

        uint8 decimals = asset.decimals();
        uint256 amount = depositAmount * 10**decimals;

        // Generate a random new wallet
        uint256 newWalletPrivateKey = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, owner)));
        address newWallet = vm.addr(newWalletPrivateKey);

        console2.log("==============================================");
        console2.log("Test: Whitelist Restriction");
        console2.log("==============================================");
        console2.log("Owner:", owner);
        console2.log("New Wallet (non-whitelisted):", newWallet);
        console2.log("Asset:", assetAddress);
        console2.log("Wrapper:", wrapperAddress);
        console2.log("Vault:", vaultAddress);
        console2.log("Test Amount:", depositAmount, "tokens");
        console2.log("");

        // Step 1: Transfer tokens from owner to new wallet
        console2.log("--- Step 1: Transfer tokens to new wallet ---");
        uint256 ownerBalance = asset.balanceOf(owner);
        console2.log("Owner balance:", ownerBalance / 10**decimals, "tokens");

        vm.startBroadcast(ownerPrivateKey);
        asset.transfer(newWallet, amount);
        vm.stopBroadcast();

        uint256 newWalletBalance = asset.balanceOf(newWallet);
        console2.log("New wallet balance after transfer:", newWalletBalance / 10**decimals, "tokens");
        console2.log("");

        // Step 2: Check whitelist status
        console2.log("--- Step 2: Check whitelist status ---");
        bool isWhitelisted = vault.isWhitelisted(newWallet);
        bool isWhitelistEnabled = vault.whitelistEnabled();
        console2.log("Whitelist enabled:", isWhitelistEnabled);
        console2.log("New wallet whitelisted:", isWhitelisted);
        console2.log("");

        // Step 3: Attempt depositAndStake without whitelist (should fail)
        console2.log("--- Step 3: Attempt depositAndStake without whitelist ---");
        console2.log("This should FAIL with 'NotWhitelisted' error");
        console2.log("");

        vm.startBroadcast(newWalletPrivateKey);

        // Approve wrapper
        asset.approve(wrapperAddress, amount);
        console2.log("Approved", amount / 10**decimals, "tokens to wrapper");

        // Try to depositAndStake (should revert)
        try vault.depositAndStake(uint104(amount), newWallet) {
            console2.log("ERROR: depositAndStake succeeded when it should have failed!");
            console2.log("Whitelist is not working correctly!");
            vm.stopBroadcast();
            revert("Test failed: whitelist not enforced");
        } catch Error(string memory reason) {
            console2.log("SUCCESS: depositAndStake failed as expected");
            console2.log("Revert reason:", reason);
        } catch (bytes memory lowLevelData) {
            console2.log("SUCCESS: depositAndStake failed as expected");
            console2.log("Reverted with custom error (NotWhitelisted)");
            console2.logBytes(lowLevelData);
        }

        vm.stopBroadcast();
        console2.log("");

        // Step 4: Add wallet to whitelist
        console2.log("--- Step 4: Add wallet to whitelist ---");
        vm.startBroadcast(ownerPrivateKey);
        vault.addToWhitelist(newWallet);
        console2.log("Added", newWallet, "to whitelist");
        vm.stopBroadcast();

        bool isWhitelistedNow = vault.isWhitelisted(newWallet);
        console2.log("New wallet whitelisted now:", isWhitelistedNow);
        console2.log("");

        // Step 5: Attempt depositAndStake with whitelist (should succeed)
        console2.log("--- Step 5: Attempt depositAndStake with whitelist ---");
        console2.log("This should SUCCEED");
        console2.log("");

        vm.startBroadcast(newWalletPrivateKey);

        // Approve wrapper again (previous approval was consumed or needs refresh)
        uint256 currentAllowance = asset.allowance(newWallet, wrapperAddress);
        if (currentAllowance < amount) {
            asset.approve(wrapperAddress, amount);
            console2.log("Re-approved", amount / 10**decimals, "tokens to wrapper");
        }

        // Try to depositAndStake (should succeed now)
        vault.depositAndStake(uint104(amount), newWallet);
        console2.log("SUCCESS: depositAndStake succeeded!");

        vm.stopBroadcast();

        // Step 6: Verify final state
        console2.log("");
        console2.log("--- Step 6: Verify final state ---");
        uint256 finalWalletBalance = asset.balanceOf(newWallet);
        uint256 vaultWrapperBalance = wrapper.balanceOf(vaultAddress);
        (uint16 receiptRound, uint104 stakeAmount, uint128 unredeemedShares) = vault.stakeReceipts(newWallet);

        console2.log("New wallet asset balance:", finalWalletBalance / 10**decimals, "tokens");
        console2.log("Vault wrapper balance:", vaultWrapperBalance / 10**decimals, "tokens");
        console2.log("Pending stake amount:", stakeAmount / 10**decimals, "tokens");
        console2.log("Receipt round:", receiptRound);
        console2.log("");

        // Summary
        console2.log("==============================================");
        console2.log("Test Complete!");
        console2.log("==============================================");
        console2.log("Result: Whitelist restriction is working correctly");
        console2.log("- Non-whitelisted wallet was blocked");
        console2.log("- Whitelisted wallet was allowed");
        console2.log("==============================================");
    }
}
