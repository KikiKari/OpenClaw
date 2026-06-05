# OpenClaw Cluster — Interaktive 3D-Visualisierungen

Dieser Branch (`gh-pages`) liefert die interaktiven 3D-Ansichten des
OpenClaw Clusters über **GitHub Pages**.

🔗 **Live:** https://kikikari.github.io/OpenClaw/

## Seiten

| Seite | Inhalt |
| --- | --- |
| [`index.html`](index.html) | Netzwerk-Topologie — Gateways, Node-Pool 2–8, Docker (drehbar/zoombar) |
| [`mcp-flow.html`](mcp-flow.html) | MCP-OAuth-Proxy Request-Flow — Client → Auth → Router → Perplexity |

Beide Seiten sind über die Navigationsleiste (oben rechts) verknüpft.

## Technik

- [three.js](https://threejs.org/) (ES-Module via CDN) + OrbitControls + CSS2D-Labels
- Statische HTML-Seiten, keine Build-Pipeline (`.nojekyll`)
- Auto-Rotation, pausiert bei Interaktion (Ziehen / Scrollen / Rechtsklick)

## Quelle

Die Diagramme werden im `main`-Branch reproduzierbar erzeugt
(`assets/gen_topology.py`, `assets/gen_mcp_flow.py`).

→ [Haupt-README](../../tree/main#readme)
