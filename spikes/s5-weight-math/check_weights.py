"""Spike S5 reference: recompute every weight in states.csv with exact rationals and compare to Solidity.

Independent of the Solidity flooring: shares = raw × multiplier / 1e18 exactly, value = shares × price,
weight = value / total × 10,000 exactly. Pass when |solidity_bps − exact_bps| < 1 for every weight.
Also checks the B20 UI conversion matches its documented rule floor(raw × multiplier / 1e18).

    python3 spikes/s5-weight-math/check_weights.py
"""

import csv
import sys
from fractions import Fraction
from pathlib import Path

CSV = Path(__file__).with_name("states.csv")


def main() -> int:
    rows = list(csv.DictReader(CSV.open()))
    worst, worst_at = Fraction(0), "-"
    failures = []
    random_worst = Fraction(0)
    for r in rows:
        n = {k: int(v) for k, v in r.items()}
        for s in ("1", "2"):
            if n["ui" + s] != n["raw" + s] * n["mult" + s] // 10**18:
                failures.append(f"row {n['i']}: B20 ui{s} {n['ui' + s]} != floor(raw*mult/1e18)")
        # exact USD values (units cancel in the weights; keep dollars for readability)
        v1 = Fraction(n["raw1"] * n["mult1"], 10**18) / 10 ** n["dec1"] * Fraction(n["price1"], 10**8)
        v2 = Fraction(n["raw2"] * n["mult2"], 10**18) / 10 ** n["dec2"] * Fraction(n["price2"], 10**8)
        vu = Fraction(n["usdc6"], 10**6)
        total = v1 + v2 + vu
        for name, v in (("w1", v1), ("w2", v2), ("wu", vu)):
            exact = v / total * 10_000 if total else Fraction(0)
            diff = abs(n[name] - exact)
            if diff > worst:
                worst, worst_at = diff, f"row {n['i']} {name}"
            if n["i"] < 50:
                random_worst = max(random_worst, diff)
            if diff >= 1:
                failures.append(f"row {n['i']}: {name} solidity {n[name]} vs exact {float(exact):.4f} bps")
    print(f"{len(rows)} states checked, worst |solidity - exact| = {float(worst):.10f} bps ({worst_at})")
    print(f"50 random states: worst {float(random_worst):.10f} bps (Solidity floors, so the error is always < 1)")
    for f in failures:
        print("FAIL", f)
    print("S5 weight math PASS" if not failures else f"S5 weight math FAIL ({len(failures)})")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
