#!/usr/bin/env bash
# Spike S3 (read-only, Base mainnet, no wallet): read Coinbase tokenized-stock Chainlink feeds
# and walk back recent rounds to see how long the feed goes without an update.
# Feed addresses from https://docs.base.org/build-on-base/integrate-defi/list-tokenized-stocks
set -eo pipefail
export PATH="$PATH:$HOME/.foundry/bin"
RPC="${BASE_MAINNET_RPC_URL:-https://mainnet.base.org}"
ROUNDS="${ROUNDS:-25}"

read_feed() {
  local name=$1 feed=$2
  echo "== $name feed $feed"
  echo "description: $(base-cast call "$feed" 'description()(string)' --rpc-url "$RPC")"
  echo "decimals:    $(base-cast call "$feed" 'decimals()(uint8)' --rpc-url "$RPC")"
  local out; out=$(base-cast call "$feed" 'latestRoundData()(uint80,int256,uint256,uint256,uint80)' --rpc-url "$RPC")
  local rid ans upd now
  rid=$(echo "$out" | sed -n 1p | awk '{print $1}')
  ans=$(echo "$out" | sed -n 2p | awk '{print $1}')
  upd=$(echo "$out" | sed -n 4p | awk '{print $1}')
  now=$(date -u +%s)
  echo "latest: round $rid answer $ans updatedAt $upd ($(date -u -d @"$upd" '+%a %F %T') UTC), age $(( (now-upd)/3600 ))h"
  echo "recent rounds (updatedAt UTC, gap to next):"
  local prev=$upd r=$rid
  for _ in $(seq 1 "$ROUNDS"); do
    r=$(python3 -c "print($r - 1)") # round ids exceed 64-bit shell math
    local o u a
    o=$(base-cast call "$feed" 'getRoundData(uint80)(uint80,int256,uint256,uint256,uint80)' "$r" --rpc-url "$RPC" 2>/dev/null) || break
    a=$(echo "$o" | sed -n 2p | awk '{print $1}')
    u=$(echo "$o" | sed -n 4p | awk '{print $1}')
    echo "  $(date -u -d @"$u" '+%a %F %T')  answer $a  gap $(( (prev-u)/3600 ))h"
    prev=$u
  done
}

echo "Base mainnet block $(base-cast block-number --rpc-url "$RPC"), now $(date -u '+%a %F %T') UTC"
read_feed NVDA 0x04689a41629776563E6822F76f2e57D148d28513
read_feed AAPL 0x787f13dEa48Db0897CbCDD985de77809D837F988
