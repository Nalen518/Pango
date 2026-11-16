// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// Spike S4 target: reverts with PangoVault-style custom errors so the agent can practise decoding them.
contract Reverter {
    error AboveFairValue(uint256 paidPrice, uint256 maxPrice);
    error CorporateActionPending(uint256 effectiveAt);
    error EnforcedPause();

    event Bought(uint256 mode);

    /// mode 0 succeeds; 1, 2, 3 revert with the errors above.
    function buy(uint256 mode) external {
        if (mode == 1) revert AboveFairValue(105e18, 101e18);
        if (mode == 2) revert CorporateActionPending(1_795_000_000);
        if (mode == 3) revert EnforcedPause();
        emit Bought(mode);
    }
}
