# Pango

Hackathon project for Base Stocks Maxxing (Agentic Stock Finance track), deadline Dec 5, 2026.
Spec: `docs/Pango-SRD.md`. Current phase brief: `docs/Pango-subagent-prompt.md`.

## Repo and authorship

- Repo: https://github.com/Nalen518/Pango
- Nalen518 is the **only** contributor. Never add Claude (or anyone else) as co-author or contributor:
  no `Co-Authored-By:` trailers in commits, no "Generated with Claude Code" lines in PRs, issues, README or docs.
- Commits use the existing git identity (Nalen518); never change it.
- Branches: all work happens on `Development` (capital D, matches the remote). `main` holds only ready-to-deploy code; never commit to `main` directly. Merge `Development` → `main` only when Nalen518 asks.

## Environment

- Windows 11 host. Contracts run in WSL Ubuntu with Base's Foundry build (`base-forge`, `base-cast`, `base-anvil`, installed in `~/.foundry/bin`); stock `forge` cannot run B20 precompiles.
- Agent (Python, uv) and web (Next.js, pnpm) use the Windows-side toolchain.
- Testnet only: base-anvil or Base Sepolia (84532). Never send a mainnet transaction. Secrets only in `.env` (git-ignored).
