#!/usr/bin/env bash
#
# Deploy the registry and settlement contract to Robinhood Chain.
#
# Why this is a shell script and not `forge script`
# -------------------------------------------------
# `forge script` refuses chain 46630 with "Chain 46630 not supported" — its
# broadcast path wants a chain it recognises. `forge create` has no such
# objection and reaches the node happily, so deployment is driven with that
# instead. Deploy.s.sol is kept because it documents the wiring and is what runs
# once Foundry learns the chain.
#
# The two contracts reference each other and both hold the reference immutably,
# so neither can be deployed second without a setter. A setter on a reputation
# registry is a rewrite button, so instead the settlement address is computed
# from the deployer's next nonce and the registry is built against it. The
# script refuses to continue if the prediction does not hold.
#
# Usage
# -----
#   export PRIVATE_KEY=0x...          # funded on Robinhood Chain testnet
#   ./script/deploy.sh                # testnet, via the local proxy
#   ./script/deploy.sh --direct       # skip the proxy if your network allows TLS
#
set -euo pipefail
cd "$(dirname "$0")/.."

NETWORK="${NETWORK:-testnet}"
PROXY_PORT="${PROXY_PORT:-8645}"
USE_PROXY=1
[[ "${1:-}" == "--direct" ]] && USE_PROXY=0

if [[ -z "${PRIVATE_KEY:-}" ]]; then
  echo "PRIVATE_KEY is not set. Export a key funded on Robinhood Chain $NETWORK." >&2
  exit 1
fi

UPSTREAM="https://rpc.${NETWORK}.chain.robinhood.com"

if [[ $USE_PROXY -eq 1 ]]; then
  # forge's TLS handshake to this endpoint is cut short by the Cloudflare in
  # front of it; the proxy performs the TLS leg with a client it accepts.
  python3 script/rpc-proxy.py --network "$NETWORK" --port "$PROXY_PORT" &
  PROXY_PID=$!
  trap 'kill $PROXY_PID 2>/dev/null || true' EXIT
  sleep 2
  RPC="http://127.0.0.1:${PROXY_PORT}"
else
  RPC="$UPSTREAM"
fi

DEPLOYER=$(cast wallet address --private-key "$PRIVATE_KEY")
BALANCE=$(cast balance "$DEPLOYER" --rpc-url "$RPC")
CHAIN=$(cast chain-id --rpc-url "$RPC")

echo "deployer : $DEPLOYER"
echo "chain    : $CHAIN"
echo "balance  : $BALANCE wei"

if [[ "$BALANCE" == "0" ]]; then
  echo
  echo "No balance. Fund $DEPLOYER from one of:" >&2
  echo "  https://faucet.testnet.chain.robinhood.com/" >&2
  echo "  https://faucet.chainstack.com/robinhood-chain-testnet-faucet" >&2
  exit 1
fi

NONCE=$(cast nonce "$DEPLOYER" --rpc-url "$RPC")
PREDICTED_MANAGER=$(cast compute-address "$DEPLOYER" --nonce $((NONCE + 1)) --rpc-url "$RPC" | awk '{print $NF}')
echo "manager will be at: $PREDICTED_MANAGER"

REGISTRY=$(forge create src/AgentRegistry.sol:AgentRegistry \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --broadcast \
  --constructor-args "$PREDICTED_MANAGER" \
  2>&1 | grep 'Deployed to:' | awk '{print $3}')
echo "AgentRegistry  : $REGISTRY"

MANAGER=$(forge create src/MandateManager.sol:MandateManager \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --broadcast \
  --constructor-args "$REGISTRY" \
  2>&1 | grep 'Deployed to:' | awk '{print $3}')
echo "MandateManager : $MANAGER"

# The whole trust model rests on these two pointing at each other and nothing
# else being able to write reputation. Check it on chain rather than assume it.
# macOS ships bash 3.2, which has no ${VAR,,} lowercase expansion, so fold with tr.
MANAGER_LC=$(printf '%s' "$MANAGER" | tr '[:upper:]' '[:lower:]')
PREDICTED_LC=$(printf '%s' "$PREDICTED_MANAGER" | tr '[:upper:]' '[:lower:]')
if [[ "$MANAGER_LC" != "$PREDICTED_LC" ]]; then
  echo "FATAL: manager landed at $MANAGER, not the predicted $PREDICTED_MANAGER." >&2
  echo "The registry will reject it and nothing can settle. Redeploy both." >&2
  exit 1
fi

WIRED_SETTLEMENT=$(cast call "$REGISTRY" "settlement()(address)" --rpc-url "$RPC")
WIRED_REGISTRY=$(cast call "$MANAGER" "registry()(address)" --rpc-url "$RPC")
echo
echo "registry.settlement() = $WIRED_SETTLEMENT"
echo "manager.registry()    = $WIRED_REGISTRY"

# The page says deploy.sh fills these in, so it has to. A UI that claims to read
# live addresses while holding stale ones is exactly the kind of quiet lie this
# project exists to argue against.
APP="../app/index.html"
if [[ -f "$APP" ]]; then
  python3 - "$APP" "$REGISTRY" "$MANAGER" <<'PYEOF'
import io, re, sys
path, registry, manager = sys.argv[1], sys.argv[2], sys.argv[3]
s = io.open(path, encoding="utf-8").read()
s = re.sub(r'registry:\s*[^,\n]+,', f'registry: "{registry}",', s, count=1)
s = re.sub(r'manager:\s*[^,\n]+,', f'manager:  "{manager}",', s, count=1)
io.open(path, "w", encoding="utf-8").write(s)
print(f"  wrote addresses into {path}")
PYEOF
fi

mkdir -p deployments
cat > "deployments/${CHAIN}.json" <<JSON
{
  "chainId": $CHAIN,
  "network": "robinhood-$NETWORK",
  "deployer": "$DEPLOYER",
  "agentRegistry": "$REGISTRY",
  "mandateManager": "$MANAGER"
}
JSON
echo
echo "wrote deployments/${CHAIN}.json"
