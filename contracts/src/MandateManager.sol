// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MandateVault, IERC20} from "./MandateVault.sol";

interface IAgentRegistry {
    function agents(uint256)
        external
        view
        returns (address operator, uint256 stake, string memory metadataURI, uint64 passed, uint64 failed, bool retired);
    function recordOutcome(uint256 agentId, bool success) external;
    function slash(uint256 agentId, uint256 amount, address to) external returns (uint256);
}

/// @title MandateManager
/// @notice Opens mandates and settles them from chain state.
///
///         A mandate is a promise with a number attached: this much principal, this
///         much gain, by this time. Settlement reads the vault balance and compares
///         it to the promise. There is no amount parameter on `settle`, no verdict
///         parameter, and no privileged caller. The outcome is derived, so anyone
///         may trigger it and nobody can shade it.
///
///         That is why settlement is permissionless. A caller picks nothing and
///         gains nothing, so there is no keeper to run and nothing to bribe.
contract MandateManager {
    enum Status {
        None,
        Open,
        Passed,
        Failed
    }

    struct Mandate {
        uint256 agentId;
        address principal; // who funded it and who gets the result
        address token;
        address vault;
        uint256 deposited; // measured baseline: what went in
        uint256 targetGain; // how much more must be there at the deadline
        uint256 bond; // agent stake at risk on this mandate
        uint64 deadline;
        Status status;
    }

    IAgentRegistry public immutable registry;

    uint256 public nextMandateId = 1;
    mapping(uint256 => Mandate) public mandates;

    event Opened(
        uint256 indexed mandateId,
        uint256 indexed agentId,
        address indexed principal,
        address vault,
        uint256 deposited,
        uint256 targetGain,
        uint64 deadline
    );
    event Settled(
        uint256 indexed mandateId,
        uint256 indexed agentId,
        bool success,
        uint256 finalBalance,
        uint256 required,
        uint256 slashed
    );

    error UnknownMandate();
    error NotOpen();
    error TooEarly();
    error DeadlineInPast();
    error ZeroDeposit();
    error AgentUnavailable();
    error InsufficientStake();
    error TransferFailed();

    constructor(address registry_) {
        registry = IAgentRegistry(registry_);
    }

    /// @notice Fund a mandate and put an agent's bond behind it.
    /// @param agentId       the agent taking the work
    /// @param token         ERC20 the mandate is denominated and measured in
    /// @param amount        principal handed to the agent
    /// @param targetGain    how much above the principal must be present at settlement
    /// @param deadline      when the promise comes due
    /// @param bond          agent stake placed at risk; slashed to the principal on failure
    /// @param targets       venues the agent may call, chosen by the principal
    function open(
        uint256 agentId,
        address token,
        uint256 amount,
        uint256 targetGain,
        uint64 deadline,
        uint256 bond,
        address[] calldata targets
    ) external returns (uint256 mandateId) {
        if (amount == 0) revert ZeroDeposit();
        if (deadline <= block.timestamp) revert DeadlineInPast();

        (address operator, uint256 stake,,,, bool retired) = registry.agents(agentId);
        if (operator == address(0) || retired) revert AgentUnavailable();
        if (stake < bond) revert InsufficientStake();

        MandateVault vault = new MandateVault(operator, token, targets);

        if (!IERC20(token).transferFrom(msg.sender, address(vault), amount)) revert TransferFailed();

        mandateId = nextMandateId++;
        mandates[mandateId] = Mandate({
            agentId: agentId,
            principal: msg.sender,
            token: token,
            vault: address(vault),
            deposited: amount,
            targetGain: targetGain,
            bond: bond,
            deadline: deadline,
            status: Status.Open
        });

        emit Opened(mandateId, agentId, msg.sender, address(vault), amount, targetGain, deadline);
    }

    /// @notice Settle a mandate against what is actually in the vault.
    /// @dev Permissionless, and parameterless beyond the id. Early settlement is
    ///      allowed once the target is already met, because holding a met promise
    ///      open only exposes the principal to the agent losing it again.
    function settle(uint256 mandateId) external {
        Mandate storage m = mandates[mandateId];
        if (m.status == Status.None) revert UnknownMandate();
        if (m.status != Status.Open) revert NotOpen();

        uint256 finalBalance = IERC20(m.token).balanceOf(m.vault);
        uint256 required = m.deposited + m.targetGain;
        bool success = finalBalance >= required;

        if (!success && block.timestamp < m.deadline) revert TooEarly();

        m.status = success ? Status.Passed : Status.Failed;

        // The principal is made whole as far as the vault allows, always.
        MandateVault(m.vault).release(m.principal, finalBalance);

        uint256 slashed;
        if (!success) {
            // The whole bond is forfeit, and deliberately so.
            //
            // The obvious alternative is to slash the shortfall. It is wrong here:
            // the shortfall is denominated in the mandate token and the bond is
            // denominated in ETH, so comparing them silently mixes units. With a
            // six-decimal stablecoin it is worse than meaningless. A ten thousand
            // dollar shortfall becomes 1e10 wei, and an agent could steal the
            // principal for a slashing cost of roughly ten gwei.
            //
            // Converting between the two would need a price oracle, which would
            // hand every settlement a trusted input and undo the reason this
            // contract derives its verdict instead of being told it. So the bond
            // is simply what the agent staked on this promise, forfeit in full if
            // the promise is not kept. No cross-unit arithmetic exists to get
            // wrong.
            slashed = registry.slash(m.agentId, m.bond, m.principal);
        }

        registry.recordOutcome(m.agentId, success);

        emit Settled(mandateId, m.agentId, success, finalBalance, required, slashed);
    }

    function vaultBalance(uint256 mandateId) external view returns (uint256) {
        return IERC20(mandates[mandateId].token).balanceOf(mandates[mandateId].vault);
    }

    /// @notice What settle() would decide right now.
    function wouldPass(uint256 mandateId) external view returns (bool) {
        Mandate storage m = mandates[mandateId];
        return IERC20(m.token).balanceOf(m.vault) >= m.deposited + m.targetGain;
    }

    function totalMandates() external view returns (uint256) {
        return nextMandateId - 1;
    }

    receive() external payable {}
}
