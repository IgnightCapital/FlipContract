// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Whitelist
 * @notice Base contract providing whitelist functionality
 * @dev Can be inherited by contracts that need whitelist access control
 * @dev Requires the inheriting contract to have onlyOwner modifier (e.g., via Ownable)
 */
abstract contract Whitelist {
    // #############################################
    // STATE
    // #############################################

    /// @notice Mapping to track whitelisted addresses
    mapping(address => bool) public whitelist;

    /// @notice Whether whitelist is enabled
    bool public whitelistEnabled;

    // #############################################
    // EVENTS
    // #############################################

    event WhitelistAdded(address indexed account);

    event WhitelistRemoved(address indexed account);

    event WhitelistStatusSet(bool enabled);

    // #############################################
    // ERRORS
    // #############################################

    error NotWhitelisted();

    // #############################################
    // MODIFIERS
    // #############################################

    /**
     * @dev Throws if called by any account that is not whitelisted when whitelist is enabled
     */
    modifier onlyWhitelisted() {
        if (whitelistEnabled && !whitelist[msg.sender]) {
            revert NotWhitelisted();
        }
        _;
    }

    // #############################################
    // WHITELIST MANAGEMENT
    // #############################################

    /**
     * @notice Adds an address to the whitelist
     * @param account Address to add to whitelist
     */
    function _addToWhitelist(address account) internal {
        whitelist[account] = true;
        emit WhitelistAdded(account);
    }

    /**
     * @notice Removes an address from the whitelist
     * @param account Address to remove from whitelist
     */
    function _removeFromWhitelist(address account) internal {
        whitelist[account] = false;
        emit WhitelistRemoved(account);
    }

    /**
     * @notice Enables or disables the whitelist
     * @param enabled Whether whitelist should be enabled
     */
    function _setWhitelistEnabled(bool enabled) internal {
        whitelistEnabled = enabled;
        emit WhitelistStatusSet(enabled);
    }

    /**
     * @notice Checks if an address is whitelisted
     * @param account Address to check
     * @return bool Whether the address is whitelisted
     */
    function isWhitelisted(address account) public view returns (bool) {
        return whitelist[account];
    }
}
