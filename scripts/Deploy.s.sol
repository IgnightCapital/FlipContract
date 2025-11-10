// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {StableWrapper} from "../src/StableWrapper.sol";
import {console2} from "forge-std/console2.sol";
import {StreamVault} from "../src/StreamVault.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {Vault} from "../src/lib/Vault.sol";

/**
 * @title Deploy
 * @notice Deployment script for Stream V2 protocol
 * @dev Configure deployment parameters in .env file
 * @dev Set TEST_MODE=true to deploy MockERC20 for testing
 */
contract Deploy is Script {
    function run() public {
        // Load configuration from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Check if test mode
        bool testMode = vm.envOr("TEST_MODE", false);

        // Asset configuration
        address assetAddress;
        uint8 decimals;
        string memory assetSymbol;

        if (testMode) {
            // Test mode: MockERC20 will be deployed
            console2.log("==============================================");
            console2.log("TEST MODE ENABLED");
            console2.log("==============================================");
            decimals = uint8(vm.envOr("DECIMALS", uint256(6)));
            assetSymbol = vm.envOr("ASSET_SYMBOL", string("USD"));
            assetAddress = address(0); // Will be set after MockERC20 deployment
        } else {
            // Production mode: Use existing asset
            assetAddress = vm.envAddress("ASSET_ADDRESS");
            decimals = uint8(vm.envUint("DECIMALS"));
            assetSymbol = vm.envString("ASSET_SYMBOL");
        }

        // Vault parameters
        uint256 vaultCap = vm.envUint("VAULT_CAP"); // in whole tokens
        uint256 minSupply = vm.envUint("MIN_SUPPLY"); // in whole tokens

        // Optional: Custom names (defaults to Stream + symbol)
        string memory wrapperName = vm.envOr("WRAPPER_NAME", string.concat("Stream ", assetSymbol));
        string memory wrapperSymbol = vm.envOr("WRAPPER_SYMBOL", string.concat("stream", assetSymbol));
        string memory vaultName = vm.envOr("VAULT_NAME", string.concat("Staked Stream ", assetSymbol));
        string memory vaultSymbol = vm.envOr("VAULT_SYMBOL", string.concat("x", assetSymbol));

        if (!testMode) {
            console2.log("==============================================");
            console2.log("Stream V2 Deployment - PRODUCTION");
            console2.log("==============================================");
        }
        console2.log("Deployer:", deployer);
        console2.log("Mode:", testMode ? "TEST (MockERC20)" : "PRODUCTION");
        if (!testMode) {
            console2.log("Asset:", assetAddress);
        }
        console2.log("Decimals:", decimals);
        console2.log("Asset Symbol:", assetSymbol);
        console2.log("Vault Cap:", vaultCap, "tokens");
        console2.log("Min Supply:", minSupply, "tokens");
        console2.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockERC20 if in test mode
        if (testMode) {
            console2.log("Deploying MockERC20 for testing...");
            string memory mockName = vm.envOr("ASSET_NAME", string.concat("Test ", assetSymbol));
            MockERC20 mockToken = new MockERC20(
                mockName,
                string.concat("t", assetSymbol),
                decimals
            );
            assetAddress = address(mockToken);

            // Mint tokens to deployer
            uint256 mintAmount = vm.envOr("MOCK_MINT_AMOUNT", uint256(10000000)) * 10**decimals;
            mockToken.mint(deployer, mintAmount);

            console2.log("MockERC20 deployed:", assetAddress);
            console2.log("  Name:", mockName);
            console2.log("  Symbol:", string.concat("t", assetSymbol));
            console2.log("  Minted", vm.envOr("MOCK_MINT_AMOUNT", uint256(10000000)), "tokens to deployer");
            console2.log("");
        }

        // Deploy StableWrapper
        console2.log("Deploying StableWrapper...");
        StableWrapper wrapper = new StableWrapper(
            assetAddress,
            wrapperName,
            wrapperSymbol,
            decimals,
            deployer // initial keeper (will be set to vault)
        );
        console2.log("StableWrapper deployed:", address(wrapper));
        console2.log("  Name:", wrapperName);
        console2.log("  Symbol:", wrapperSymbol);
        console2.log("");

        // Deploy StreamVault
        console2.log("Deploying StreamVault...");
        Vault.VaultParams memory vaultParams = Vault.VaultParams({
            decimals: decimals,
            cap: uint104(vaultCap * 10**decimals),
            minimumSupply: uint56(minSupply * 10**decimals)
        });

        StreamVault vault = new StreamVault(
            vaultName,
            vaultSymbol,
            address(wrapper),
            vaultParams
        );
        console2.log("StreamVault deployed:", address(vault));
        console2.log("  Name:", vaultName);
        console2.log("  Symbol:", vaultSymbol);
        console2.log("");

        // Set vault as keeper
        console2.log("Setting StreamVault as keeper...");
        wrapper.setKeeper(address(vault));
        console2.log("Done");
        console2.log("");

        vm.stopBroadcast();

        // Summary
        console2.log("==============================================");
        console2.log("Deployment Complete");
        console2.log("==============================================");
        console2.log("Mode:", testMode ? "TEST" : "PRODUCTION");
        console2.log("Asset:", assetAddress);
        console2.log("StableWrapper:", address(wrapper));
        console2.log("StreamVault:", address(vault));
        console2.log("Owner:", deployer);
        console2.log("==============================================");

        if (testMode) {
            console2.log("");
            console2.log("Test Mode - Next Steps:");
            console2.log("1. Check token balance");
            console2.log("2. Approve and deposit tokens");
            console2.log("3. Test the vault functions");
        }
    }
}