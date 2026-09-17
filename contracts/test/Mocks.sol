// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockERC20 {
    string public name = "Mock USD";
    string public symbol = "mUSD";
    uint8 public decimals = 6;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        if (a != type(uint256).max) allowance[from][msg.sender] = a - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// @notice Stands in for a trading venue. `profit` mints a gain into the caller,
///         `drain` pulls the caller's balance somewhere else. Both are reachable
///         through the same allowlisted address, which is the realistic case: a
///         router the principal trusts can still be pointed at a bad outcome.
contract MockRouter {
    MockERC20 public immutable token;

    constructor(MockERC20 token_) {
        token = token_;
    }

    function profit(uint256 amount) external {
        token.mint(msg.sender, amount);
    }

    function drain(address to) external {
        uint256 bal = token.balanceOf(msg.sender);
        token.transferFrom(msg.sender, to, bal);
    }
}
