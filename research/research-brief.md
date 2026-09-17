# Arbitrum Open House Singapore: Online Buildathon — Research Brief

**Compiled:** 2026-09-17
**Intel Depth:** ID 9 (Deep Intelligence)
**Sources:** Web research (14 searches, 5 page fetches). Social intel NOT gathered — see § Social Intel.

---

## Overview

| Field | Value |
|-------|-------|
| Name | Arbitrum Open House Singapore — Online Buildathon |
| Organizer | Arbitrum Foundation, sponsored by Robinhood Chain |
| Platform | HackQuest |
| Window | 13 September – **4 October 2026** |
| Prize pool | $115,000 USDC (this phase), $415,000 across Open House |
| Tracks | Overall, Promising Products, Grants |
| Chain | Any Arbitrum chain — Arbitrum One, Arbitrum Sepolia, **Robinhood Chain** |
| Next stage | Founder House Singapore, 23–25 October, +$300K |

---

## THE HEADLINE FINDING

**BOTTOM LINE:** ERC-8004's **Validation Registry is not deployed**. The standard defines three registries — identity, reputation, validation — and ships only the first two. HoodRobinSentinel is functionally the missing third. That reframes the project from "a competing agent registry" (weak, duplicative) to "the part of the ratified standard nobody has built" (strong, timely).

**EVIDENCE:**
- "The Validation Registry is still planned, and its corresponding smart contracts have not yet been deployed." [A1, Chainstack ERC-8004 teardown]
- ERC-8004's Reputation Registry is **client-attested opinion**: a user "submitted feedback... a rating of 80/100 with the following comment." [A1, same]
- ERC-8004 ratified January 2026, live on 18+ EVM chains including Arbitrum. [B2, multiple]
- Identity Registry = an ERC-721 minted by the agent's own owner. [A1]

**CONFIDENCE:** High. Sourced from a technical teardown that walks the actual deployed contracts, corroborated by the standard's own framing.

**SO WHAT:** Do not position this as agent reputation. Position it as **derivation**: ERC-8004 standardised *where* a score lives and left *where the number comes from* undefined. A rating of 80/100 with a comment is a Yelp review. HoodRobinSentinel produces a verdict no party authored. Reads as filling a known gap in a ratified standard rather than competing with it — and the builder already shipped Warrant, an ERC-8004 validator, so the lineage is real.

---

## Judging Criteria

Two published framings. Both matter.

**HackQuest listing (the submission form's rubric):**

| Criterion | What it means | Our standing |
|---|---|---|
| Smart contract quality | "best practices, structured logically and efficiently, with minimal security vulnerabilities" | **Strongest.** No admin/pause/upgrade, immutable wiring, 15 tests + 257-run fuzz, a units bug found by tests and fixed by deleting the cross-unit arithmetic. |
| Product-market fit potential | "clear potential to attract and retain users" | **Weakest.** One agent, two mandates, all self-created. |
| Innovation and creativity | "original approaches that push boundaries" | Strong. Derived-not-asserted + Wilson lower bound. |
| Real problem-solving | "address genuine market needs" | Strong and timely. |

**Organizer's own scoring framework (DEV post, more operational):** execution (repo/demo quality), problem-solution fit (sector-specific), **traction/potential (evidence of post-event continuation)**.

**SO WHAT:** The third axis is not on the HackQuest page and is easy to miss. "Dormant repositories after submission significantly hurt traction scores." Commit activity through judging is scored.

---

## Disqualifiers

**BOTTOM LINE:** One hard eliminator, and we already cleared it.

- **"Projects must deploy on an Arbitrum chain before evaluation begins. Not 'plans to deploy.' Not 'could work on Arbitrum.' Deployed. This eliminates numerous submissions automatically."** [A1, Arbitrum DEV post]
- "If no or few submissions meet the host's quality standards, the prize may be subject to change." [B2]

**SO WHAT:** HoodRobinSentinel is deployed on Robinhood Chain testnet with two settled mandates. A meaningful share of the field will be removed at this gate. Our contracts are live at `0xa736E54B…` and `0xA4C2f6F2…`.

---

## Prizes

| Track | 1st | 2nd | 3rd |
|---|---|---|---|
| Overall | 40,000 | 20,000 | 10,000 |
| Promising Products | 7,000 | 5,000 | 3,000 |
| Grants | up to 30,000, milestone-based, Foundation discretion | | |

**Reserved slot:** *"At minimum, 1 of 3 prizes is reserved for a project building on Robinhood Chain"* — across both prize tracks. [A1, HackQuest]

**SO WHAT:** This is the single largest strategic lever. Most entrants default to Arbitrum One or Sepolia. Deploying on Robinhood Chain moves us into a guaranteed-podium pool, and we are already there.

---

## Demo Video Requirements

No explicit demo video length, format, or platform requirement was found on the HackQuest listing or Arbitrum's posts. [ASSUMED] Standard 2–4 minute recorded demo. Confirm on HackQuest before submitting.

---

## Submission Form Fields

Not public — HackQuest reveals the submission form to registered teams. **Register early to extract the field list**, which is a direct input to the packaging step.

---

## Network / Chain Infrastructure

| Field | Value |
|---|---|
| Chain | Robinhood Chain (Arbitrum Orbit L2, built with Offchain Labs) |
| Chain ID | **46630** testnet / **4663** mainnet |
| RPC | `https://rpc.testnet.chain.robinhood.com` (verified live, chain id `0xb626`) |
| Explorer | `https://explorer.testnet.chain.robinhood.com` |
| Gas | ETH |
| Faucet | `https://faucet.testnet.chain.robinhood.com/`, Chainstack up to 1 ETH/24h |
| Block time | 100ms |
| Stack | Fully EVM; Solidity or Rust via Stylus; ERC-4337 first-class |

**Two traps, both hit and documented in this repo:** `forge script` rejects chain 46630 outright; forge cannot complete TLS to the public RPC because Cloudflare answers unfamiliar clients with error 1010. `contracts/script/rpc-proxy.py` is the workaround.

---

## Competitor Landscape

**BOTTOM LINE:** Buildathon submissions are not public before the 4 October deadline, so the entrant field cannot be enumerated. Indirect signals are usable and favourable.

### Robinhood Chain ecosystem (who is actually here)

| Project | Category |
|---|---|
| Arcus, Lighter, Rialto | trading / DeFi |
| Morpho | lending |
| Arrakis, Meridian | liquidity |
| Uniswap | dedicated AMM |
| Chainlink, Alchemy, LayerZero, Allium, TRM | infrastructure |

**Zero agent-infrastructure projects named.** The deployed ecosystem is DeFi-heavy despite the chain's AI-native marketing.

### Adjacent prior art (not this buildathon)

| Project | What | Threat | Source |
|---|---|:---:|---|
| AgentPass | ERC-8004 identity + challenge-response auth on Base | LOW — identity, not outcome derivation; different event | [C3] |
| OpenStoa | won Synthesis 2026 "Agents That Keep Secrets" | LOW — privacy, different axis | [C3] |
| A-Identity | "passport and wallet for the agentic economy" — KYA + settlement | MEDIUM — adjacent framing, but identity+payments not measurement | [C3] |

**CONFIDENCE:** Medium. Absence of a named competitor is bounded by search visibility, not proof of absence.

**SO WHAT:** The gap is real in both directions — nobody visible is deriving agent reputation from settlement, and the chain's own ecosystem has no agent infrastructure at all. The risk is the mirror image: if no agents exist on Robinhood Chain, who uses this? That is the cold-start question a judge will ask, and § PMF below is the honest answer.

---

## Past Editions Analysis

**BOTTOM LINE:** Winners ship sophisticated math and working code, not decks.

- India cohort's top execution scorer built a "high-precision math layer in Stylus using Q96.48 fixed-point arithmetic, added trade segmentation for large orders." [A1]
- "Winning teams ship functional MVPs with structured code, documentation, and tests — not polished pitch decks with broken demos." [A1]
- Several India winners advanced to the mentorship program and continued toward mainnet. [A1]

**SO WHAT:** A Wilson lower bound implemented in WAD fixed-point with an integer sqrt is the *same shape of achievement* as the India winner's Q96.48 layer — non-obvious math, correctly implemented, verified against hand calculation. Lead with it. We can go further than they could: our figures are verifiable on chain (`score(1)` returns `206543291473892927`).

---

## Community Pain (verbatim)

Verbatim quotes captured. **Gap acknowledged:** these are organizer and documentation sources, not community complaints — no Discord/Telegram access this run.

1. **"Not 'plans to deploy.' Not 'could work on Arbitrum.' Deployed."** — Arbitrum, DEV post [A1]
2. **"a polished pitch deck with a broken demo loses to a rough pitch deck with a working MVP every time"** — Arbitrum Open House materials [A1]
3. **"The Validation Registry is still planned, and its corresponding smart contracts have not yet been deployed."** — Chainstack [A1]
4. **"In DeFi, judges want user-facing financial products, not protocol wrappers."** — Arbitrum, DEV post [A1] ← **this one is aimed at us**

---

## Capability Sheet — what Robinhood Chain uniquely enables

| Primitive | Uniquely possible here |
|---|---|
| AI-native L2 positioning | The chain's own copy markets "agents that trade, swap, lend, and transact with tokenized real-world assets onchain" — agent infrastructure is on-thesis, not a stretch |
| Tokenized equities (Stock Tokens) | Mandates denominated in real equity exposure, not just stablecoins. **US-unavailable** |
| 100ms blocks | Settlement is cheap and near-instant, so permissionless settle() has no keeper economics problem |
| ERC-4337 first-class | Agents as smart accounts is the native pattern |
| Stylus (Rust) | Heavier math could move to Stylus — the India winner's route |

---

## Category Saturation

**Grid queries returned zero across every category, including a control query for DeFi on Arbitrum One — a category that is certainly not empty.** The query is broken, not the data. No saturation figures are reported rather than reporting a false zero. Copilot was unavailable (`COLOSSEUM_COPILOT_PAT` not set); its corpus is Solana-focused and of limited relevance to an EVM entry regardless.

---

## Track Coverage Matrix

| Track | Prize | Focus | Overlap | Est. submissions |
|---|---|---|---|---|
| Overall | 70K | best project outright | — | HIGH |
| Promising Products | 15K | early-stage with PMF potential | **full overlap with Overall** | MEDIUM |
| Grants | 30K | milestone-based continuation | overlaps both | LOW |

**Multi-track target:** a single submission is considered for Overall and Promising Products; the Robinhood Chain reserved slot applies across both. **Grants reward exactly the "continued building" axis** the organizer scores — a credible post-buildathon roadmap is a third shot at the same work.

---

## Domain Knowledge Sources

| Source | URL | Covers | Essential |
|---|---|---|:---:|
| Robinhood Chain docs | docs.robinhood.com/chain/ | RPC, chain IDs, EVM compat | YES |
| ERC-8004 spec + awesome list | github.com/sudeepb02/awesome-erc8004 | registry shapes to conform to | **YES** |
| Chainstack ERC-8004 teardown | chainstack.com/erc-8004-ai-agents-on-chain/ | what is actually deployed | YES |
| Arbitrum winner analysis | dev.to/arbitrum/what-winning-arbitrum-open-house-teams-do-differently-18f8 | judging reality | YES |

---

## Kill List

**1. Saturated** — Another DEX, lending market, or liquidity manager on Robinhood Chain. Arcus, Lighter, Morpho, Arrakis, Uniswap are already there with real teams.

**2. Broken dependencies** — Anything depending on `forge script` against chain 46630 (rejected), or direct forge→RPC TLS (Cloudflare 1010). Anything depending on US-available Stock Tokens.

**3. Already built** — A bespoke agent identity registry. ERC-8004 ratified that in January and it is live on 18+ chains. Building a competing identity layer is strictly worse than conforming to the existing one.

**4. Zero alignment** — Anything not deployed to an Arbitrum chain before judging. Automatic elimination.

---

## Social Intel

**Not gathered.** No Discord or Telegram link was found for this buildathon, and no manual social review was performed this run. Competitor data above is web-sourced only. This is the main gap in this brief; HackQuest registration would likely expose a participant channel worth reviewing.

---

## Key Links

| Resource | URL |
|---|---|
| HackQuest listing | https://www.hackquest.io/hackathons/Arbitrum-Open-House-Singapore-Online-Buildathon |
| Open House hub | https://openhouse.arbitrum.io/ |
| Winner analysis | https://dev.to/arbitrum/what-winning-arbitrum-open-house-teams-do-differently-18f8 |
| Robinhood Chain docs | https://docs.robinhood.com/chain/ |
| Testnet faucet | https://faucet.testnet.chain.robinhood.com/ |
| ERC-8004 resources | https://github.com/sudeepb02/awesome-erc8004 |

---

## Three actions this brief implies

1. **Reposition as the missing Validation Registry**, not as agent reputation. Conform to ERC-8004 shapes where cheap.
2. **Register on HackQuest now** — it unlocks the submission form fields and likely a participant channel, and costs nothing.
3. **Answer cold start explicitly in the submission.** "In DeFi, judges want user-facing financial products, not protocol wrappers" is aimed squarely at a primitive like this. It needs a user-facing face and a credible first user.
