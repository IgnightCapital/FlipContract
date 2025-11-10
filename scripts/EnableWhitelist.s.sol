// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {StreamVault} from "../src/StreamVault.sol";

/**
 * @title EnableWhitelist
 * @notice Script to enable whitelist on StreamVault
 *
 * Usage:
 * forge script scripts/EnableWhitelist.s.sol --rpc-url $RPC_URL --broadcast
 */
contract EnableWhitelist is Script {
    function run() public {
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");
        address payable vaultAddress = payable(vm.envAddress("VAULT_ADDRESS"));

        StreamVault vault = StreamVault(vaultAddress);

        console2.log("==============================================");
        console2.log("Enable Whitelist");
        console2.log("==============================================");
        console2.log("Vault:", vaultAddress);

        bool currentStatus = vault.whitelistEnabled();
        console2.log("Current whitelist status:", currentStatus);

        vm.startBroadcast(ownerPrivateKey);
        vault.setWhitelistEnabled(true);
        vm.stopBroadcast();

        bool newStatus = vault.whitelistEnabled();
        console2.log("New whitelist status:", newStatus);
        console2.log("==============================================");
    }
}
