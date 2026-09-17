# HoodRobinSentinel — Orynth Submission Form

Copy and paste the answers below into the Orynth submission form.

## Product name
HoodRobinSentinel

## Product link
https://hoodrobinsentinel.vercel.app

PENDING A DOMAIN. Orynth has refused free subdomains since 10 September 2026, so this address
is not submittable as it stands. The Vercel project is `hoodrobinsentinel` and it owns this
URL; attach a purchased domain to that project and redeploy before registering. Suggested:
`hoodrobin.xyz`, `sentinelscore.xyz`, or `derived.credit`.

## GitHub repository
https://github.com/Leihyn/HoodRobinSentinel

## X / Twitter account
https://x.com/faruukku

The matching handle, `@faruukku`, is rendered in the footer of the single-page app
(`app/index.html`), beside the project name and the GitHub link.

## One-sentence summary (60 characters maximum)
Agent reputation measured from outcomes, not self-reported

## What makes it special? (500 characters maximum)
Every agent registry takes the agent's word for it: the agent marks its own task complete and the contract records the claim. Here nobody can state an outcome. A mandate is a promise with a number; settlement reads the vault balance and compares. No verdict parameter, no privileged caller. Scores use a Wilson lower bound, so one success is worth 20.65%, not 100%, and a perfect record cannot be farmed from cheap tasks. Live on Robinhood Chain with two mandates settled.

## Categories
Select up to three:
1. AI
2. Crypto/Web3
3. Developer Tools

## Logo
Upload:
`app/logo.png`

512x512. The shield-and-check mark from the site header, drawn in the page's own blue-to-green
gradient on its dark ground. Generated for this submission; the repo had no logo before.

## Screenshots
Upload these in this order (all in `orynth-assets/`, captured 2026-09-17 from the deployed site
at https://hoodrobinsentinel.vercel.app). Frames 1 to 8 are 1440x900 at deviceScaleFactor 2;
frames 9 and 10 are 430x932 phone-viewport captures.

1. `01-hoodrobinsentinel.png` — The thesis: "An agent's record, measured rather than claimed", above a live status strip reading Robinhood Chain directly
2. `02-hoodrobinsentinel.png` — The leaderboard, and the whole argument in one row: the agent's raw success rate reads 50.0% while the Wilson bound it is ranked by reads 9.4%
3. `03-hoodrobinsentinel.png` — Leaderboard detail: kept and missed pills, stake at risk, and the score bar
4. `04-hoodrobinsentinel.png` — "How a score is produced": the four steps from funded mandate to permanent record
5. `05-hoodrobinsentinel.png` — "Why settlement is permissionless", with the three lines of Solidity that produce the verdict
6. `06-hoodrobinsentinel.png` — Foot of the page: the project name, chain, repository link and `@faruukku`
7. `07-hoodrobinsentinel.png` — The same masthead in dark mode, the site's `prefers-color-scheme: dark` palette
8. `08-hoodrobinsentinel.png` — The leaderboard in dark mode
9. `09-hoodrobinsentinel.png` — Phone viewport: headline and live chain status
10. `10-hoodrobinsentinel.png` — Phone viewport, scrolled to the leaderboard

Capture note: every figure in these frames is a live read from Robinhood Chain testnet, not a
fixture. The block height moves between frames because the chain moves between frames. The one
agent and its 1-kept/1-missed record are real settlements I made on chain
([pass](https://explorer.testnet.chain.robinhood.com/tx/0xbe5f3f4a3510aac792d8b0499647953e12044b5725a1f735cc614344fa937de2),
[fail](https://explorer.testnet.chain.robinhood.com/tx/0xea3572a87a4fc4e0ade04eff6ab4a2a7e8d6fee62d52bfe76ce07c5965fdc27f)),
not seeded data. The leaderboard has exactly one row because exactly one agent has registered;
nothing was invented to make the table look fuller.

Keep wallet addresses, secrets, browser tabs, notifications, and unrelated desktop windows out of screenshots.

## First comment
An agent offers to run a strategy with your money and says it has a 94% success rate. Where did that number come from? On every agent registry shipping today, it came from the agent: it marks its own task complete and the contract writes down what it was told. That is a press release with a signature on it. HoodRobinSentinel makes the number unstateable. A mandate carries a principal, a target and a deadline; settlement reads the vault balance and compares it to the promise, with no verdict parameter and no privileged caller, so anyone can settle and nobody can shade it. Scores are a Wilson lower bound rather than a raw rate, which is why one success is worth 20.65% and not 100%. Live on Robinhood Chain testnet with one passing and one failing mandate already settled on chain.

## Why we built it
Robinhood Chain calls itself an AI-native L2 and markets agents that trade, swap, lend and transact with tokenized real-world assets. That is a chain whose thesis is autonomous agents moving real money, and the primitive missing underneath it is any way to know which of those agents has actually delivered.

ERC-8004, ratified in January 2026, defines three registries for exactly this: identity, reputation and validation. Two of them are deployed. The Identity Registry is an ERC-721 an agent's own owner mints. The Reputation Registry holds client-attested feedback, which in practice means a rating out of a hundred with a comment attached, which is a review. The Validation Registry, the one meant to carry derived proof rather than opinion, has not been deployed by anyone.

This is that missing piece. The difference between a review and a measurement is whether any party authored it, and nothing here lets a party author anything.

The statistic matters as much as the mechanism. A raw success rate lies on small samples: three wins from three attempts is 100% and tells you nothing. The Wilson lower bound asks what the worst true rate still consistent with the record is, at 95% confidence. Three-for-three scores 0.44 and 650-of-1000 scores 0.62, so thin perfection ranks below thick competence. That ordering is the difference between a score you can farm and a score you have to earn.

## Standout features
- **Nobody can state an outcome.** `settle(uint256 id)` takes an id and nothing else. The amount comes from the vault balance and the verdict from arithmetic, so there is no parameter to abuse and no caller to privilege.
- **Permissionless settlement.** Because the caller chooses nothing and gains nothing, anyone may settle. No keeper to run, no relayer to trust, no liveness dependency on the team.
- **Wilson lower bound, on chain.** Implemented in WAD fixed point with an integer square root, so other contracts can gate on reputation. `score(1)` returned `206543291473892927` after one success and `94528654800866132` after a subsequent failure, both matching the hand calculation to the last digit.
- **A vault that closes the obvious attack.** Measuring the principal's own wallet would let them withdraw before the deadline, force a failure and take an innocent agent's bond. Funds sit where neither party can reach them until settlement.
- **Theft is terminal rather than impossible.** An allowlisted venue can be pointed somewhere unhelpful. The balance is then short at settlement, the mandate fails, the bond goes to the victim, and the failure is permanent. Reputation is the enforcement, not the gate.
- **No admin, no pause, no upgrade, no setter on the registry's writer.** Whoever can repoint a reputation registry can rewrite its history, so nobody can. The two contracts are wired to each other immutably via an address predicted from the deployer nonce.
- **A page with no build step and no dependencies.** It reads the registry over JSON-RPC and recomputes every score in the browser, so the ranking is verifiable by whoever is looking at it rather than served by an indexer.

## Technology
- Solidity 0.8.35 with Foundry; 15 tests including a 257-run fuzz asserting the score never exceeds the observed rate
- Robinhood Chain (Arbitrum Orbit L2), testnet chain id 46630, ETH for gas, 100ms blocks
- One static HTML file for the frontend; no framework, no bundler, no dependencies
- A Python JSON-RPC proxy for deployment, because Cloudflare answers forge's TLS client with error 1010

## Deployed contracts
Robinhood Chain testnet, chain id 46630.

| Contract | Address |
|---|---|
| AgentRegistry | `0xa736E54B0fEa99809dC7eE9ce24E8B54ca6219eb` |
| MandateManager | `0xA4C2f6F2BCA05d93F197133e9DCD25273ae6D909` |

Settled mandates: one passing, one failing. Agent 1's record is 1 kept, 1 missed, scored 9.45%.

## Known limitations
- Testnet only, and the mandate token is a mock ERC20 rather than a real asset.
- One agent and two mandates exist, and I created all of them. Cold start is the honest weakness: a reputation system with no agents is a database with no rows.
- A third party can donate into a vault and push a mandate to pass. It costs them real money to improve someone else's score, so the attack is self-taxing, but it is not zero.
- An allowlist is only as tight as the principal makes it. Naming a permissive router is equivalent to trusting the agent.

## Ownership verification
When Orynth generates HoodRobinSentinel's unique verification token, replace the placeholder on
line 5 of `app/index.html`:

```html
<meta name="ory-verify" content="PASTE_HOODROBINSENTINEL_TOKEN_HERE">
```

Then redeploy `app/` to the Vercel project `hoodrobinsentinel`.

Do not reuse a verification token from another product.

## Final checklist
- [x] Product name is HoodRobinSentinel.
- [ ] Website opens at a purchased domain (currently hoodrobinsentinel.vercel.app, which Orynth refuses).
- [x] GitHub repository is identified and public.
- [x] `@faruukku` is deployed on the product website (footer).
- [x] Logo is ready at `app/logo.png`.
- [x] Ten screenshots are captured in `orynth-assets/`.
- [ ] Screenshots are uploaded.
- [ ] HoodRobinSentinel's unique Orynth verification token is deployed.
- [ ] Ownership verification succeeds.
- [x] First comment is ready to publish at launch.
