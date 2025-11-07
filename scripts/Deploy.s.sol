// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {StableWrapper} from "../src/StableWrapper.sol";
import {console2} from "forge-std/console2.sol";
import {StreamVault} from "../src/StreamVault.sol";
import {Vault} from "../src/lib/Vault.sol";

/**
 * @title Deploy
 * @notice Deployment script for Stream V2 protocol on Ethereum and other chains
 * @dev Configure deployment parameters in .env file
 */
contract Deploy is Script {
    function run() public {
        // Load configuration from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Required parameters
        address assetAddress = vm.envAddress("ASSET_ADDRESS");
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT");
        uint8 decimals = uint8(vm.envUint("DECIMALS"));
        string memory assetSymbol = vm.envString("ASSET_SYMBOL");

        // Vault parameters
        uint256 vaultCap = vm.envUint("VAULT_CAP"); // in whole tokens
        uint256 minSupply = vm.envUint("MIN_SUPPLY"); // in whole tokens

        // Optional: Custom names (defaults to Stream + symbol)
        string memory wrapperName = vm.envOr("WRAPPER_NAME", string.concat("Stream ", assetSymbol));
        string memory wrapperSymbol = vm.envOr("WRAPPER_SYMBOL", string.concat("stream", assetSymbol));
        string memory vaultName = vm.envOr("VAULT_NAME", string.concat("Staked Stream ", assetSymbol));
        string memory vaultSymbol = vm.envOr("VAULT_SYMBOL", string.concat("x", assetSymbol));

        console2.log("==============================================");
        console2.log("Stream V2 Deployment");
        console2.log("==============================================");
        console2.log("Deployer:", deployer);
        console2.log("Asset:", assetAddress);
        console2.log("LayerZero Endpoint:", lzEndpoint);
        console2.log("Decimals:", decimals);
        console2.log("Vault Cap:", vaultCap, "tokens");
        console2.log("Min Supply:", minSupply, "tokens");
        console2.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy StableWrapper
        console2.log("Deploying StableWrapper...");
        StableWrapper wrapper = new StableWrapper(
            assetAddress,
            wrapperName,
            wrapperSymbol,
            decimals,
            deployer, // initial keeper (will be set to vault)
            lzEndpoint,
            deployer // delegate
        );
        console2.log("StableWrapper deployed:", address(wrapper));
        console2.log("  Name:", wrapperName);
        console2.log("  Symbol:", wrapperSymbol);
        console2.log("");

        // Deploy StreamVault
        console2.log("Deploying StreamVault...");
        Vault.VaultParams memory vaultParams = Vault.VaultParams({
            decimals: decimals,
            cap: vaultCap * 10**decimals,
            minimumSupply: minSupply * 10**decimals
        });

        StreamVault vault = new StreamVault(
            vaultName,
            vaultSymbol,
            address(wrapper),
            lzEndpoint,
            deployer, // delegate
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
        console2.log("Asset:", assetAddress);
        console2.log("StableWrapper:", address(wrapper));
        console2.log("StreamVault:", address(vault));
        console2.log("Owner:", deployer);
        console2.log("==============================================");
    }
}