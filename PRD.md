# HoodRobinSentinel: Product Requirements Document

**Version:** 1.0
**Date:** 2026-09-17
**Hackathon:** Arbitrum Open House Singapore — Online Buildathon
**Submission window:** 13 September – 4 October 2026
**Chain:** Robinhood Chain testnet (46630), mainnet 4663
**Status when written:** deployed, two mandates settled on chain

---

## Section 1: Project Overview

### The problem, in one number

**94%.**

That is the success rate an agent will quote you. On every agent registry
shipping today, that number came from the agent. It accepts a task, does
something, and calls `markComplete()`. The contract writes down what it was
told.

A score produced that way is a press release with a signature on it. The abuse
is not subtle: complete three cheap tasks, mint a perfect record, rent the
record out, walk away from the fourth.

### The solution

A mandate is a promise with a number attached: this much principal, this much
gain, by this deadline. At settlement a contract reads the vault balance and
compares it to the promise.

There is no verdict parameter, no amount parameter, and no privileged caller.
The outcome is **derived from chain state**, so the reputation that follows
cannot be negotiated by anyone, including us.

### Why it belongs on Robinhood Chain

Robinhood Chain describes itself as "a permissionless, AI-native Layer 2 built
for financial services and real-world assets," and markets agents that "trade,
swap, lend, and transact with tokenized real-world assets onchain."

That is a chain whose thesis is autonomous agents moving real money. The
primitive missing underneath it is any way to know which of those agents has
actually delivered. Every other L2 could host this; on this one it is load
bearing.

### Why this wins (mapped to the published judging criteria)

| Criterion | Our claim |
|---|---|
| **Smart contract quality** — best practices, minimal vulnerabilities | No admin, no pause, no upgrade, no setter on the registry's writer. 15 tests including a 257-run fuzz. A units bug (token-denominated shortfall vs ETH-denominated bond) was caught by tests and fixed by removing the cross-unit arithmetic rather than adding an oracle. |
| **Innovation and creativity** | Two ideas not present in existing agent registries: reputation *derived at settlement* rather than reported, and ranking by a **Wilson lower bound** so thin perfection cannot outrank thick competence. |
| **Real problem-solving** | Agent reputation is the gating problem for agentic finance, and it is unsolved on every chain. |
| **Product-market fit potential** | Weakest axis, addressed in §6. |

### Thesis framing

> One success is worth 20.65%, not 100%.

That is not a slogan; it is `score(1)` reading `206543291473892927` on Robinhood
Chain testnet right now. The raw rate after one win is 100%. The lower bound
says a single observation is nearly no evidence, so a fresh agent cannot present
itself as proven.

---

## Section 2: System Architecture Overview

### Component table

| Contract | Responsibility | Trust property |
|---|---|---|
| `AgentRegistry` | identity, stake, pass/fail record, Wilson score | writable **only** by the settlement contract, set immutably at construction |
| `MandateManager` | opens mandates, settles them from chain state | settlement takes only an id; no caller is privileged |
| `MandateVault` | per-mandate escrow | neither principal nor agent can withdraw before settlement; agent may act only through principal-chosen venues |
| `Wilson` | lower bound in WAD, integer sqrt | pure; no state, no owner |

### Data flow

```
principal ──open()──► MandateManager ──deploys──► MandateVault
                            │                          ▲
                            │                          │ execute(), allowlist only
                            │                       agent
                 settle(id) │  permissionless, parameterless
                            ▼
              balance >= deposited + targetGain ?
                 pass ──► recordOutcome(true)  ──► bond returned
                 fail ──► recordOutcome(false) ──► bond slashed to principal
```

### State: what persists where

| State | Location | Who can change it |
|---|---|---|
| agent identity, stake | `AgentRegistry` | operator (stake up / retire), settlement (slash) |
| pass / fail counts | `AgentRegistry` | **settlement only** |
| mandate terms | `MandateManager` | nobody after `open()` |
| principal funds | `MandateVault` | agent via allowlist; manager at settlement |

### Deployed

| | |
|---|---|
| AgentRegistry | `0xa736E54B0fEa99809dC7eE9ce24E8B54ca6219eb` |
| MandateManager | `0xA4C2f6F2BCA05d93F197133e9DCD25273ae6D909` |

---

## Section 3: User Flows

### F1: An agent registers
Operator calls `register(metadataURI)` with ETH as stake. The stake exists to be
lost; an agent with nothing at risk can fail and re-register under a new address,
which is the behaviour being priced.

### F2: A principal opens a mandate
Names the agent, the token, the principal amount, the target gain, the deadline,
the bond, and the venues the agent may touch. Funds move into a fresh vault.

### F3: The agent works
`vault.execute(target, data)` — agent only, allowlisted targets only.
`vault.approveTarget()` for routers that pull.

### F4: Anyone settles
`settle(id)` reads the vault balance. Early settlement is allowed once the
target is met, because holding a met promise open only risks losing it again.

### F5: The record updates
Pass returns the bond. Fail forfeits it to the principal. Either way the counts
move and the Wilson score is recomputed from them.

### F6: A reader checks the score
`app/index.html` reads the registry over JSON-RPC and recomputes every score in
the browser. No indexer to trust.

---

## Section 4: Technical Specifications

### 4.1 The releasable test

```solidity
uint256 finalBalance = IERC20(m.token).balanceOf(m.vault);
uint256 required     = m.deposited + m.targetGain;
bool    success      = finalBalance >= required;
```

Three lines, no inputs beyond the id. This is the whole verdict.

### 4.2 Wilson lower bound

`L = ( p̂ + z²/2n − z·sqrt( (p̂(1−p̂) + z²/4n)/n ) ) / (1 + z²/n)` at z = 1.96,
in WAD fixed point with a Babylonian sqrt.

| Record | Raw | Wilson |
|---|---|---|
| 1 / 1 | 100% | 20.65% |
| 1 / 2 | 50% | 9.45% |
| 3 / 3 | 100% | 43.85% |
| 650 / 1000 | 65% | 61.99% |

The first two are measured on chain, not computed here.

### 4.3 Slashing takes the whole bond

The shortfall is denominated in the mandate token; the bond is in ETH. Slashing
the shortfall compares them, which is a units bug: a $10,000 shortfall in a
six-decimal stablecoin is `1e10` wei, so theft would cost roughly ten gwei.
Converting needs a price feed, and a price feed hands every settlement a trusted
input, undoing the reason the verdict is derived. So the bond is forfeit whole
and no cross-unit arithmetic exists.

---

## Section 5: What is deliberately absent

**No oracle.** Any price input is a trusted input.
**No admin, pause, or upgrade.** Whoever can repoint a reputation registry can
rewrite its history.
**No partial credit.** A promise is met or it is not.
**No prevention of theft.** An allowlisted router can be pointed somewhere
unhelpful. The system makes that terminal rather than impossible: short balance,
failed mandate, bond to the victim, permanent record. Reputation is the
enforcement, not the gate.

---

## Section 6: What could go wrong

### Cold start is the real risk
A reputation system with no agents is a database with no rows. Two mandates and
one agent exist, and I created all of them.

**Mitigation to build:** derive a provisional record from existing on-chain
activity so an agent arrives with evidence rather than a blank record, and make
the first mandates cheap enough that bootstrapping is rational.

### The measurement can be gamed at the edges
A third party can donate into a vault and push a mandate to pass. It costs them
real money to improve someone else's score, so the attack is self-taxing, but it
is not zero.

### Allowlists are only as tight as the principal makes them
Naming a permissive router is equivalent to trusting the agent. The product
should ship opinionated allowlist presets rather than a free-text field.

### US jurisdiction
Robinhood's Stock Tokens are unavailable in the US, which constrains what an
RWA-flavoured demo can show.

---

## Section 7: Scope

**P0 — done**
Contracts, tests, deployment, one passing and one failing mandate settled on
chain, zero-dependency leaderboard.

**P1 — before 4 October**
A second agent with a contrasting record so the ranking argument is visible in
the UI rather than only the README. Hosted page on a real domain. Demo video.

**P2 — if time**
Provisional records derived from prior on-chain activity (the cold-start
answer). Allowlist presets. An MCP server so an agent can ask "what can I
prove?" before bidding for work.
