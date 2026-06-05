#!/usr/bin/env python3
"""Generiert ein rotierendes 3D-GIF des MCP-OAuth-Proxy-Flows.

Rotiert die Pipeline um die vertikale Achse, rendert jedes Frame als SVG
(cairosvg) und setzt alles mit Pillow zu einem Loop-GIF zusammen.

Ausgabe: mcp-oauth-flow.gif im selben Verzeichnis.

Verwendung:
    python3 assets/gen_mcp_flow_gif.py          # GIF erzeugen
    python3 assets/gen_mcp_flow_gif.py test     # nur ein Testframe als PNG

Abhängigkeiten: cairosvg, Pillow. Teilt STAGES/ARROWS mit gen_mcp_flow.py.
"""
import io
import math
import os
import sys

import cairosvg
from PIL import Image

from gen_mcp_flow import STAGES, ARROWS

C = math.cos(math.radians(30))
S = 0.5
SCALE = 40
FRAMES = 36
FRAME_MS = 80
ZHI = 1.7  # Höhe des Response-Bogens


def _norm(v):
    m = math.sqrt(sum(c * c for c in v)) or 1.0
    return (v[0] / m, v[1] / m, v[2] / m)


LIGHT = _norm((-0.40, -0.70, 0.60))


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


PX = sum(s[1] for s in STAGES) / len(STAGES)
PY = sum(s[2] for s in STAGES) / len(STAGES)

FACES = [(4, 5, 6, 7), (0, 1, 2, 3), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]


def world_corners(cx, cy, hw, h):
    return [
        (cx - hw, cy - hw, 0), (cx + hw, cy - hw, 0), (cx + hw, cy + hw, 0), (cx - hw, cy + hw, 0),
        (cx - hw, cy - hw, h), (cx + hw, cy - hw, h), (cx + hw, cy + hw, h), (cx - hw, cy + hw, h),
    ]


def frame_svg(ang, view):
    minx, miny, W, H = view
    faces, labels = [], []
    top = {}

    for _id, cx, cy, hw, h, cols, label, sub_ in STAGES:
        light_hex, dark_hex = cols[0], cols[2]
        rc3 = [(*rot(x, y, ang, PX, PY), z) for (x, y, z) in world_corners(cx, cy, hw, h)]
        rc2 = [iso(x, y, z) for (x, y, z) in rc3]
        ctr = (sum(p[0] for p in rc3) / 8, sum(p[1] for p in rc3) / 8, sum(p[2] for p in rc3) / 8)
        for f in FACES:
            p3 = [rc3[i] for i in f]
            p2 = [rc2[i] for i in f]
            n = _norm(cross(sub(p3[1], p3[0]), sub(p3[3], p3[0])))
            fc = (sum(p[0] for p in p3) / 4, sum(p[1] for p in p3) / 4, sum(p[2] for p in p3) / 4)
            out = sub(fc, ctr)
            if sum(n[i] * out[i] for i in range(3)) < 0:
                n = (-n[0], -n[1], -n[2])
            bright = 0.30 + 0.70 * max(0.0, sum(n[i] * LIGHT[i] for i in range(3)))
            d = " ".join(f"{x:.1f},{y:.1f}" for x, y in p2)
            faces.append((fc[0] + fc[1] + fc[2],
                          f'<polygon points="{d}" fill="{shade(dark_hex, light_hex, bright)}" '
                          f'stroke="#0d1117" stroke-width="0.8" stroke-linejoin="round"/>'))
        lc = iso(*rot(cx, cy, ang, PX, PY), h)
        labels.append((ctr[0] + ctr[1] + ctr[2],
                       f'<text x="{lc[0]:.1f}" y="{lc[1]:.1f}" text-anchor="middle" '
                       f'font-family="Segoe UI, Arial, sans-serif" font-size="12" font-weight="700" '
                       f'fill="#fff" style="paint-order:stroke;stroke:#0d1117;stroke-width:1.2px">{label}</text>'))
        top[_id] = (lc, cx, cy, h)

    # Request-Pfeile
    arrows = []
    for a, b, _l in ARROWS:
        (x1, y1), _, _, _ = top[a]
        (x2, y2), _, _, _ = top[b]
        ex, ey = x1 + 0.74 * (x2 - x1), y1 + 0.74 * (y2 - y1)
        arrows.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{ex:.1f}" y2="{ey:.1f}" '
                      f'stroke="#c9d1d9" stroke-width="2" marker-end="url(#a)"/>')

    # Response-Bogen
    (_, pcx, pcy, ph) = top["pplx"]
    (_, ccx, ccy, ch) = top["client"]
    arc = [iso(*rot(pcx, pcy, ang, PX, PY), ph), iso(*rot(pcx, pcy, ang, PX, PY), ZHI),
           iso(*rot(ccx, ccy, ang, PX, PY), ZHI), iso(*rot(ccx, ccy, ang, PX, PY), ch)]
    arc_d = " ".join(f"{x:.1f},{y:.1f}" for x, y in arc)
    response = (f'<polyline points="{arc_d}" fill="none" stroke="#d29922" stroke-width="2" '
                f'stroke-dasharray="6 5" marker-end="url(#g)"/>')

    faces.sort(key=lambda t: t[0])
    labels.sort(key=lambda t: t[0])

    ly0 = miny + 16
    legend = (
        f'<text x="{minx+10:.1f}" y="{ly0:.1f}" font-family="Segoe UI, Arial, sans-serif" '
        f'font-size="13" font-weight="700" fill="#c9d1d9">MCP-OAuth-Proxy — 3D-Flow</text>'
        f'<text x="{minx+10:.1f}" y="{ly0+17:.1f}" font-family="Segoe UI, Arial, sans-serif" '
        f'font-size="10" fill="#8b949e">OAuth 2.1 + PKCE · <tspan fill="#d29922">— — Response</tspan></text>'
    )
    defs = ('<defs>'
            '<marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" '
            'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#c9d1d9"/></marker>'
            '<marker id="g" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" '
            'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#d29922"/></marker></defs>')

    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{minx:.1f} {miny:.1f} {W:.1f} {H:.1f}" '
        f'width="{W:.0f}" height="{H:.0f}">{defs}'
        f'<rect x="{minx:.1f}" y="{miny:.1f}" width="{W:.1f}" height="{H:.1f}" fill="#0d1117"/>{legend}'
        + "".join(s for _, s in faces) + "".join(arrows) + response
        + "".join(s for _, s in labels) + "</svg>"
    )


def compute_view(angles):
    xs, ys = [], []
    for ang in angles:
        for _id, cx, cy, hw, h, *_ in STAGES:
            for (x, y, z) in world_corners(cx, cy, hw, h):
                rx, ry = rot(x, y, ang, PX, PY)
                sx, sy = iso(rx, ry, z)
                xs.append(sx); ys.append(sy)
        for sid in ("pplx", "client"):
            sc = next(s for s in STAGES if s[0] == sid)
            rx, ry = rot(sc[1], sc[2], ang, PX, PY)
            xs.append(iso(rx, ry, ZHI)[0]); ys.append(iso(rx, ry, ZHI)[1])
    pad = 30
    minx, maxx = min(xs) - pad, max(xs) + pad
    miny, maxy = min(ys) - pad - 40, max(ys) + pad
    return (minx, miny, maxx - minx, maxy - miny)


def render_png(svg, scale=1.25):
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), scale=scale))).convert("RGB")


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    angles = [2 * math.pi * i / FRAMES for i in range(FRAMES)]
    view = compute_view(angles)
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        render_png(frame_svg(math.radians(35), view), scale=2).save("/tmp/mcp_frame.png")
        print("Testframe: /tmp/mcp_frame.png")
    else:
        frames = [render_png(frame_svg(a, view)) for a in angles]
        pal = frames[0].quantize(colors=128, method=Image.MEDIANCUT)
        fq = [f.quantize(palette=pal, dither=Image.NONE) for f in frames]
        out = os.path.join(here, "mcp-oauth-flow.gif")
        fq[0].save(out, save_all=True, append_images=fq[1:], duration=FRAME_MS, loop=0, optimize=True, disposal=2)
        print(f"GIF geschrieben: {out} ({FRAMES} Frames, {os.path.getsize(out)/1024:.0f} KB)")
