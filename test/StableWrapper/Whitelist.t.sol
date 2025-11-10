// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Base.t.sol";

contract WhitelistTest is Base {
    // #############################################
    // Whitelist Management Tests
    // #############################################

    function test_SuccessfulAddToWhitelist() public {
        vm.prank(owner);
        stableWrapper.addToWhitelist(depositor1);

        assertTrue(stableWrapper.isWhitelisted(depositor1));
        assertFalse(stableWrapper.isWhitelisted(depositor2));
    }

    function test_SuccessfulRemoveFromWhitelist() public {
        vm.startPrank(owner);
        stableWrapper.addToWhitelist(depositor1);
        assertTrue(stableWrapper.isWhitelisted(depositor1));

        stableWrapper.removeFromWhitelist(depositor1);
        assertFalse(stableWrapper.isWhitelisted(depositor1));
        vm.stopPrank();
    }

    function test_SuccessfulEnableWhitelist() public {
        assertFalse(stableWrapper.whitelistEnabled());

        vm.prank(owner);
        stableWrapper.setWhitelistEnabled(true);

        assertTrue(stableWrapper.whitelistEnabled());
    }

    function test_SuccessfulDisableWhitelist() public {
        vm.startPrank(owner);
        stableWrapper.setWhitelistEnabled(true);
        assertTrue(stableWrapper.whitelistEnabled());

        stableWrapper.setWhitelistEnabled(false);
        assertFalse(stableWrapper.whitelistEnabled());
        vm.stopPrank();
    }

    function test_RevertIfNonOwnerAddsToWhitelist() public {
        vm.prank(depositor1);
        vm.expectRevert();
        stableWrapper.addToWhitelist(depositor2);
    }

    function test_RevertIfNonOwnerRemovesFromWhitelist() public {
        vm.prank(owner);
        stableWrapper.addToWhitelist(depositor1);

        vm.prank(depositor2);
        vm.expectRevert();
        stableWrapper.removeFromWhitelist(depositor1);
    }

    function test_RevertIfNonOwnerEnablesWhitelist() public {
        vm.prank(depositor1);
        vm.expectRevert();
        stableWrapper.setWhitelistEnabled(true);
    }

    // #############################################
    // Deposit Tests with Whitelist
    // #############################################

    function test_SuccessfulDepositWhenWhitelistDisabled() public {
        // Whitelist is disabled by default
        uint256 amount = 1000 * (10 ** 6);

        vm.prank(owner);
        stableWrapper.setAllowIndependence(true);

        vm.prank(depositor1);
        stableWrapper.deposit(depositor1, amount);

        assertEq(stableWrapper.balanceOf(depositor1), amount);
    }

    function test_SuccessfulDepositWhenWhitelistedAndEnabled() public {
        uint256 amount = 1000 * (10 ** 6);

        vm.startPrank(owner);
        stableWrapper.setAllowIndependence(true);
        stableWrapper.addToWhitelist(depositor1);
        stableWrapper.setWhitelistEnabled(true);
        vm.stopPrank();

        vm.prank(depositor1);
        stableWrapper.deposit(depositor1, amount);

        assertEq(stableWrapper.balanceOf(depositor1), amount);
    }

    function test_RevertIfNotWhitelistedAndEnabledForDeposit() public {
        uint256 amount = 1000 * (10 ** 6);

        vm.startPrank(owner);
        stableWrapper.setAllowIndependence(true);
        stableWrapper.setWhitelistEnabled(true);
        vm.stopPrank();

        vm.prank(depositor1);
        vm.expectRevert();
        stableWrapper.deposit(depositor1, amount);
    }

    function test_SuccessfulDepositETHWhenWhitelistedAndEnabled() public {
        uint256 amount = 1 ether;

        // Change asset to WETH for ETH deposits
        vm.startPrank(owner);
        stableWrapper.setAsset(address(stableWrapper.WETH()));
        stableWrapper.setAllowIndependence(true);
        stableWrapper.addToWhitelist(depositor1);
        stableWrapper.setWhitelistEnabled(true);
        vm.stopPrank();

        vm.prank(depositor1);
        stableWrapper.depositETH{value: amount}(depositor1);

        assertEq(stableWrapper.balanceOf(depositor1), amount);
    }

    function test_RevertIfNotWhitelistedForDepositETH() public {
        uint256 amount = 1 ether;

        vm.startPrank(owner);
        stableWrapper.setAsset(address(stableWrapper.WETH()));
        stableWrapper.setAllowIndependence(true);
        stableWrapper.setWhitelistEnabled(true);
        vm.stopPrank();

        vm.prank(depositor1);
        vm.expectRevert();
        stableWrapper.depositETH{value: amount}(depositor1);
    }

    // #############################################
    // Withdrawal Tests with Whitelist
    // #############################################

    function test_SuccessfulInitiateWithdrawalWhenWhitelisted() public {
        uint256 depositAmount = 1000 * (10 ** 6);
        uint224 withdrawAmount = 500 * (10 ** 6);

        // Setup: deposit first
        vm.startPrank(owner);
        stableWrapper.setAllowIndependence(true);
        stableWrapper.addToWhitelist(depositor1);
        stableWrapper.setWhitelistEnabled(true);
        vm.stopPrank();

        vm.prank(depositor1);
        stableWrapper.deposit(depositor1, depositAmount);

        // Initiate withdrawal
        vm.prank(depositor1);
        stableWrapper.initiateWithdrawal(withdrawAmount);

        (uint224 receiptAmount, ) = stableWrapper.withdrawalReceipts(
            depositor1
        );
        assertEq(receiptAmount, withdrawAmount);
    }

    function test_RevertIfNotWhitelistedForInitiateWithdrawal() public {
        uint256 depositAmount = 1000 * (10 ** 6);
        uint224 withdrawAmount = 500 * (10 ** 6);

        // Setup: deposit when whitelist is disabled
        vm.prank(owner);
        stableWrapper.setAllowIndependence(true);

        vm.prank(depositor1);
        stableWrapper.deposit(depositor1, depositAmount);

        // Enable whitelist without whitelisting depositor1
        vm.prank(owner);
        stableWrapper.setWhitelistEnabled(true);

        // Try to withdraw - should fail
        vm.prank(depositor1);
        vm.expectRevert();
        stableWrapper.initiateWithdrawal(withdrawAmount);
    }

    function test_SuccessfulCompleteWithdrawalWhenWhitelisted() public {
        uint256 depositAmount = 1000 * (10 ** 6);
        uint224 withdrawAmount = 500 * (10 ** 6);

        // Setup and deposit
        vm.startPrank(owner);
        stableWrapper.setAllowIndependence(true);
        stableWrapper.addToWhitelist(depositor1);
        stableWrapper.setWhitelistEnabled(true);
        vm.stopPrank();

        vm.prank(depositor1);
        stableWrapper.deposit(depositor1, depositAmount);

        // Initiate withdrawal
        vm.prank(depositor1);
        stableWrapper.initiateWithdrawal(withdrawAmount);

        // Roll epoch
        vm.prank(owner);
        stableWrapper.processWithdrawals();

        // Complete withdrawal
        vm.prank(depositor1);
        stableWrapper.completeWithdrawal(depositor1);

        assertEq(usdc.balanceOf(depositor1), startingBal - depositAmount + withdrawAmount);
    }

    function test_RevertIfNotWhitelistedForCompleteWithdrawal() public {
        uint256 depositAmount = 1000 * (10 ** 6);
        uint224 withdrawAmount = 500 * (10 ** 6);

        // Setup: deposit and initiate withdrawal when whitelist is disabled
        vm.prank(owner);
        stableWrapper.setAllowIndependence(true);

        vm.prank(depositor1);
        stableWrapper.deposit(depositor1, depositAmount);

        vm.prank(depositor1);
        stableWrapper.initiateWithdrawal(withdrawAmount);

        // Roll epoch
        vm.prank(owner);
        stableWrapper.processWithdrawals();

        // Enable whitelist without whitelisting depositor1
        vm.prank(owner);
        stableWrapper.setWhitelistEnabled(true);

        // Try to complete withdrawal - should fail
        vm.prank(depositor1);
        vm.expectRevert();
        stableWrapper.completeWithdrawal(depositor1);
    }

    // #############################################
    // Whitelist State Change Tests
    // #############################################

    function test_CanDepositAfterWhitelistDisabled() public {
        uint256 amount = 1000 * (10 ** 6);

        // Enable whitelist and whitelist depositor1
        vm.startPrank(owner);
        stableWrapper.setAllowIndependence(true);
        stableWrapper.addToWhitelist(depositor1);
        stableWrapper.setWhitelistEnabled(true);
        vm.stopPrank();

        // Depositor1 can deposit
        vm.prank(depositor1);
        stableWrapper.deposit(depositor1, amount);
        assertEq(stableWrapper.balanceOf(depositor1), amount);

        // Disable whitelist
        vm.prank(owner);
        stableWrapper.setWhitelistEnabled(false);

        // Now depositor2 (not whitelisted) can also deposit
        vm.prank(depositor2);
        stableWrapper.deposit(depositor2, amount);
        assertEq(stableWrapper.balanceOf(depositor2), amount);
    }

    function test_CannotDepositAfterRemovedFromWhitelist() public {
        uint256 amount = 1000 * (10 ** 6);

        vm.startPrank(owner);
        stableWrapper.setAllowIndependence(true);
        stableWrapper.addToWhitelist(depositor1);
        stableWrapper.setWhitelistEnabled(true);
        vm.stopPrank();

        // Depositor1 can deposit
        vm.prank(depositor1);
        stableWrapper.deposit(depositor1, amount);

        // Remove from whitelist
        vm.prank(owner);
        stableWrapper.removeFromWhitelist(depositor1);

        // Cannot deposit anymore
        vm.prank(depositor1);
        vm.expectRevert();
        stableWrapper.deposit(depositor1, amount);
    }

    function test_MultipleAddressesWhitelist() public {
        uint256 amount = 1000 * (10 ** 6);

        vm.startPrank(owner);
        stableWrapper.setAllowIndependence(true);
        stableWrapper.addToWhitelist(depositor1);
        stableWrapper.addToWhitelist(depositor2);
        stableWrapper.addToWhitelist(depositor3);
        stableWrapper.setWhitelistEnabled(true);
        vm.stopPrank();

        // All three can deposit
        vm.prank(depositor1);
        stableWrapper.deposit(depositor1, amount);

        vm.prank(depositor2);
        stableWrapper.deposit(depositor2, amount);

        vm.prank(depositor3);
        stableWrapper.deposit(depositor3, amount);

        assertEq(stableWrapper.balanceOf(depositor1), amount);
        assertEq(stableWrapper.balanceOf(depositor2), amount);
        assertEq(stableWrapper.balanceOf(depositor3), amount);

        // Depositor4 cannot deposit
        vm.prank(depositor4);
        vm.expectRevert();
        stableWrapper.deposit(depositor4, amount);
    }

    // #############################################
    // Events Tests
    // #############################################

    function test_EmitWhitelistAddedEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit WhitelistAdded(depositor1);
        stableWrapper.addToWhitelist(depositor1);
    }

    function test_EmitWhitelistRemovedEvent() public {
        vm.prank(owner);
        stableWrapper.addToWhitelist(depositor1);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit WhitelistRemoved(depositor1);
        stableWrapper.removeFromWhitelist(depositor1);
    }

    function test_EmitWhitelistStatusSetEvent() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit WhitelistStatusSet(true);
        stableWrapper.setWhitelistEnabled(true);
    }

    // Events from Whitelist contract
    event WhitelistAdded(address indexed account);
    event WhitelistRemoved(address indexed account);
    event WhitelistStatusSet(bool enabled);
}
