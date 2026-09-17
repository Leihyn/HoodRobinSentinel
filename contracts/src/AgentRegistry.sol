// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Wilson} from "./Wilson.sol";

/// @title AgentRegistry
/// @notice Identity and reputation for autonomous agents.
///
///         The reputation here is not self-reported. Nothing in this contract lets
///         an agent, or its operator, or an admin, say how well it did. The only
///         function that moves a record is `recordOutcome`, and only the settlement
///         contract may call it, after reading the result off chain state.
///
///         That is the whole difference from a task board where an agent marks its
///         own work complete. A score is either derived from something that
///         happened, or it is a claim. This one is derived.
contract AgentRegistry {
    using Wilson for uint256;

    struct Agent {
        address operator; // who may act for this agent
        uint256 stake; // slashable bond, in native ETH
        string metadataURI; // off-chain descriptor
        uint64 passed;
        uint64 failed;
        bool retired;
    }

    /// The settlement contract. Set once, at deployment, and never again: a
    /// registry whose writer can be swapped is a registry whose history can be
    /// rewritten.
    address public immutable settlement;

    uint256 public nextAgentId = 1;
    mapping(uint256 => Agent) public agents;
    mapping(address => uint256) public agentIdOf;

    event Registered(uint256 indexed agentId, address indexed operator, uint256 stake, string metadataURI);
    event StakeAdded(uint256 indexed agentId, uint256 amount, uint256 total);
    event OutcomeRecorded(uint256 indexed agentId, bool success, uint64 passed, uint64 failed);
    event Slashed(uint256 indexed agentId, uint256 amount, address indexed to);
    event Retired(uint256 indexed agentId, uint256 refunded);

    error NotOperator();
    error NotSettlement();
    error AlreadyRegistered();
    error UnknownAgent();
    error AgentRetired();
    error NoStake();

    constructor(address settlement_) {
        settlement = settlement_;
    }

    modifier onlySettlement() {
        if (msg.sender != settlement) revert NotSettlement();
        _;
    }

    /// @notice Register the caller as an agent, bonding the ETH sent as stake.
    /// @dev The stake exists to be lost. An agent with nothing at risk can fail a
    ///      mandate and register again under a fresh address, which is exactly the
    ///      behaviour this is meant to price.
    function register(string calldata metadataURI) external payable returns (uint256 agentId) {
        if (agentIdOf[msg.sender] != 0) revert AlreadyRegistered();
        if (msg.value == 0) revert NoStake();

        agentId = nextAgentId++;
        agents[agentId] =
            Agent({operator: msg.sender, stake: msg.value, metadataURI: metadataURI, passed: 0, failed: 0, retired: false});
        agentIdOf[msg.sender] = agentId;

        emit Registered(agentId, msg.sender, msg.value, metadataURI);
    }

    function addStake(uint256 agentId) external payable {
        Agent storage a = _live(agentId);
        if (msg.sender != a.operator) revert NotOperator();
        a.stake += msg.value;
        emit StakeAdded(agentId, msg.value, a.stake);
    }

    /// @notice Record a settled mandate. Settlement contract only.
    function recordOutcome(uint256 agentId, bool success) external onlySettlement {
        Agent storage a = _live(agentId);
        if (success) a.passed++;
        else a.failed++;
        emit OutcomeRecorded(agentId, success, a.passed, a.failed);
    }

    /// @notice Take stake from a failing agent and pay it to the wronged party.
    /// @dev Capped at the remaining stake rather than reverting. A mandate must
    ///      always be able to settle; a bond that has already been spent cannot be
    ///      allowed to block the next settlement.
    function slash(uint256 agentId, uint256 amount, address to) external onlySettlement returns (uint256 taken) {
        Agent storage a = agents[agentId];
        if (a.operator == address(0)) revert UnknownAgent();

        taken = amount > a.stake ? a.stake : amount;
        if (taken > 0) {
            a.stake -= taken;
            (bool ok,) = to.call{value: taken}("");
            require(ok, "slash transfer failed");
            emit Slashed(agentId, taken, to);
        }
    }

    /// @notice Retire an agent and withdraw its remaining stake.
    /// @dev The record is kept. Retiring closes the agent to new mandates; it does
    ///      not erase what the agent did, which is the point of keeping a history.
    function retire(uint256 agentId) external {
        Agent storage a = _live(agentId);
        if (msg.sender != a.operator) revert NotOperator();

        uint256 refund = a.stake;
        a.stake = 0;
        a.retired = true;

        if (refund > 0) {
            (bool ok,) = msg.sender.call{value: refund}("");
            require(ok, "refund failed");
        }
        emit Retired(agentId, refund);
    }

    /// @notice Wilson lower bound on this agent's record, in WAD.
    function score(uint256 agentId) external view returns (uint256) {
        Agent storage a = agents[agentId];
        return Wilson.score(a.passed, a.failed);
    }

    function record(uint256 agentId) external view returns (uint64 passed, uint64 failed, uint256 wilson) {
        Agent storage a = agents[agentId];
        return (a.passed, a.failed, Wilson.score(a.passed, a.failed));
    }

    function totalAgents() external view returns (uint256) {
        return nextAgentId - 1;
    }

    function _live(uint256 agentId) private view returns (Agent storage a) {
        a = agents[agentId];
        if (a.operator == address(0)) revert UnknownAgent();
        if (a.retired) revert AgentRetired();
    }

    receive() external payable {}
}
