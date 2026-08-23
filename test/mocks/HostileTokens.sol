// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice ERC-20 that hands control to an attacker contract on every transfer, simulating
///         an ERC-777-style callback token. Used ONLY to probe reentrancy guards -- the
///         intended deployment asset is a standard stablecoin with no transfer hooks.
contract ReentrantToken is ERC20 {
    address public hook;
    bool public hookEnabled;

    constructor() ERC20("Reentrant", "REE") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setHook(address _hook) external {
        hook = _hook;
    }

    function setHookEnabled(bool v) external {
        hookEnabled = v;
    }

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        if (hookEnabled && hook != address(0)) {
            // Best-effort callback; ignore failure so the transfer itself still settles.
            (bool ok,) = hook.call(abi.encodeWithSignature("onTokenMoved()"));
            ok; // silence unused warning
        }
    }
}

/// @notice ERC-20 that burns a fee on every transfer, so the recipient receives less than
///         the sender sent. Used ONLY to demonstrate that this token class is OUTSIDE the
///         supported model -- it is not a supported deployment asset.
contract FeeOnTransferToken is ERC20 {
    uint256 public feeBps = 100; // 1%

    constructor() ERC20("FeeOnTransfer", "FEE") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }
        uint256 fee = (value * feeBps) / 10_000;
        super._update(from, to, value - fee);
        if (fee > 0) {
            super._update(from, address(0xdEaD), fee);
        }
    }
}
