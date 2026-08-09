#!/usr/bin/env python3
"""Generiert ein isometrisches (2.5D) SVG des MCP-OAuth-Proxy-Flows.

Pipeline: MCP Client → Auth-Middleware → Tool-Router → Perplexity API,
mit gestricheltem Response-Bogen zurück zum Client.

Ausgabe: mcp-oauth-flow.svg im selben Verzeichnis.

Verwendung:
    python3 assets/gen_mcp_flow.py

Teilt iso()/box_polys()/Farbpalette mit gen_topology.py.
"""
import os

from gen_topology import iso, box_polys, BLUE, GREEN, PURPLE, ORANGE

# Pipeline-Stufen: (id, cx, cy, halbbreite, höhe, farben, label, sublabel)
STAGES = [
    ("client", 0.0, 1.2, 0.80, 0.55, BLUE,   "MCP Client",     "ChatGPT · Claude · VSC"),
    ("auth",   3.0, 1.2, 0.80, 0.70, GREEN,  "Auth-Middleware", "JWT RS256"),
    ("router", 6.0, 1.2, 0.80, 0.62, PURPLE, "Tool-Router",    "tools/call"),
    ("pplx",   9.0, 1.2, 0.80, 0.55, ORANGE, "Perplexity API", "ask·search·research"),
]

# Request-Pfeile (solide) mit Beschriftung
ARROWS = [
    ("client", "auth", "POST /mcp"),
    ("auth", "router", "validiert"),
    ("router", "pplx", "Key (.env)"),
]


def build_svg():
    pos = {s[0]: (s[1], s[2], s[4]) for s in STAGES}

    # Boxen: hinten (kleines x) zuerst
    svg_boxes, svg_labels = [], []
    for _id, cx, cy, hw, h, cols, label, sub in sorted(STAGES, key=lambda s: s[1] + s[2]):
        polys, (lx, ly) = box_polys(cx, cy, hw, h, *cols)
        svg_boxes.extend(polys)
        svg_labels.append(
            f'<text x="{lx:.1f}" y="{ly-3:.1f}" text-anchor="middle" '
            f'font-family="Segoe UI, Arial, sans-serif" font-size="12.5" '
            f'font-weight="700" fill="#ffffff">{label}</text>'
        )
        svg_labels.append(
            f'<text x="{lx:.1f}" y="{ly+10:.1f}" text-anchor="middle" '
            f'font-family="Segoe UI, Arial, sans-serif" font-size="9" '
            f'fill="#eaeef2">{sub}</text>'
        )

    # Request-Pfeile (auf 72 % gekürzt, damit die Spitze in der Lücke sichtbar bleibt)
    svg_arrows = []
    for a, b, _lbl in ARROWS:
        ax, ay, ah = pos[a]
        bx, by, bh = pos[b]
        x1, y1 = iso(ax, ay, ah)
        x2, y2 = iso(bx, by, bh)
        ex, ey = x1 + 0.72 * (x2 - x1), y1 + 0.72 * (y2 - y1)
        svg_arrows.append(
            f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{ex:.1f}" y2="{ey:.1f}" '
            f'stroke="#c9d1d9" stroke-width="2" marker-end="url(#arrow)"/>'
        )

    # Response-Bogen (gestrichelt, über die Pipeline zurück zum Client)
    px, py, ph = pos["pplx"]
    cx0, cy0, ch = pos["client"]
    zhi = 1.7
    arc = [iso(px, py, ph), iso(px, py, zhi), iso(cx0, cy0, zhi), iso(cx0, cy0, ch)]
    arc_d = " ".join(f"{x:.1f},{y:.1f}" for x, y in arc)
    rmx, rmy = iso((px + cx0) / 2, py, zhi)
    svg_response = (
        f'<polyline points="{arc_d}" fill="none" stroke="#d29922" stroke-width="2" '
        f'stroke-dasharray="6 5" marker-end="url(#arrowg)"/>'
        f'<text x="{rmx:.1f}" y="{rmy-6:.1f}" text-anchor="middle" '
        f'font-family="Segoe UI, Arial, sans-serif" font-size="9" font-weight="600" '
        f'fill="#d29922">Response</text>'
    )

    # Bounding-Box
    pts = []
    for _id, cx, cy, hw, h, *_ in STAGES:
        for dx in (-hw, hw):
            for dy in (-hw, hw):
                pts.append(iso(cx + dx, cy + dy, 0))
                pts.append(iso(cx + dx, cy + dy, h))
    pts.append(iso(0.0, 1.2, zhi))
    pts.append(iso(9.0, 1.2, zhi))
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    pad = 34
    minx, maxx = min(xs) - pad, max(xs) + pad
    miny, maxy = min(ys) - pad - 44, max(ys) + pad
    W, H = maxx - minx, maxy - miny

    ly0 = miny + 16
    legend = (
        f'<text x="{minx+10:.1f}" y="{ly0:.1f}" font-family="Segoe UI, Arial, sans-serif" '
        f'font-size="13" font-weight="700" fill="#c9d1d9">MCP-OAuth-Proxy — Request-Flow</text>'
        f'<text x="{minx+10:.1f}" y="{ly0+18:.1f}" font-family="Segoe UI, Arial, sans-serif" '
        f'font-size="10" fill="#8b949e">OAuth 2.1 + PKCE · '
        f'<tspan fill="#d29922">— — Response</tspan></text>'
    )

    defs = (
        '<defs>'
        '<marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" '
        'markerHeight="6" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#c9d1d9"/></marker>'
        '<marker id="arrowg" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" '
        'markerHeight="6" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#d29922"/></marker>'
        '</defs>'
    )

    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{minx:.1f} {miny:.1f} {W:.1f} {H:.1f}" '
        f'width="{W:.0f}" height="{H:.0f}" role="img" '
        f'aria-label="Isometrischer 3D-Request-Flow des MCP-OAuth-Proxy">\n'
        f'  {defs}\n'
        f'  <rect x="{minx:.1f}" y="{miny:.1f}" width="{W:.1f}" height="{H:.1f}" fill="#0d1117" rx="8"/>\n'
        f'  {legend}\n  '
        + "\n  ".join(svg_boxes) + "\n  "
        + "\n  ".join(svg_arrows) + "\n  "
        + svg_response + "\n  "
        + "\n  ".join(svg_labels) + "\n</svg>\n"
    )


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mcp-oauth-flow.svg")
    with open(out, "w", encoding="utf-8") as f:
        f.write(build_svg())
    print(f"SVG geschrieben: {out} ({len(STAGES)} Stufen, {len(ARROWS)} Request-Pfeile)")
