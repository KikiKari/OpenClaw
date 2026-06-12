# Generates a rotating 3D GIF of the MCP-OAuth proxy flow.
# Source: assets/gen_mcp_flow_gif.py (+ gen_mcp_flow.py, gen_topology.py).
# Needs cairosvg + Pillow (and libcairo + fonts for SVG text). Build context: repo root.
FROM python:3.12-slim

LABEL org.opencontainers.image.source="https://github.com/KikiKari/OpenClaw" \
      org.opencontainers.image.description="Generates a rotating 3D GIF of the MCP-OAuth proxy flow (assets/gen_mcp_flow_gif.py, cairosvg+Pillow). Output written to /out/mcp-oauth-flow.gif — mount a volume at /out." \
      org.opencontainers.image.licenses="MIT"

RUN apt-get update && apt-get install -y --no-install-recommends \
        libcairo2 fonts-dejavu-core fontconfig \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir cairosvg Pillow

WORKDIR /app
COPY assets/gen_topology.py assets/gen_mcp_flow.py assets/gen_mcp_flow_gif.py ./

# The script writes mcp-oauth-flow.gif next to itself (/app); copy it to /out.
CMD ["sh", "-c", "python3 gen_mcp_flow_gif.py && mkdir -p /out && cp -v /app/mcp-oauth-flow.gif /out/"]
