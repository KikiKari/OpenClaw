# OpenClaw — Codespace Infrastructure

This branch (`verbose-waddle`) is part of the **OpenClaw Cluster** GitHub infrastructure.
It was built and optimized using [Claude Code](https://claude.ai/code) and serves as the
GitHub infrastructure setup and the maintenance base for the `main` default branch —
repository structure, documentation, gateway configs, and agent rules.

→ Main repository: [KikiKari/OpenClaw](https://github.com/KikiKari/OpenClaw)

---

## Codespace Architecture

OpenClaw uses two dedicated GitHub Codespaces for development and infrastructure:

### verbose-waddle · `KikiKari/OpenClaw` (this branch)
> GitHub Infrastructure · Main Default · Sandbox

- **Origin:** Created directly from `KikiKari/OpenClaw` (2-core · 8GB RAM)
- **Role:** Sets up and maintains the `main` default branch — the authoritative
  source for repository structure, documentation, gateway configs, and agent rules
- **Contains:** MCP configurations, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`,
  gateway branch management, security policies, and maintenance scripts
- **Sandbox:** Used for testing new repository structures before merging to `main`

### special-engine · `github/codespaces-react`
> Claude Code · GitHub Optimization · Interpolation

- **Origin:** Created from `github/codespaces-react` template (4-core · 16GB RAM)
- **Role:** Claude Code-driven GitHub optimization — builds the frontend client,
  publishes packages, generates GitHub Actions workflows, and interpolates between
  the OpenClaw branches and external package registries
- **Contains:** React/Vite frontend, npm package, Docker image, multi-language
  code examples, CI/CD pipeline definitions

---

## Maintenance & Scripts

verbose-waddle maintains the `main` README and repository structure. Helper scripts
live in [`scripts/`](https://github.com/KikiKari/OpenClaw/tree/main/scripts) on `main`:

| Script | Purpose |
|---|---|
| `update_readme_stats.py` | Refreshes the badge / stat counts in the `main` README |
| `pplx-tools/` | Authenticate the Perplexity MCP daemon as **Pro** in a headless Codespace via session-cookie injection (no browser/Cloudflare login) |

```bash
# Refresh README stats on main
python3 scripts/update_readme_stats.py

# Re-authenticate the Perplexity MCP session (see scripts/pplx-tools/README.md)
scripts/pplx-tools/pplx-refresh.sh
```

---

## Published Packages

Cluster artifacts are built and distributed from the `special-engine` branch:

| Package | Registry | Description |
|---|---|---|
| `@kikikari/openclaw-client` | [GitHub Packages (npm)](https://github.com/KikiKari/OpenClaw/packages) | React/JS frontend client |
| `openclaw-py` | [PyPI](https://pypi.org/project/openclaw-py) | Python gateway client library |
| `ghcr.io/kikikari/openclaw` | [GitHub Container Registry](https://github.com/KikiKari/OpenClaw/pkgs/container/openclaw) | Docker image |

---

## Branch Overview

| Branch | Description |
|---|---|
| `main` | Documentation, security policies, gateway structure |
| `gateway1` / `gateway2` | Gateway node configurations |
| `gateway1-abstractions` / `gateway2-abstractions` | Abstraction layers |
| `gh-pages` | GitHub Pages — [kikikari.github.io/OpenClaw](https://kikikari.github.io/OpenClaw/) |
| `verbose-waddle` | GitHub infrastructure setup & sandbox |
| `special-engine` | Claude Code frontend & package distribution |
