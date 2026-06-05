#!/usr/bin/env python3
"""Generiert ein isometrisches (2.5D) SVG des coding-agent-Flows.

Flow: Project Board → Gateway 1 & Gateway 2 (coding-agent) → Pull Requests,
mit Codex-Migration (gestrichelt) und Review-Rückkopplung (Bogen) zum Board.

Ausgabe: codeflow.svg im selben Verzeichnis.

Verwendung:
    python3 assets/gen_codeflow.py

Teilt iso()/box_polys()/Farbpalette mit gen_topology.py.
"""
import os

from gen_topology import iso, box_polys, BLUE, GREEN, PURPLE, ORANGE

# Blöcke: (id, cx, cy, halbbreite, höhe, farben, label, sublabel)
NODES = [
    ("board", 0.3, 0.3, 0.80, 0.48, BLUE,   "Project Board",  "Kanban"),
    ("gw1",   3.0, 1.1, 0.74, 0.58, GREEN,  "Gateway 1",      "coding-agent"),
    ("gw2",   1.1, 3.0, 0.74, 0.58, GREEN,  "Gateway 2",      "coding-agent"),
    ("codex", 3.4, 3.4, 0.66, 0.46, PURPLE, "Codex CLI",      "migriert"),
    ("pr",    5.2, 5.2, 0.80, 0.48, ORANGE, "Pull Requests",  "Commits"),
]

SOLID = [("board", "gw1"), ("board", "gw2"), ("gw1", "pr"), ("gw2", "pr")]
DASHED = [("codex", "gw1"), ("codex", "gw2")]  # Codex-Migration
ZHI = 1.8  # Höhe des Review-Bogens


def build_svg():
    pos = {n[0]: (n[1], n[2], n[4]) for n in NODES}

    # Verbindungen (hinter den Boxen)
    links = []
    for a, b in SOLID:
        ax, ay, ah = pos[a]; bx, by, bh = pos[b]
        x1, y1 = iso(ax, ay, ah); x2, y2 = iso(bx, by, bh)
        ex, ey = x1 + 0.74 * (x2 - x1), y1 + 0.74 * (y2 - y1)
        links.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{ex:.1f}" y2="{ey:.1f}" '
                     f'stroke="#c9d1d9" stroke-width="2" marker-end="url(#arrow)"/>')
    for a, b in DASHED:
        ax, ay, ah = pos[a]; bx, by, bh = pos[b]
        x1, y1 = iso(ax, ay, ah); x2, y2 = iso(bx, by, bh)
        links.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
                     f'stroke="#8957e5" stroke-width="1.8" stroke-dasharray="5 4" stroke-linecap="round"/>')

    # Boxen: hinten (kleines x+y) zuerst
    svg_boxes, svg_labels = [], []
    for _id, cx, cy, hw, h, cols, label, sub in sorted(NODES, key=lambda n: n[1] + n[2]):
        polys, (lx, ly) = box_polys(cx, cy, hw, h, *cols)
        svg_boxes.extend(polys)
        svg_labels.append(f'<text x="{lx:.1f}" y="{ly-3:.1f}" text-anchor="middle" '
                          f'font-family="Segoe UI, Arial, sans-serif" font-size="12" '
                          f'font-weight="700" fill="#ffffff">{label}</text>')
        svg_labels.append(f'<text x="{lx:.1f}" y="{ly+10:.1f}" text-anchor="middle" '
                          f'font-family="Segoe UI, Arial, sans-serif" font-size="9" '
                          f'fill="#eaeef2">{sub}</text>')

    # Review-Bogen (gestrichelt, von PR seitlich ausschwingend zurück zum Board)
    px, py, ph = pos["pr"]; bx, by, bh = pos["board"]
    arc = [iso(px, py, ph), iso(px + 1.4, py - 1.4, ZHI),
           iso(bx + 1.4, by - 1.4, ZHI), iso(bx, by, bh)]
    arc_d = " ".join(f"{x:.1f},{y:.1f}" for x, y in arc)
    rmx, rmy = iso((px + bx) / 2 + 1.4, (py + by) / 2 - 1.4, ZHI)
    response = (f'<polyline points="{arc_d}" fill="none" stroke="#d29922" stroke-width="2" '
                f'stroke-dasharray="6 5" marker-end="url(#arrowg)"/>'
                f'<text x="{rmx:.1f}" y="{rmy-6:.1f}" text-anchor="middle" '
                f'font-family="Segoe UI, Arial, sans-serif" font-size="9" font-weight="600" '
                f'fill="#d29922">Review</text>')

    # Bounding-Box
    pts = []
    for _id, cx, cy, hw, h, *_ in NODES:
        for dx in (-hw, hw):
            for dy in (-hw, hw):
                pts.append(iso(cx + dx, cy + dy, 0)); pts.append(iso(cx + dx, cy + dy, h))
    pts.append(iso(pos["pr"][0] + 1.4, pos["pr"][1] - 1.4, ZHI))
    pts.append(iso(pos["board"][0] + 1.4, pos["board"][1] - 1.4, ZHI))
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    pad = 34
    minx, maxx = min(xs) - pad, max(xs) + pad
    miny, maxy = min(ys) - pad - 44, max(ys) + pad
    W, H = maxx - minx, maxy - miny

    ly0 = miny + 16
    legend = (
        f'<text x="{minx+10:.1f}" y="{ly0:.1f}" font-family="Segoe UI, Arial, sans-serif" '
        f'font-size="13" font-weight="700" fill="#c9d1d9">coding-agent — Board → Gateways → PR</text>'
        f'<text x="{minx+10:.1f}" y="{ly0+18:.1f}" font-family="Segoe UI, Arial, sans-serif" '
        f'font-size="10" fill="#8b949e">'
        f'<tspan fill="#8957e5">— — Codex-Migration</tspan> · '
        f'<tspan fill="#d29922">— — Review</tspan></text>'
    )
    defs = (
        '<defs>'
        '<marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" '
        'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#c9d1d9"/></marker>'
        '<marker id="arrowg" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" '
        'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#d29922"/></marker>'
        '</defs>'
    )

    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{minx:.1f} {miny:.1f} {W:.1f} {H:.1f}" '
        f'width="{W:.0f}" height="{H:.0f}" role="img" '
        f'aria-label="Isometrischer 3D-Flow des coding-agent: Board, Gateways, Pull Requests">\n'
        f'  {defs}\n'
        f'  <rect x="{minx:.1f}" y="{miny:.1f}" width="{W:.1f}" height="{H:.1f}" fill="#0d1117" rx="8"/>\n'
        f'  {legend}\n  '
        + "\n  ".join(svg_boxes) + "\n  "
        + "\n  ".join(links) + "\n  "
        + response + "\n  "
        + "\n  ".join(svg_labels) + "\n</svg>\n"
    )


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "codeflow.svg")
    with open(out, "w", encoding="utf-8") as f:
        f.write(build_svg())
    print(f"SVG geschrieben: {out} ({len(NODES)} Blöcke)")
