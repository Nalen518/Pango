# Pango

A research-to-portfolio agent for tokenized stocks on Base. PangoVault enforces every trade rule onchain: fair-value band, no trading through a stock split, share and spending caps, owner weight bounds. Testnet only (Base Sepolia).

Spec: [docs/Pango-SRD.md](docs/Pango-SRD.md)

## Layout

| Folder | What |
| --- | --- |
| `contracts/` | base-forge project (OpenZeppelin v5.7.0, base-std v1.1.0, forge-std v1.17.0) |
| `agent/` | Python agent service (FastAPI, web3.py), managed with uv |
| `web/` | Next.js app (wagmi, viem, @base-org/account), managed with pnpm |
| `spikes/` | Phase 0 risk spikes S1–S5 (throwaway) |
| `docs/` | SRD, phase briefs, spike report |

## Toolchain (tested versions)

| Tool | Version |
| --- | --- |
| base-forge / base-cast / base-anvil | 1.6.0-v1.1.0 (commit `6130ccf`) |
| solc | 0.8.35 |
| Python (uv-managed) | 3.11.17, uv 0.13.5 |
| Node / pnpm | 24.16.0 / 11.9.0 |
| Next.js | 16.4.6 |

## Setup (Windows + WSL)

1. Install WSL2 with Ubuntu: `wsl --install -d Ubuntu` (admin PowerShell, then reboot).
2. In WSL, install Base's Foundry build:
   `curl -L https://raw.githubusercontent.com/base/base-anvil/HEAD/foundryup/install | bash`, open a new shell, run `base-foundryup`.
3. Clone with submodules: `git clone --recurse-submodules https://github.com/Nalen518/Pango.git`
4. Copy `.env.example` to `.env` and fill in testnet values.
5. Contracts (in WSL): `cd contracts && base-forge test`
6. Agent (Windows): `cd agent && uv sync && uv run agent` → http://127.0.0.1:8000/health
7. Web (Windows): `cd web && pnpm install && pnpm dev` → http://localhost:3000

Stock `forge` can't run B20 precompiles; always use the `base-` commands for contracts.
