# OpenClaw — Codespace Infrastructure

This branch (`special-engine`) is part of the **OpenClaw Cluster** GitHub infrastructure.
It was built and optimized using [Claude Code](https://claude.ai/code) and serves as the
React/Vite frontend client and package distribution layer.

→ Main repository: [KikiKari/OpenClaw](https://github.com/KikiKari/OpenClaw)

---

## Codespace Architecture

OpenClaw uses two dedicated GitHub Codespaces for development and infrastructure:

### verbose-waddle · `KikiKari/OpenClaw`
> GitHub Infrastructure · Main Default · Sandbox

- **Origin:** Created directly from `KikiKari/OpenClaw` (2-core · 8GB RAM)
- **Role:** Sets up and maintains the `main` default branch — the authoritative
  source for repository structure, documentation, gateway configs, and agent rules
- **Contains:** MCP configurations, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`,
  gateway branch management, and security policies
- **Sandbox:** Used for testing new repository structures before merging to `main`

### special-engine · `github/codespaces-react` (this branch)
> Claude Code · GitHub Optimization · Interpolation

- **Origin:** Created from `github/codespaces-react` template (4-core · 16GB RAM)
- **Role:** Claude Code-driven GitHub optimization — builds the frontend client,
  publishes packages, generates GitHub Actions workflows, and interpolates between
  the OpenClaw branches and external package registries
- **Contains:** React/Vite frontend, npm package, Docker image, multi-language
  code examples, CI/CD pipeline definitions

---

## Published Packages

| Package | Registry | Description |
|---|---|---|
| `@kikikari/openclaw-client` | [GitHub Packages (npm)](https://github.com/KikiKari/OpenClaw/packages) | React/JS frontend client |
| `openclaw-py` | [PyPI](https://pypi.org/project/openclaw-py) | Python gateway client library |
| `ghcr.io/kikikari/openclaw` | [GitHub Container Registry](https://github.com/KikiKari/OpenClaw/pkgs/container/openclaw) | Docker image |

---

## Docker

```bash
docker pull ghcr.io/kikikari/openclaw:main

docker run -p 8080:8080 ghcr.io/kikikari/openclaw:main
```

---

## npm

```bash
npm install @kikikari/openclaw-client
```

```js
import { GatewayClient, ClusterManager } from '@kikikari/openclaw-client';

const cluster = new ClusterManager([
  'http://gateway1.openclaw.internal',
  'http://gateway2.openclaw.internal',
]);

const status = await cluster.healthCheck();
```

---

## Development

```bash
npm install
npm start      # Dev server on http://localhost:3000
npm run build  # Production build
npm test       # Run tests
```

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