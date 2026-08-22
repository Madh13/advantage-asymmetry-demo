// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Minimal mint-on-demand ERC-20 for local Foundry tests only, standing in for
///         AUDD/testnet USDC per the master brief's development fallback hierarchy
///         (Section 4: "Local Foundry tests: use a small mock ERC-20."). Not deployed
///         anywhere beyond the test suite.
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Stable", "mUSD") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
