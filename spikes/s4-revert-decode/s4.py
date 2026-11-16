"""Spike S4: preflight a reverting call with eth_call, decode the custom error, then broadcast it anyway.

Run (base-anvil must be running in WSL on port 8545, and `base-forge build` done in spikes/):
    uv run --project agent python spikes/s4-revert-decode/s4.py [rpc_url]
Local anvil only: uses anvil's unlocked dev account, no private key.
"""

import json
import sys
from pathlib import Path

from eth_abi import decode
from eth_utils import keccak
from web3 import Web3
from web3.exceptions import ContractCustomError, ContractLogicError

RPC = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8545"
ARTIFACT = Path(__file__).resolve().parents[1] / "out" / "Reverter.sol" / "Reverter.json"


def error_table(abi: list) -> dict:
    """selector (0x + 8 hex) -> (name, [arg names], [arg types]) for every custom error in the ABI."""
    table = {}
    for item in abi:
        if item["type"] != "error":
            continue
        types = [i["type"] for i in item["inputs"]]
        sel = "0x" + keccak(text=f"{item['name']}({','.join(types)})")[:4].hex()
        table[sel] = (item["name"], [i["name"] for i in item["inputs"]], types)
    return table


def decode_revert(data: str, table: dict) -> str:
    data = data if data.startswith("0x") else "0x" + data
    entry = table.get(data[:10])
    if entry is None:
        return f"unknown error {data[:10]}"
    name, names, types = entry
    args = decode(types, bytes.fromhex(data[10:])) if types else ()
    return name + "(" + ", ".join(f"{n}={v}" for n, v in zip(names, args)) + ")"


def main() -> None:
    w3 = Web3(Web3.HTTPProvider(RPC))
    assert w3.is_connected(), f"no node at {RPC}"
    chain_id = w3.eth.chain_id
    assert chain_id in (31337, 84532), f"refusing chain {chain_id}: local anvil or Base Sepolia only"

    art = json.loads(ARTIFACT.read_text())
    abi, bytecode = art["abi"], art["bytecode"]["object"]
    table = error_table(abi)
    sender = w3.eth.accounts[0]  # anvil dev account, unlocked

    tx = w3.eth.contract(abi=abi, bytecode=bytecode).constructor().transact({"from": sender})
    addr = w3.eth.wait_for_transaction_receipt(tx).contractAddress
    c = w3.eth.contract(address=addr, abi=abi)
    print(f"chain {chain_id}, Reverter at {addr}")

    ok = 0
    for mode, expected in [(1, "AboveFairValue"), (2, "CorporateActionPending"), (3, "EnforcedPause")]:
        # 1) preflight with eth_call
        try:
            c.functions.buy(mode).call({"from": sender})
            print(f"mode {mode}: preflight unexpectedly passed")
            continue
        except (ContractCustomError, ContractLogicError) as e:
            data = e.data if isinstance(e.data, str) else str(e.data)
            decoded = decode_revert(data, table)
        print(f"mode {mode}: preflight -> {decoded}")

        # 2) broadcast anyway with a manual gas limit (skips estimate_gas, which would refuse)
        h = c.functions.buy(mode).transact({"from": sender, "gas": 100_000})
        r = w3.eth.wait_for_transaction_receipt(h)
        print(f"mode {mode}: broadcast tx {h.hex()} status {r.status} gasUsed {r.gasUsed}")

        if decoded.startswith(expected) and r.status == 0:
            ok += 1

    # sanity: the success path still works
    r = w3.eth.wait_for_transaction_receipt(c.functions.buy(0).transact({"from": sender}))
    print(f"mode 0: status {r.status}")

    assert ok == 3 and r.status == 1, "S4 FAILED"
    print("S4 PASS: 3/3 errors decoded by name and 3/3 reverted txs mined with status 0")


if __name__ == "__main__":
    main()
