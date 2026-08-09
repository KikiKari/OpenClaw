# Generates an isometric (2.5D) SVG of the MCP-OAuth proxy flow.
# Source: assets/gen_mcp_flow.py (+ assets/gen_topology.py). Pure Python, no deps.
# Build context: repository root.
FROM python:3.12-slim

LABEL org.opencontainers.image.source="https://github.com/KikiKari/OpenClaw" \
      org.opencontainers.image.description="Generates an isometric (2.5D) SVG of the MCP-OAuth proxy flow (assets/gen_mcp_flow.py). Output written to /out/mcp-oauth-flow.svg — mount a volume at /out." \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app
COPY assets/gen_topology.py assets/gen_mcp_flow.py ./

# The script writes mcp-oauth-flow.svg next to itself (/app); copy it to /out.
CMD ["sh", "-c", "python3 gen_mcp_flow.py && mkdir -p /out && cp -v /app/mcp-oauth-flow.svg /out/"]
