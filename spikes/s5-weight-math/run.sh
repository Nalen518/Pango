#!/usr/bin/env bash
# Spike S5: run from WSL in spikes/ → bash s5-weight-math/run.sh
set -o pipefail
export PATH="$PATH:$HOME/.foundry/bin"
cd "$(dirname "$0")/.."
base-forge test --isolate -vv --match-path 's5-*/*' 2>&1 | grep -E 'PASS|FAIL|gas:|weights|weight after|Suite|Logs'
python3 s5-weight-math/check_weights.py
