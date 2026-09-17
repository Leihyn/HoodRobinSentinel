// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {MandateManager} from "../src/MandateManager.sol";
import {MandateVault} from "../src/MandateVault.sol";
import {Wilson} from "../src/Wilson.sol";
import {MockERC20, MockRouter} from "./Mocks.sol";

contract SentinelTest is Test {
    AgentRegistry registry;
    MandateManager manager;
    MockERC20 token;
    MockRouter router;

    address agentOp = address(0xA6E7);
    address principal = address(0xB055);
    address stranger = address(0xC0DE);

    uint256 constant PRINCIPAL_AMOUNT = 10_000e6;
    uint256 constant TARGET_GAIN = 100e6;
    uint256 constant BOND = 1 ether;

    function setUp() public {
        // The registry only accepts writes from the settlement contract, and the
        // settlement contract needs the registry. Both stay immutable by
        // predicting the manager's address from the deployer nonce.
        address predictedManager = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        registry = new AgentRegistry(predictedManager);
        manager = new MandateManager(address(registry));
        assertEq(registry.settlement(), address(manager), "address prediction must hold");

        token = new MockERC20();
        router = new MockRouter(token);

        vm.deal(agentOp, 10 ether);
        token.mint(principal, 1_000_000e6);
    }

    function _register() internal returns (uint256 agentId) {
        vm.prank(agentOp);
        agentId = registry.register{value: 5 ether}("ipfs://agent");
    }

    function _open(uint256 agentId) internal returns (uint256 mandateId) {
        address[] memory targets = new address[](1);
        targets[0] = address(router);

        vm.startPrank(principal);
        token.approve(address(manager), PRINCIPAL_AMOUNT);
        mandateId = manager.open(
            agentId, address(token), PRINCIPAL_AMOUNT, TARGET_GAIN, uint64(block.timestamp + 1 days), BOND, targets
        );
        vm.stopPrank();
    }

    // --- the happy path -----------------------------------------------------

    function test_AgentMeetsTarget_PassesAndKeepsBond() public {
        uint256 agentId = _register();
        uint256 mandateId = _open(agentId);

        (,,, address vault,,,,,) = _mandate(mandateId);

        // The agent earns the gain through the allowlisted venue.
        vm.prank(agentOp);
        MandateVault(vault).execute(address(router), abi.encodeCall(MockRouter.profit, (TARGET_GAIN)));

        uint256 stakeBefore = _stake(agentId);
        uint256 principalBefore = token.balanceOf(principal);

        manager.settle(mandateId);

        (uint64 passed, uint64 failed,) = registry.record(agentId);
        assertEq(passed, 1, "should record a pass");
        assertEq(failed, 0, "should not record a failure");
        assertEq(_stake(agentId), stakeBefore, "bond must not be touched on success");
        assertEq(
            token.balanceOf(principal) - principalBefore,
            PRINCIPAL_AMOUNT + TARGET_GAIN,
            "principal gets deposit plus gain"
        );
    }

    /// A met promise can settle before the deadline. Holding it open would only
    /// expose the principal to the agent losing the gain again.
    function test_EarlySettle_AllowedOnceTargetMet() public {
        uint256 agentId = _register();
        uint256 mandateId = _open(agentId);
        (,,, address vault,,,,,) = _mandate(mandateId);

        vm.prank(agentOp);
        MandateVault(vault).execute(address(router), abi.encodeCall(MockRouter.profit, (TARGET_GAIN)));

        assertTrue(manager.wouldPass(mandateId));
        manager.settle(mandateId); // no warp

        (uint64 passed,,) = registry.record(agentId);
        assertEq(passed, 1);
    }

    // --- failure and slashing ----------------------------------------------

    function test_AgentDoesNothing_FailsAndIsSlashed() public {
        uint256 agentId = _register();
        uint256 mandateId = _open(agentId);

        uint256 stakeBefore = _stake(agentId);
        uint256 principalBefore = token.balanceOf(principal);

        vm.warp(block.timestamp + 2 days);
        manager.settle(mandateId);

        (uint64 passed, uint64 failed,) = registry.record(agentId);
        assertEq(passed, 0);
        assertEq(failed, 1, "doing nothing is a failure, not a neutral outcome");

        assertEq(stakeBefore - _stake(agentId), BOND, "the whole bond is forfeit");
        assertEq(token.balanceOf(principal) - principalBefore, PRINCIPAL_AMOUNT, "deposit returned");
        assertEq(principal.balance, BOND, "bond paid to the principal in ETH");
    }

    /// The design does not prevent an agent misusing an allowlisted venue. It
    /// makes the misuse terminal: the balance is short, the mandate fails, the
    /// bond goes to the victim, and the record carries it forever.
    function test_AgentStealsThroughAllowlistedVenue_FailsAndIsSlashed() public {
        uint256 agentId = _register();
        uint256 mandateId = _open(agentId);
        (,,, address vault,,,,,) = _mandate(mandateId);

        vm.startPrank(agentOp);
        MandateVault(vault).approveTarget(address(router), type(uint256).max);
        MandateVault(vault).execute(address(router), abi.encodeCall(MockRouter.drain, (agentOp)));
        vm.stopPrank();

        assertEq(token.balanceOf(vault), 0, "agent moved the funds out");
        assertEq(token.balanceOf(agentOp), PRINCIPAL_AMOUNT, "agent holds them");

        uint256 stakeBefore = _stake(agentId);
        vm.warp(block.timestamp + 2 days);
        manager.settle(mandateId);

        (, uint64 failed,) = registry.record(agentId);
        assertEq(failed, 1, "theft settles as a failure");
        assertEq(stakeBefore - _stake(agentId), BOND, "bond fully slashed, capped at the bond");
        assertEq(principal.balance, BOND, "victim receives the bond");
    }

    function test_AgentCannotUseUnlistedVenue() public {
        uint256 agentId = _register();
        uint256 mandateId = _open(agentId);
        (,,, address vault,,,,,) = _mandate(mandateId);

        MockRouter rogue = new MockRouter(token);
        vm.prank(agentOp);
        vm.expectRevert(MandateVault.TargetNotAllowed.selector);
        MandateVault(vault).execute(address(rogue), abi.encodeCall(MockRouter.profit, (1)));
    }

    // --- the attacks the vault exists to stop -------------------------------

    /// If a mandate measured the principal's own wallet, the principal could pull
    /// funds before the deadline and collect the bond from an agent that did
    /// nothing wrong. The vault has no withdrawal path for them.
    function test_PrincipalCannotWithdrawEarlyToForceFailure() public {
        uint256 agentId = _register();
        uint256 mandateId = _open(agentId);
        (,,, address vault,,,,,) = _mandate(mandateId);

        vm.prank(principal);
        vm.expectRevert(MandateVault.NotAgent.selector);
        MandateVault(vault).execute(address(router), abi.encodeCall(MockRouter.drain, (principal)));

        vm.prank(principal);
        vm.expectRevert(MandateVault.NotManager.selector);
        MandateVault(vault).release(principal, PRINCIPAL_AMOUNT);
    }

    function test_CannotSettleFailingMandateBeforeDeadline() public {
        uint256 agentId = _register();
        uint256 mandateId = _open(agentId);

        vm.expectRevert(MandateManager.TooEarly.selector);
        manager.settle(mandateId);
    }

    function test_CannotSettleTwice() public {
        uint256 agentId = _register();
        uint256 mandateId = _open(agentId);

        vm.warp(block.timestamp + 2 days);
        manager.settle(mandateId);

        vm.expectRevert(MandateManager.NotOpen.selector);
        manager.settle(mandateId);
    }

    /// Nobody is privileged at settlement, because nobody chooses anything there.
    function test_SettlementIsPermissionless() public {
        uint256 agentId = _register();
        uint256 mandateId = _open(agentId);
        (,,, address vault,,,,,) = _mandate(mandateId);

        vm.prank(agentOp);
        MandateVault(vault).execute(address(router), abi.encodeCall(MockRouter.profit, (TARGET_GAIN)));

        vm.prank(stranger);
        manager.settle(mandateId);

        (uint64 passed,,) = registry.record(agentId);
        assertEq(passed, 1, "a stranger can settle and the verdict is unchanged");
    }

    /// Reputation is writable only by settlement. There is no path for an agent,
    /// an operator, or the deployer to write its own score.
    function test_NobodyCanWriteReputationDirectly() public {
        uint256 agentId = _register();

        vm.prank(agentOp);
        vm.expectRevert(AgentRegistry.NotSettlement.selector);
        registry.recordOutcome(agentId, true);

        vm.expectRevert(AgentRegistry.NotSettlement.selector);
        registry.recordOutcome(agentId, true);

        vm.prank(stranger);
        vm.expectRevert(AgentRegistry.NotSettlement.selector);
        registry.slash(agentId, 1 ether, stranger);
    }

    function test_CannotOpenAgainstMoreBondThanStaked() public {
        vm.prank(agentOp);
        uint256 agentId = registry.register{value: 0.5 ether}("ipfs://thin");

        address[] memory targets = new address[](1);
        targets[0] = address(router);

        vm.startPrank(principal);
        token.approve(address(manager), PRINCIPAL_AMOUNT);
        vm.expectRevert(MandateManager.InsufficientStake.selector);
        manager.open(
            agentId, address(token), PRINCIPAL_AMOUNT, TARGET_GAIN, uint64(block.timestamp + 1 days), 5 ether, targets
        );
        vm.stopPrank();
    }

    // --- the reputation statistic -------------------------------------------

    /// Three-for-three must not outrank 650-of-1000. A raw percentage says
    /// 100% beats 65%; the lower bound says otherwise, which is the point.
    function test_ThinPerfectRecordRanksBelowThickGoodOne() public pure {
        uint256 perfectButThin = Wilson.score(3, 0);
        uint256 goodAndThick = Wilson.score(650, 350);

        assertApproxEqRel(perfectButThin, 0.4385e18, 0.01e18, "3/3 lower bound");
        assertApproxEqRel(goodAndThick, 0.6199e18, 0.01e18, "650/1000 lower bound");
        assertLt(perfectButThin, goodAndThick, "thin perfection must rank lower");
    }

    function test_ScoreIsZeroWithNoRecord() public pure {
        assertEq(Wilson.score(0, 0), 0);
    }

    function test_ScoreRisesWithEvidenceAtFixedRate() public pure {
        // Same 90% rate, more evidence, tighter bound.
        uint256 thin = Wilson.score(9, 1);
        uint256 thick = Wilson.score(900, 100);
        assertLt(thin, thick, "more evidence at the same rate must score higher");
        assertLt(thick, 0.9e18, "the bound never exceeds the observed rate");
    }

    function testFuzz_ScoreNeverExceedsObservedRate(uint32 passed, uint32 failed) public pure {
        uint256 n = uint256(passed) + uint256(failed);
        vm.assume(n > 0 && n < 1e9);

        uint256 s = Wilson.score(passed, failed);
        uint256 observed = (uint256(passed) * 1e18) / n;

        assertLe(s, observed, "a lower bound must not exceed the point estimate");
        assertLe(s, 1e18, "score is a fraction");
    }

    // --- helpers ------------------------------------------------------------

    function _stake(uint256 agentId) internal view returns (uint256 stake) {
        (, stake,,,,) = registry.agents(agentId);
    }

    function _mandate(uint256 id)
        internal
        view
        returns (
            uint256 agentId,
            address principal_,
            address token_,
            address vault,
            uint256 deposited,
            uint256 targetGain,
            uint256 bond,
            uint64 deadline,
            MandateManager.Status status
        )
    {
        return manager.mandates(id);
    }
}
