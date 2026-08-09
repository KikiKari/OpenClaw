#!/usr/bin/env python3
"""Generiert ein isometrisches (2.5D) SVG der OpenClaw-Netzwerk-Topologie.

Ausgabe: network-topology.svg im selben Verzeichnis wie dieses Skript.

Verwendung:
    python3 assets/gen_topology.py

Keine externen Abhängigkeiten (nur Standardbibliothek).
"""
import math
import os

C = math.cos(math.radians(30))
S = 0.5
SCALE = 46

# Farbpaletten (top, rechte Wand, linke Wand)
BLUE = ("#4c9aff", "#2f80ed", "#1b5fc0")
GREEN = ("#57d38c", "#2ea043", "#1f7a34")
PURPLE = ("#b88cf0", "#8957e5", "#6a3fc0")
ORANGE = ("#f0b352", "#d29922", "#a8761a")

# Knoten: (id, cx, cy, halbbreite, höhe, farben, label, sublabel)
NODES = [
    ("net", 0.4, 0.4, 0.55, 0.45, BLUE, "Internet", ""),
    ("gw1", 3.0, 1.0, 0.75, 0.65, GREEN, "Gateway 1", ""),
    ("gw2", 1.0, 3.0, 0.75, 0.65, GREEN, "Gateway 2", ""),
    ("n2", 5.0, 2.0, 0.65, 0.55, PURPLE, "Node 2", "Worker"),
    ("n36", 3.5, 3.5, 0.65, 0.55, PURPLE, "Node 3–6", "Worker"),
    ("n78", 2.0, 5.0, 0.65, 0.55, PURPLE, "Node 7–8", "Docker"),
    ("dock", 4.5, 4.5, 0.7, 0.5, ORANGE, "Docker", "Heavy Jobs"),
]

# Verbindungen: (von, nach, gestrichelt)
LINKS = [
    ("net", "gw1", False), ("net", "gw2", False),
    ("gw1", "gw2", True),
    ("gw1", "n2", False), ("gw1", "n36", False),
    ("gw2", "n78", False), ("gw2", "n36", False),
    ("n2", "dock", False), ("n78", "dock", False),
]


def iso(x, y, z=0.0):
    """Isometrische Projektion (2:1-Dimetrie) eines 3D-Punkts auf 2D."""
    sx = (x - y) * C * SCALE
    sy = ((x + y) * S - z) * SCALE
    return sx, sy


def box_polys(cx, cy, hw, h, top, right, left):
    """Liefert die drei SVG-Polygone (links, rechts, oben) eines Quaders."""
    t = [iso(cx - hw, cy - hw, h), iso(cx + hw, cy - hw, h),
         iso(cx + hw, cy + hw, h), iso(cx - hw, cy + hw, h)]
    r = [iso(cx + hw, cy - hw, 0), iso(cx + hw, cy + hw, 0),
         iso(cx + hw, cy + hw, h), iso(cx + hw, cy - hw, h)]
    l = [iso(cx - hw, cy + hw, 0), iso(cx + hw, cy + hw, 0),
         iso(cx + hw, cy + hw, h), iso(cx - hw, cy + hw, h)]

    def poly(pts, fill):
        d = " ".join(f"{px:.1f},{py:.1f}" for px, py in pts)
        return (f'<polygon points="{d}" fill="{fill}" stroke="#0d1117" '
                f'stroke-width="1" stroke-linejoin="round"/>')

    return [poly(l, left), poly(r, right), poly(t, top)], iso(cx, cy, h)


def build_svg():
    pos = {n[0]: (n[1], n[2], n[4]) for n in NODES}

    svg_links = []
    for a, b, dashed in LINKS:
        ax, ay, ah = pos[a]
        bx, by, bh = pos[b]
        x1, y1 = iso(ax, ay, ah)
        x2, y2 = iso(bx, by, bh)
        dash = ' stroke-dasharray="6 5"' if dashed else ""
        col = "#d29922" if dashed else "#8b949e"
        w = 2.4 if dashed else 1.8
        svg_links.append(
            f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
            f'stroke="{col}" stroke-width="{w}"{dash} stroke-linecap="round"/>'
        )

    # Painter's Algorithmus: hinten (kleines x+y) zuerst zeichnen
    svg_boxes, svg_labels = [], []
    for _id, cx, cy, hw, h, cols, label, sub in sorted(NODES, key=lambda n: n[1] + n[2]):
        polys, (lx, ly) = box_polys(cx, cy, hw, h, *cols)
        svg_boxes.extend(polys)
        svg_labels.append(
            f'<text x="{lx:.1f}" y="{ly-3:.1f}" text-anchor="middle" '
            f'font-family="Segoe UI, Arial, sans-serif" font-size="13" '
            f'font-weight="700" fill="#ffffff">{label}</text>'
        )
        if sub:
            svg_labels.append(
                f'<text x="{lx:.1f}" y="{ly+11:.1f}" text-anchor="middle" '
                f'font-family="Segoe UI, Arial, sans-serif" font-size="9.5" '
                f'fill="#eaeef2">{sub}</text>'
            )

    gx1, gy1, gh1 = pos["gw1"]
    gx2, gy2, gh2 = pos["gw2"]
    vx, vy = iso((gx1 + gx2) / 2, (gy1 + gy2) / 2, gh1 + 0.55)
    vpn_label = (
        f'<text x="{vx:.1f}" y="{vy:.1f}" text-anchor="middle" '
        f'font-family="Segoe UI, Arial, sans-serif" font-size="9.5" font-weight="600" '
        f'fill="#d29922">VPN</text>'
    )

    # Bounding-Box
    pts = []
    for _id, cx, cy, hw, h, *_ in NODES:
        for dx in (-hw, hw):
            for dy in (-hw, hw):
                pts.append(iso(cx + dx, cy + dy, 0))
                pts.append(iso(cx + dx, cy + dy, h))
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    pad = 34
    minx, maxx = min(xs) - pad, max(xs) + pad
    miny, maxy = min(ys) - pad - 44, max(ys) + pad
    W, H = maxx - minx, maxy - miny

    ly0 = miny + 16
    legend = (
        f'<text x="{minx+10:.1f}" y="{ly0:.1f}" font-family="Segoe UI, Arial, sans-serif" '
        f'font-size="13" font-weight="700" fill="#c9d1d9">OpenClaw Cluster — Netzwerk-Topologie</text>'
        f'<text x="{minx+10:.1f}" y="{ly0+18:.1f}" font-family="Segoe UI, Arial, sans-serif" '
        f'font-size="10" fill="#8b949e">Beide Gateways nutzen Node-Pool 2–8 · '
        f'<tspan fill="#d29922">— — Tailscale / WireGuard</tspan></text>'
    )

    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{minx:.1f} {miny:.1f} {W:.1f} {H:.1f}" '
        f'width="{W:.0f}" height="{H:.0f}" role="img" '
        f'aria-label="Isometrische 3D-Netzwerk-Topologie des OpenClaw Clusters">\n'
        f'  <rect x="{minx:.1f}" y="{miny:.1f}" width="{W:.1f}" height="{H:.1f}" fill="#0d1117" rx="8"/>\n'
        f'  {legend}\n  '
        + "\n  ".join(svg_links) + "\n  "
        + "\n  ".join(svg_boxes) + "\n  "
        + vpn_label + "\n  "
        + "\n  ".join(svg_labels) + "\n</svg>\n"
    )


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "network-topology.svg")
    with open(out, "w", encoding="utf-8") as f:
        f.write(build_svg())
    print(f"SVG geschrieben: {out} ({len(NODES)} Knoten, {len(LINKS)} Verbindungen)")
