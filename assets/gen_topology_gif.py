#!/usr/bin/env python3
"""Generiert ein rotierendes 3D-GIF der OpenClaw-Netzwerk-Topologie.

Rotiert die Szene um die vertikale Achse, rendert jedes Frame als SVG,
konvertiert via cairosvg zu PNG und setzt alles mit Pillow zu einem
Loop-GIF zusammen.

Ausgabe: network-topology.gif im selben Verzeichnis.

Verwendung:
    python3 assets/gen_topology_gif.py          # GIF erzeugen
    python3 assets/gen_topology_gif.py test     # nur ein Testframe als PNG

Abhängigkeiten: cairosvg, Pillow.
"""
import io
import math
import os
import sys

import cairosvg
from PIL import Image

from gen_topology import NODES, LINKS  # gemeinsame Knoten/Verbindungen

C = math.cos(math.radians(30))
S = 0.5
SCALE = 44
FRAMES = 36
FRAME_MS = 80
LIGHT = (-0.40, -0.70, 0.60)  # Lichtrichtung (oben-links-vorne)


def _norm(v):
    m = math.sqrt(sum(c * c for c in v)) or 1.0
    return (v[0] / m, v[1] / m, v[2] / m)


LIGHT = _norm(LIGHT)


def iso(x, y, z=0.0):
    return (x - y) * C * SCALE, ((x + y) * S - z) * SCALE


def rot(x, y, ang, px, py):
    c, s = math.cos(ang), math.sin(ang)
    dx, dy = x - px, y - py
    return px + dx * c - dy * s, py + dx * s + dy * c


def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def shade(dark, light, b):
    d, l = hex2rgb(dark), hex2rgb(light)
    r = [int(d[i] + (l[i] - d[i]) * b) for i in range(3)]
    return "#%02x%02x%02x" % (max(0, min(255, r[0])), max(0, min(255, r[1])), max(0, min(255, r[2])))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


# Pivot = Schwerpunkt der Knotenzentren
PX = sum(n[1] for n in NODES) / len(NODES)
PY = sum(n[2] for n in NODES) / len(NODES)

# Würfel-Flächen als Eckindizes (0-3 unten, 4-7 oben)
FACES = [
    (4, 5, 6, 7),  # oben
    (0, 1, 2, 3),  # unten
    (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7),  # Wände
]


def world_corners(cx, cy, hw, h):
    return [
        (cx - hw, cy - hw, 0), (cx + hw, cy - hw, 0), (cx + hw, cy + hw, 0), (cx - hw, cy + hw, 0),
        (cx - hw, cy - hw, h), (cx + hw, cy - hw, h), (cx + hw, cy + hw, h), (cx - hw, cy + hw, h),
    ]


def frame_svg(ang, view):
    minx, miny, W, H = view
    faces, labels = [], []
    link_pos = {}

    for _id, cx, cy, hw, h, cols, label, sub_ in NODES:
        dark, mid, light = cols  # (top/hell, rechte, linke/dunkel) -> light=cols[0], dark=cols[2]
        light_hex, dark_hex = cols[0], cols[2]
        wc = world_corners(cx, cy, hw, h)
        # rotieren + projizieren
        rc3 = [(*rot(x, y, ang, PX, PY), z) for (x, y, z) in wc]
        rc2 = [iso(x, y, z) for (x, y, z) in rc3]
        ctr = (sum(p[0] for p in rc3) / 8, sum(p[1] for p in rc3) / 8, sum(p[2] for p in rc3) / 8)

        for f in FACES:
            p3 = [rc3[i] for i in f]
            p2 = [rc2[i] for i in f]
            n = _norm(cross(sub(p3[1], p3[0]), sub(p3[3], p3[0])))
            # nach außen orientieren
            fc = (sum(p[0] for p in p3) / 4, sum(p[1] for p in p3) / 4, sum(p[2] for p in p3) / 4)
            out = sub(fc, ctr)
            if sum(n[i] * out[i] for i in range(3)) < 0:
                n = (-n[0], -n[1], -n[2])
            bright = 0.30 + 0.70 * max(0.0, sum(n[i] * LIGHT[i] for i in range(3)))
            depth = fc[0] + fc[1] + fc[2]
            d = " ".join(f"{x:.1f},{y:.1f}" for x, y in p2)
            faces.append((depth, f'<polygon points="{d}" fill="{shade(dark_hex, light_hex, bright)}" '
                                 f'stroke="#0d1117" stroke-width="0.8" stroke-linejoin="round"/>'))

        # Label-Position = projiziertes Deckel-Zentrum
        lc = iso(*rot(cx, cy, ang, PX, PY), h)
        labels.append((ctr[0] + ctr[1] + ctr[2],
                       f'<text x="{lc[0]:.1f}" y="{lc[1]:.1f}" text-anchor="middle" '
                       f'font-family="Segoe UI, Arial, sans-serif" font-size="12.5" '
                       f'font-weight="700" fill="#ffffff" '
                       f'style="paint-order:stroke;stroke:#0d1117;stroke-width:1.2px">{label}</text>'))
        link_pos[_id] = lc

    # Verbindungen (hinter den Flächen)
    svg_links = []
    for a, b, dashed in LINKS:
        x1, y1 = link_pos[a]
        x2, y2 = link_pos[b]
        dash = ' stroke-dasharray="6 5"' if dashed else ""
        col = "#d29922" if dashed else "#8b949e"
        w = 2.4 if dashed else 1.6
        svg_links.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
                         f'stroke="{col}" stroke-width="{w}"{dash} stroke-linecap="round"/>')

    faces.sort(key=lambda t: t[0])      # hinten zuerst
    labels.sort(key=lambda t: t[0])     # nahe Labels zuletzt

    ly0 = miny + 16
    legend = (
        f'<text x="{minx+10:.1f}" y="{ly0:.1f}" font-family="Segoe UI, Arial, sans-serif" '
        f'font-size="13" font-weight="700" fill="#c9d1d9">OpenClaw Cluster — 3D-Topologie</text>'
        f'<text x="{minx+10:.1f}" y="{ly0+17:.1f}" font-family="Segoe UI, Arial, sans-serif" '
        f'font-size="10" fill="#8b949e">Gateways · Node-Pool 2–8 · '
        f'<tspan fill="#d29922">VPN: Tailscale / WireGuard</tspan></text>'
    )

    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{minx:.1f} {miny:.1f} {W:.1f} {H:.1f}" '
        f'width="{W:.0f}" height="{H:.0f}">'
        f'<rect x="{minx:.1f}" y="{miny:.1f}" width="{W:.1f}" height="{H:.1f}" fill="#0d1117"/>'
        f'{legend}'
        + "".join(svg_links)
        + "".join(s for _, s in faces)
        + "".join(s for _, s in labels)
        + "</svg>"
    )


def compute_view(angles):
    xs, ys = [], []
    for ang in angles:
        for _id, cx, cy, hw, h, *_ in NODES:
            for (x, y, z) in world_corners(cx, cy, hw, h):
                rx, ry = rot(x, y, ang, PX, PY)
                sx, sy = iso(rx, ry, z)
                xs.append(sx)
                ys.append(sy)
    pad = 30
    minx, maxx = min(xs) - pad, max(xs) + pad
    miny, maxy = min(ys) - pad - 40, max(ys) + pad
    return (minx, miny, maxx - minx, maxy - miny)


def render_png(svg, scale=1.3):
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), scale=scale))).convert("RGB")


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    angles = [2 * math.pi * i / FRAMES for i in range(FRAMES)]
    view = compute_view(angles)

    if len(sys.argv) > 1 and sys.argv[1] == "test":
        img = render_png(frame_svg(math.radians(35), view), scale=2)
        img.save("/tmp/topo_frame.png")
        print("Testframe: /tmp/topo_frame.png")
    else:
        frames = [render_png(frame_svg(a, view)) for a in angles]
        # gemeinsame Palette für gleichmäßige Farben
        pal = frames[0].quantize(colors=128, method=Image.MEDIANCUT)
        frames_q = [f.quantize(palette=pal, dither=Image.NONE) for f in frames]
        out = os.path.join(here, "network-topology.gif")
        frames_q[0].save(out, save_all=True, append_images=frames_q[1:],
                         duration=FRAME_MS, loop=0, optimize=True, disposal=2)
        kb = os.path.getsize(out) / 1024
        print(f"GIF geschrieben: {out} ({FRAMES} Frames, {kb:.0f} KB)")
