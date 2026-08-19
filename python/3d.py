#!/usr/bin/env python3
# 3d.js — portiert nach python
# Quelle: javascript, Projects@abstractions:javascript/3d.js
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# -*- coding: utf-8 -*-
"""
3d.html — portiert nach python
Quelle: html, Projects@tagesstatus-live-public:public/3d.html
Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py
"""

import sys
import math
from PIL import Image, ImageDraw, ImageFont
import numpy as np

# Globale Variablen für das DOM-ähnliche Verhalten
document = None
window = None
navigator = None

class HTMLElement:
    def __init__(self, tag_name):
        self.tag_name = tag_name
        self.attributes = {}
        self.children = []
        self.textContent = ""
        self.innerHTML = ""
        self.className = ""
        self.id = ""
        self.style = {}
    
    def setAttribute(self, name, value):
        self.attributes[name] = value
    
    def appendChild(self, child):
        self.children.append(child)
    
    def outerHTML(self):
        attrs = "".join([f' {k}="{v}"' for k, v in self.attributes.items()])
        if self.tag_name in ['meta', 'link', 'img', 'br', 'hr']:
            return f"<{self.tag_name}{attrs}>"
        
        content = self.textContent or self.innerHTML or "".join([c.outerHTML() for c in self.children])
        return f"<{self.tag_name}{attrs}>{content}</{self.tag_name}>"

class Document:
    def __init__(self):
        self.documentElement = HTMLElement('html')
        self.head = HTMLElement('head')
        self.body = HTMLElement('body')
        self.documentElement.appendChild(self.head)
        self.documentElement.appendChild(self.body)
    
    def createElement(self, tag_name):
        return HTMLElement(tag_name)
    
    def getElementById(self, element_id):
        # Simple implementation for known IDs
        elements = {
            'buehne': self.buehne_element,
            'btn-plus': self.btn_plus,
            'btn-minus': self.btn_minus,
            'btn-reset': self.btn_reset,
            'btn-iso': self.btn_iso,
            'k-name': self.k_name,
            'k-sub': self.k_sub,
            'k-schicht': self.k_schicht,
            'k-id': self.k_id,
            'btn-prev': self.btn_prev,
            'btn-next': self.btn_next,
            'legende': self.legende
        }
        return elements.get(element_id)
    
    def createDocument(self):
        html = self.documentElement
        html.setAttribute('lang', 'de')

        # Head-Bereich
        head = self.head

        # Meta-Tags
        metaCharset = self.createElement('meta')
        metaCharset.setAttribute('charset', 'utf-8')
        head.appendChild(metaCharset)

        metaViewport = self.createElement('meta')
        metaViewport.setAttribute('name', 'viewport')
        metaViewport.setAttribute('content', 'width=device-width, initial-scale=1')
        head.appendChild(metaViewport)

        title = self.createElement('title')
        title.textContent = 'Tagesstatus Live Public — Interaktive Architektur'
        head.appendChild(title)

        metaDescription = self.createElement('meta')
        metaDescription.setAttribute('name', 'description')
        metaDescription.setAttribute('content', 'Acht Dienste, ein Blick: Tokens, Abruf, Kacheln — drehen, zoomen, Knoten auswählen.')
        head.appendChild(metaDescription)

        metaThemeColor = self.createElement('meta')
        metaThemeColor.setAttribute('name', 'theme-color')
        metaThemeColor.setAttribute('content', '#0f766e')
        head.appendChild(metaThemeColor)

        # Styles
        style = self.createElement('style')
        style.textContent = '''
  :root{
    --bg:#fbfaf7; --panel:#fff; --line:#e6e3dc; --text:#16191d; --muted:#5f6773;
    --ac:#0f766e; --buehne:#0e1420; --buehne-line:#1d2739;
    color-scheme: light;
  }
  @media (prefers-color-scheme: dark){
    :root{ --bg:#0f1115; --panel:#171a21; --line:#262b36; --text:#f2f4f8; --muted:#9aa3b2;
           color-scheme: dark; }
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--text);
       font:15px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
  .wrap{max-width:1240px;margin:0 auto;padding:34px 22px 60px}
  .technik{font-size:12px;font-weight:700;letter-spacing:.1em;text-transform:uppercase;
           color:var(--ac);margin:0 0 10px}
  h1{font-size:clamp(30px,5vw,52px);line-height:1.05;margin:0 0 14px;letter-spacing:-.03em}
  .lede{font-size:16.5px;color:var(--muted);max-width:62ch;margin:0 0 26px}
  .raster{display:grid;grid-template-columns:minmax(0,1fr) 288px;gap:18px;align-items:start}
  @media (max-width:880px){ .raster{grid-template-columns:1fr} }
  .buehne{position:relative;background:var(--buehne);border-radius:14px;overflow:hidden;
          min-height:520px;aspect-ratio:16/11}
  .buehne canvas{display:block;width:100%;height:100%}
  .knoepfe{position:absolute;top:14px;right:14px;display:flex;gap:8px;z-index:2}
  button{font:inherit;font-size:14px;font-weight:650;padding:9px 14px;border-radius:9px;
         border:1px solid var(--line);background:var(--panel);color:var(--text);cursor:pointer}
  button:hover{border-color:var(--ac)}
  button[aria-pressed="true"]{background:var(--ac);border-color:var(--ac);color:#fff}
  .karte{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:20px}
  .karte h2{font-size:11px;font-weight:700;letter-spacing:.09em;text-transform:uppercase;
            color:var(--muted);margin:0 0 12px}
  .karte h3{font-size:23px;margin:0 0 4px;letter-spacing:-.02em}
  .karte .sub{color:var(--muted);margin:0 0 18px;font-size:14.5px}
  .feld{border-top:1px solid var(--line);padding:12px 0 0;margin:0 0 12px}
  .feld dt{font-size:11px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;
           color:var(--muted);margin:0 0 3px}
  .feld dd{margin:0;font-weight:650}
  .blaettern{display:flex;gap:8px;margin-top:16px}
  .blaettern button{flex:1;text-align:center;line-height:1.25;padding:11px 8px}
  .legende{display:flex;gap:22px;flex-wrap:wrap;margin:16px 0 0;font-size:13.5px;color:var(--muted)}
  .legende span{display:inline-flex;align-items:center;gap:9px}
  .strich{width:30px;height:0;border-top-width:3px;border-top-style:solid;display:inline-block}
  .fuss{margin:14px 0 0;font-size:13px;color:var(--muted);max-width:80ch}
  .fehler{padding:40px;text-align:center;color:var(--muted)}
  a{color:var(--ac)}
'''
        head.appendChild(style)

        # Body-Bereich
        body = self.body

        # Wrap container
        wrap = self.createElement('div')
        wrap.className = 'wrap'

        # Technik
        technik = self.createElement('p')
        technik.className = 'technik'
        technik.textContent = 'three.js · r128'
        wrap.appendChild(technik)

        # Überschrift
        h1 = self.createElement('h1')
        h1.textContent = 'Tagesstatus Live Public'
        wrap.appendChild(h1)

        # Lede
        lede = self.createElement('p')
        lede.className = 'lede'
        lede.textContent = 'Acht Dienste, ein Blick: Tokens, Abruf, Kacheln — drehen, zoomen, Knoten auswählen.'
        wrap.appendChild(lede)

        # Raster
        raster = self.createElement('div')
        raster.className = 'raster'

        # Bühne
        buehne = self.createElement('div')
        buehne.className = 'buehne'
        buehne.id = 'buehne'
        self.buehne_element = buehne

        # Knöpfe
        knoepfe = self.createElement('div')
        knoepfe.className = 'knoepfe'

        btnPlus = self.createElement('button')
        btnPlus.id = 'btn-plus'
        btnPlus.setAttribute('title', 'Näher')
        btnPlus.textContent = '+'
        self.btn_plus = btnPlus
        knoepfe.appendChild(btnPlus)

        btnMinus = self.createElement('button')
        btnMinus.id = 'btn-minus'
        btnMinus.setAttribute('title', 'Weiter weg')
        btnMinus.textContent = '−'
        self.btn_minus = btnMinus
        knoepfe.appendChild(btnMinus)

        btnReset = self.createElement('button')
        btnReset.id = 'btn-reset'
        btnReset.textContent = 'Zurücksetzen'
        self.btn_reset = btnReset
        knoepfe.appendChild(btnReset)

        btnIso = self.createElement('button')
        btnIso.id = 'btn-iso'
        btnIso.setAttribute('aria-pressed', 'true')
        btnIso.setAttribute('title', 'Isometrisch oder perspektivisch')
        btnIso.textContent = 'Iso'
        self.btn_iso = btnIso
        knoepfe.appendChild(btnIso)

        buehne.appendChild(knoepfe)
        raster.appendChild(buehne)

        # Karte
        aside = self.createElement('aside')
        aside.className = 'karte'

        h2 = self.createElement('h2')
        h2.textContent = 'Ausgewählter Knoten'
        aside.appendChild(h2)

        h3 = self.createElement('h3')
        h3.id = 'k-name'
        h3.textContent = '—'
        self.k_name = h3
        aside.appendChild(h3)

        sub = self.createElement('p')
        sub.className = 'sub'
        sub.id = 'k-sub'
        sub.textContent = 'Knoten anklicken oder durchblättern'
        self.k_sub = sub
        aside.appendChild(sub)

        feld1 = self.createElement('dl')
        feld1.className = 'feld'
        dt1 = self.createElement('dt')
        dt1.textContent = 'Schicht'
        dd1 = self.createElement('dd')
        dd1.id = 'k-schicht'
        dd1.textContent = '—'
        self.k_schicht = dd1
        feld1.appendChild(dt1)
        feld1.appendChild(dd1)
        aside.appendChild(feld1)

        feld2 = self.createElement('dl')
        feld2.className = 'feld'
        dt2 = self.createElement('dt')
        dt2.textContent = 'ID'
        dd2 = self.createElement('dd')
        dd2.id = 'k-id'
        dd2.textContent = '—'
        self.k_id = dd2
        feld2.appendChild(dt2)
        feld2.appendChild(dd2)
        aside.appendChild(feld2)

        blaettern = self.createElement('div')
        blaettern.className = 'blaettern'

        btnPrev = self.createElement('button')
        btnPrev.id = 'btn-prev'
        btnPrev.innerHTML = '←<br>Vorheriger'
        self.btn_prev = btnPrev
        blaettern.appendChild(btnPrev)

        btnNext = self.createElement('button')
        btnNext.id = 'btn-next'
        btnNext.innerHTML = 'Nächster<br>→'
        self.btn_next = btnNext
        blaettern.appendChild(btnNext)

        aside.appendChild(blaettern)
        raster.appendChild(aside)
        wrap.appendChild(raster)

        # Legende
        legende = self.createElement('div')
        legende.className = 'legende'
        legende.id = 'legende'
        self.legende = legende
        wrap.appendChild(legende)

        # Fuß
        fuss = self.createElement('p')
        fuss.className = 'fuss'
        fuss.textContent = 'Schematische Dokumentationsansicht — Blockgrößen messen weder Datenmenge noch Leistung. Keine Telemetrie, keine Fernabfragen: Die Seite lädt einmalig three.js vom CDN und rechnet danach ausschließlich lokal.'
        wrap.appendChild(fuss)

        body.appendChild(wrap)
        
        return self

def hex_to_rgb(value):
    value = value.lstrip('#')
    lv = len(value)
    return tuple(int(value[i:i + lv // 3], 16) for i in range(0, lv, lv // 3))

def rgb_to_hex(rgb):
    return '#{:02x}{:02x}{:02x}'.format(rgb[0], rgb[1], rgb[2])

def multiply_color(color_hex, factor):
    rgb = hex_to_rgb(color_hex)
    return rgb_to_hex(tuple(min(255, int(c * factor)) for c in rgb))

def create_sign(text, subtitle):
    # Create a simple text image representation
    font_size = 20
    subtitle_font_size = 14
    
    # Estimate width based on character count
    text_width = len(text) * font_size * 0.6
    subtitle_width = len(subtitle) * subtitle_font_size * 0.6 if subtitle else 0
    width = int(max(text_width, subtitle_width)) + 40
    height = 96 if subtitle else 62
    
    img = Image.new('RGBA', (width, height), (255, 255, 255, 242))
    draw = ImageDraw.Draw(img)
    
    try:
        font = ImageFont.truetype("arial.ttf", font_size)
        subtitle_font = ImageFont.truetype("arial.ttf", subtitle_font_size)
    except IOError:
        font = ImageFont.load_default()
        subtitle_font = ImageFont.load_default()
    
    # Draw text
    draw.text((20, 20), text, fill=(22, 25, 29), font=font)
    if subtitle:
        draw.text((20, 50), subtitle, fill=(95, 103, 115), font=subtitle_font)
    
    return img

def create_3d_scene(doc):
    SPEC = {
        "schichten": [
            {
                "name": "Tokens",
                "farbe": "#5f6773",
                "blocks": [
                    {"id": "abfrage-beim-oeffnen", "name": "Abfrage beim Oeffnen", "untertitel": "kein Vorbelegen"},
                    {"id": "localstorage", "name": "localStorage", "untertitel": "nur lokal"},
                    {"id": "keine-vorbelegung", "name": "keine Vorbelegung", "untertitel": "leer geliefert"}
                ]
            },
            {
                "name": "Quellen",
                "farbe": "#2481cc",
                "blocks": [
                    {"id": "github", "name": "GitHub", "untertitel": "Repos, Kontingent"},
                    {"id": "vercel", "name": "Vercel", "untertitel": "Deployments"},
                    {"id": "docker-hub", "name": "Docker Hub", "untertitel": "Abbilder"},
                    {"id": "openrouter", "name": "OpenRouter", "untertitel": "Guthaben"},
                    {"id": "openai", "name": "OpenAI", "untertitel": "Admin-Key"},
                    {"id": "anthropic", "name": "Anthropic", "untertitel": "Admin-Key"},
                    {"id": "tailscale", "name": "Tailscale", "untertitel": "Geraete"},
                    {"id": "clawhub", "name": "ClawHub", "untertitel": "Skills"}
                ]
            },
            {
                "name": "Abruf",
                "farbe": "#6d5bd0",
                "blocks": [
                    {"id": "fetch-je-quelle", "name": "fetch je Quelle", "untertitel": "direkt"},
                    {"id": "cors-pruefung", "name": "CORS-Pruefung", "untertitel": "entscheidet"},
                    {"id": "fehler-isolieren", "name": "Fehler isolieren", "untertitel": "je Kachel"}
                ]
            },
            {
                "name": "Ausgabe",
                "farbe": "#0f766e",
                "blocks": [
                    {"id": "kacheln", "name": "Kacheln", "untertitel": "ein Blick"},
                    {"id": "verbrauch", "name": "Verbrauch", "untertitel": "Zahlen"},
                    {"id": "keine-daten-hinweis", "name": "keine Daten = Hinweis", "untertitel": "mit Grund"}
                ]
            }
        ],
        "kanten": [
            {"von": "abfrage-beim-oeffnen", "nach": "github", "art": "fluss"},
            {"von": "localstorage", "nach": "vercel", "art": "fluss"},
            {"von": "keine-vorbelegung", "nach": "docker-hub", "art": "fluss"},
            {"von": "github", "nach": "fetch-je-quelle", "art": "fluss"},
            {"von": "vercel", "nach": "cors-pruefung", "art": "fluss"},
            {"von": "docker-hub", "nach": "fehler-isolieren", "art": "fluss"},
            {"von": "openrouter", "nach": "fetch-je-quelle", "art": "fluss"},
            {"von": "openai", "nach": "cors-pruefung", "art": "fluss"},
            {"von": "anthropic", "nach": "fehler-isolieren", "art": "fluss"},
            {"von": "tailscale", "nach": "fetch-je-quelle", "art": "fluss"},
            {"von": "clawhub", "nach": "cors-pruefung", "art": "fluss"},
            {"von": "fetch-je-quelle", "nach": "kacheln", "art": "fluss"},
            {"von": "cors-pruefung", "nach": "verbrauch", "art": "fluss"},
            {"von": "fehler-isolieren", "nach": "keine-daten-hinweis", "art": "fluss"}
        ],
        "kantenarten": [
            {"art": "fluss", "farbe": "#0f766e", "stil": "voll", "text": "Fluss von unten nach oben"}
        ]
    }

    # Erstelle das Canvas-Element
    canvas = doc.createElement('canvas')
    canvas.setAttribute('width', '800')
    canvas.setAttribute('height', '600')
    canvas.style['display'] = 'block'
    canvas.style['width'] = '100%'
    canvas.style['height'] = '100%'

    # Füge das Canvas zur Bühne hinzu
    buehne = doc.getElementById('buehne')
    buehne.appendChild(canvas)

    # In Python können wir kein echtes 3D rendern wie in Three.js,
    # aber wir können eine statische Darstellung erzeugen
    # Hier simulieren wir die wichtigsten Elemente
    
    # Aufbau der Szene
    BW = 7.4
    BD = 4.2
    BH = 1.7
    LUFT = 1.3
    ABSTAND = 11.4
    START = -17
    
    nodes = []
    byId = {}
    
    # Für jede Schicht erstellen wir visuelle Repräsentation
    for si, sch in enumerate(SPEC["schichten"]):
        y = START + si * ABSTAND
        blocks = sch["blocks"]
        columns = max(1, math.ceil(len(blocks) / 2))
        rows = 1 if len(blocks) <= 1 else 2
        gx = columns * BW + (columns - 1) * LUFT
        gz = rows * BD + (rows - 1) * LUFT
        
        # Plate (Plattform) für die Schicht
        plate_color = multiply_color(sch["farbe"], 0.4)
        
        for i, b in enumerate(blocks):
            col = i % columns
            row = i // columns
            x = -gx / 2 + BW / 2 + col * (BW + LUFT)
            z = -gz / 2 + BD / 2 + row * (BD + LUFT)
            
            # Erstelle Schild
            sign_img = create_sign(b["name"], b.get("untertitel", ""))
            
            id_val = b.get("id") or b["name"].lower().replace(" ", "-").replace("/", "-")
            entry = {
                "id": id_val,
                "name": b["name"],
                "untertitel": b.get("untertitel", ""),
                "schicht": sch["name"],
                "position": {"x": x, "y": y, "z": z}
            }
            nodes.append(entry)
            byId[id_val] = entry

    # Kanten zeichnen (vereinfacht)
    STYLE = {}
    for a in SPEC.get("kantenarten", []):
        STYLE[a["art"]] = a

    # Legende
    legend = doc.getElementById("legende")
    for a in SPEC.get("kantenarten", []):
        span = doc.createElement("span")
        # Da wir kein CSS rendern, verwenden wir einfache Textdarstellung
        span.innerHTML = f'{a["text"]} ({a["farbe"]})'
        legend.appendChild(span)

    return doc

def main():
    # Prüfe, ob ein Dateiname übergeben wurde
    if len(sys.argv) < 2:
        print('Verwendung: python 3d.py <dateiname>')
        sys.exit(1)

    filename = sys.argv[1]
    
    # Erstelle das Dokument
    doc = Document().createDocument()
    
    # Erstelle die 3D-Szene
    doc = create_3d_scene(doc)
    
    # Schreibe das HTML in eine Datei
    with open(filename, 'w', encoding='utf-8') as f:
        f.write('<!DOCTYPE html>\n')
        f.write(doc.documentElement.outerHTML())
    
    print(f'HTML-Datei wurde erfolgreich erstellt: {filename}')

if __name__ == "__main__":
    main()
