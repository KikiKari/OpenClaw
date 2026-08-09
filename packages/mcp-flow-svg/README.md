# mcp-flow-svg (container package)

Generates an **isometric (2.5D) SVG** of the MCP-OAuth proxy flow
(MCP Client → Auth-Middleware → Tool-Router → Perplexity API), from
[`assets/gen_mcp_flow.py`](https://github.com/KikiKari/OpenClaw/blob/main/assets/gen_mcp_flow.py).
Pure Python — no external dependencies.

## Pull
```bash
docker pull ghcr.io/kikikari/mcp-flow-svg:latest
```

## Use
```bash
# Writes mcp-oauth-flow.svg into the mounted ./out directory
docker run --rm -v "$PWD/out":/out ghcr.io/kikikari/mcp-flow-svg:latest
```

Output: `out/mcp-oauth-flow.svg`.

Docs: [gh-pages README](https://github.com/KikiKari/OpenClaw/blob/gh-pages/README.md) ·
sources in [`assets/`](https://github.com/KikiKari/OpenClaw/tree/main/assets).
