# mcp-flow-gif (container package)

Generates a **rotating 3D GIF** of the MCP-OAuth proxy flow — rotates the pipeline
about the vertical axis, renders each frame as SVG via `cairosvg`, and assembles a
loop GIF with Pillow. Source:
[`assets/gen_mcp_flow_gif.py`](https://github.com/KikiKari/OpenClaw/blob/main/assets/gen_mcp_flow_gif.py).

## Pull
```bash
docker pull ghcr.io/kikikari/mcp-flow-gif:latest
```

## Use
```bash
# Writes mcp-oauth-flow.gif into the mounted ./out directory (36 frames, loop)
docker run --rm -v "$PWD/out":/out ghcr.io/kikikari/mcp-flow-gif:latest
```

Output: `out/mcp-oauth-flow.gif`.

Bundled deps: `cairosvg`, `Pillow`, `libcairo2`, DejaVu fonts.
Docs: [gh-pages README](https://github.com/KikiKari/OpenClaw/blob/gh-pages/README.md) ·
sources in [`assets/`](https://github.com/KikiKari/OpenClaw/tree/main/assets).
