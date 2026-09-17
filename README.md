# HoodRobinSentinel

**Agent reputation that is measured, not claimed. Built on Robinhood Chain.**

## The problem

An agent offers to run a strategy with your money. It says it has a 94% success
rate. Where did that number come from?

On every agent registry shipping today, it came from the agent. The agent
accepts a task, does something, then calls `markComplete()`. The contract writes
down what it was told. A score built that way is a press release with a
signature on it, and the failure mode is not subtle: an agent completes three
cheap tasks, mints itself a perfect record, rents that record out, and walks
away from the fourth.

Robinhood Chain makes this urgent rather than academic. It is a permissionless,
AI-native L2 whose stated purpose is agents that "trade, swap, lend, and
transact with tokenized real-world assets onchain." Agents on it move real
positions. The thing missing underneath is any way to know which of them has
actually done what it says.

## The idea

Nothing here lets anyone state an outcome.

A mandate is a promise with a number attached: this much principal, this much
gain, by this time. At settlement the contract reads the vault balance and
compares it to the promise. There is no verdict parameter, no amount parameter,
and no privileged caller. The outcome is *derived from chain state*, so the
reputation that follows from it cannot be negotiated.

```
principal funds a mandate ─► MandateVault ◄── agent trades, within an allowlist
                                  │
                       settle(id) │  permissionless, parameterless
                                  ▼
                   balance >= deposited + targetGain ?
                       pass ──► record, bond returned
                       fail ──► record, bond slashed to the principal
```

Because the caller of `settle` chooses nothing and gains nothing, anyone may
call it. There is no keeper to run, no relayer to trust, and nothing to bribe.

## Why there is a vault

The obvious design measures the principal's own wallet. It is broken. The
principal could move funds out before the deadline, force a failure, and collect
the bond from an agent that did nothing wrong.

So the funds sit in a per-mandate vault that neither party can withdraw from
until settlement. The agent can move them, but only through venues the principal
named when opening the mandate.

That does not make theft impossible, and it is not meant to. An allowlisted
router can usually be pointed somewhere unhelpful. What it makes theft is
**visible and terminal**: the balance is short at settlement, the mandate fails,
the bond goes to the victim, and the failure is on the agent's permanent record.
Reputation is the enforcement, not the gate. `test_AgentStealsThroughAllowlistedVenue_FailsAndIsSlashed`
is that path, end to end.

## Why the score is a Wilson lower bound

A raw success rate lies on small samples. Three wins out of three is 100%, and
it tells you nothing.

The Wilson lower bound asks a better question: given this record, what is the
worst true rate still consistent with it at 95% confidence?

| Record | Raw rate | Wilson lower bound |
|---|---|---|
| 3 / 3 | 100% | **0.44** |
| 650 / 1000 | 65% | **0.62** |

Thin perfection ranks below thick competence, which is the correct ordering when
the number gates money. It also removes the incentive to farm a perfect score
from a handful of cheap mandates, because the bound widens on thin evidence
rather than rewarding it.

## Live on Robinhood Chain testnet

| Contract | Address |
|---|---|
| AgentRegistry | [`0xa736E54B0fEa99809dC7eE9ce24E8B54ca6219eb`](https://explorer.testnet.chain.robinhood.com/address/0xa736E54B0fEa99809dC7eE9ce24E8B54ca6219eb) |
| MandateManager | [`0xA4C2f6F2BCA05d93F197133e9DCD25273ae6D909`](https://explorer.testnet.chain.robinhood.com/address/0xA4C2f6F2BCA05d93F197133e9DCD25273ae6D909) |

Chain id 46630, ETH for gas. `forge test` is 15/15, including a 257-run fuzz
over the score function.

### One full cycle, settled on chain

Agent 1 registered with a 0.002 ETH stake, took a mandate for 10,000 units of
principal against a 100-unit target, earned it through an allowlisted venue, and
was settled by an ordinary call that passes nothing but the id.

| | |
|---|---|
| Open mandate | [`0xfb1fa8c0…11cc70`](https://explorer.testnet.chain.robinhood.com/tx/0xfb1fa8c0e4c6d20aa2f029b31f71c4513a65d14712c2679ee1133533ae11cc70) |
| Agent works it | [`0x733a0af5…5d7eea8d`](https://explorer.testnet.chain.robinhood.com/tx/0x733a0af5a6044eb6085b614223ff747918c6aae5528138bfdf79a7f35d7eea8d) |
| Settlement | [`0xbe5f3f4a…fa937de2`](https://explorer.testnet.chain.robinhood.com/tx/0xbe5f3f4a3510aac792d8b0499647953e12044b5725a1f735cc614344fa937de2) |

`wouldPass(1)` read `false` before the agent acted and `true` after, from the
vault balance alone. The record that came out of settlement:

```
passed = 1   failed = 0   score = 206543291473892927   (20.65%)
```

**One success is worth 20.65%, not 100%.** That is the entire argument, now
enforced by a deployed contract rather than asserted in a README. The raw rate
after one win is 100%; the lower bound says a single observation is nearly no
evidence, so a fresh agent cannot present itself as proven.

## Run it

```bash
cd contracts
forge test -vv
```

To deploy, fund an address from the
[official faucet](https://faucet.testnet.chain.robinhood.com/) or
[Chainstack](https://faucet.chainstack.com/robinhood-chain-testnet-faucet),
then:

```bash
export PRIVATE_KEY=0x...
./script/deploy.sh
```

Deployment costs on the order of 0.000002 ETH.

## Two things that will waste your afternoon

**`forge script` refuses this chain.** It exits with `Chain 46630 not supported`
before doing anything. `forge create` has no such objection, which is why
`script/deploy.sh` drives the deployment and `Deploy.s.sol` is kept only to
document the wiring.

**forge cannot complete a TLS handshake to the public RPC.** It fails with
`received fatal alert: BadRecordMac` while `curl` and `cast` reach the identical
URL without complaint. The endpoint sits behind Cloudflare, which answers
unfamiliar clients with error 1010, "banned based on your browser's signature."
Python's default urllib agent gets the same treatment; a curl user-agent does
not. `script/rpc-proxy.py` performs the TLS leg with a client Cloudflare accepts
and serves plain HTTP to forge on localhost. `deploy.sh` starts and stops it for
you.

## The page

`app/index.html` is one file with no build step and no dependencies. It reads the registry
directly over JSON-RPC and recomputes every score in the browser, so the leaderboard is
verifiable by whoever is looking at it rather than served from an indexer you would have to
trust. Until the contracts exist it says so plainly instead of inventing rows.

```bash
python3 -m http.server 4755 --directory app
```

`deploy.sh` writes the deployed addresses into that file, so the page and the chain cannot
drift apart.

## Layout

| Path | |
|---|---|
| `contracts/src/AgentRegistry.sol` | identity, stake, record. Writable only by settlement. |
| `contracts/src/MandateManager.sol` | opens mandates, settles them from chain state. |
| `contracts/src/MandateVault.sol` | per-mandate escrow; agent acts within the principal's allowlist. |
| `contracts/src/Wilson.sol` | Wilson lower bound in WAD, with an integer sqrt. |
| `contracts/script/deploy.sh` | deployment, with the nonce prediction checked on chain. |
| `contracts/script/rpc-proxy.py` | the Cloudflare workaround described above. |
| `app/index.html` | the leaderboard; zero dependencies, reads the chain itself. |

## What is deliberately not here

**No oracle.** Slashing takes the whole bond rather than the shortfall. Slashing
the shortfall would mean comparing a token-denominated number against an
ETH-denominated one, which is a units bug: a ten thousand dollar shortfall in a
six-decimal stablecoin becomes 1e10 wei, so an agent could steal the principal
for a slashing cost of about ten gwei. Converting between them needs a price
feed, and a price feed would hand every settlement a trusted input, undoing the
reason the contract derives its verdict instead of being told it.

**No admin.** There is no pause, no upgrade, and no setter on the registry's
settlement address. Whoever can point a reputation registry at a new writer can
rewrite its history, so nobody can.

**No partial credit.** A promise is met or it is not.
