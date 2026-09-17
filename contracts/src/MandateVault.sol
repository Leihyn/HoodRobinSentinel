// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

/// @title MandateVault
/// @notice Holds the principal for one mandate while the agent works.
///
///         The vault exists because of where the measurement has to happen. If a
///         mandate measured the principal's own wallet, the principal could move
///         funds out before the deadline and force a failure, taking the agent's
///         bond. Measuring a balance that neither party can withdraw from until
///         settlement removes that.
///
///         The agent can move the funds, but only through targets the principal
///         named when opening the mandate. This does not make theft impossible. An
///         allowlisted router can usually be pointed somewhere unhelpful. It makes
///         theft *visible and terminal*: the balance is short at settlement, the
///         mandate fails, the bond is slashed, and the failure is on the agent's
///         permanent record. Reputation is the enforcement, not the gate.
contract MandateVault {
    address public immutable manager;
    address public immutable agentOperator;
    address public immutable token;

    mapping(address => bool) public allowedTarget;

    event Executed(address indexed target, bytes4 indexed selector, bool success);
    event Released(address indexed to, uint256 amount);

    error NotManager();
    error NotAgent();
    error TargetNotAllowed();
    error CallFailed(bytes returndata);

    constructor(address agentOperator_, address token_, address[] memory targets) {
        manager = msg.sender;
        agentOperator = agentOperator_;
        token = token_;
        for (uint256 i; i < targets.length; ++i) {
            allowedTarget[targets[i]] = true;
        }
    }

    /// @notice Let the agent act on the mandate's funds, within the principal's allowlist.
    function execute(address target, bytes calldata data) external returns (bytes memory) {
        if (msg.sender != agentOperator) revert NotAgent();
        if (!allowedTarget[target]) revert TargetNotAllowed();

        (bool ok, bytes memory ret) = target.call(data);
        if (!ok) revert CallFailed(ret);

        emit Executed(target, bytes4(data), ok);
        return ret;
    }

    /// @notice Approve an allowlisted target to pull the mandate token.
    /// @dev Most routers pull rather than receive. Restricting approvals to the
    ///      same allowlist keeps the spender set identical to the call set.
    function approveTarget(address target, uint256 amount) external {
        if (msg.sender != agentOperator) revert NotAgent();
        if (!allowedTarget[target]) revert TargetNotAllowed();
        IERC20(token).approve(target, amount);
    }

    /// @notice Pay out at settlement. Manager only.
    function release(address to, uint256 amount) external {
        if (msg.sender != manager) revert NotManager();
        if (amount > 0) {
            require(IERC20(token).transfer(to, amount), "release failed");
            emit Released(to, amount);
        }
    }

    function balance() external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
