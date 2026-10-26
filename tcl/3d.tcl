#!/usr/bin/env tclsh
# 3d.html — portiert nach tcl
# Quelle: html, Projects@abstractions:public/3d.html
# Erzeugt: 2026-10-26 durch ABSTRACTIONS_MANAGER.py

proc write_3d_html {filename} {
    set fd [open $filename w]
    
    puts $fd {<!DOCTYPE html>}
    puts $fd {<html lang="de">}
    puts $fd {<head>}
    puts $fd {<meta charset="utf-8">}
    puts $fd {<meta name="viewport" content="width=device-width, initial-scale=1">}
    puts $fd {<title>Abstractions Manager — Interaktive Architektur</title>}
    puts $fd {<meta name="description" content="Von OpenClaw-Scripts in zehn Zielsprachen — drehen, zoomen, Knoten auswählen.">}
    puts $fd {<meta name="theme-color" content="#0f766e">}
    puts $fd {<style>}
    puts $fd {  :root\{}
    puts $fd {    --bg:#fbfaf7; --panel:#fff; --line:#e6e3dc; --text:#16191d; --muted:#5f6773;}
    puts $fd {    --ac:#0f766e; --buehne:#0e1420; --buehne-line:#1d2739;}
    puts $fd {    color-scheme: light;}
    puts $fd {  \}}
    puts $fd {  @media (prefers-color-scheme: dark)\{}
    puts $fd {    :root\{ --bg:#0f1115; --panel:#171a21; --line:#262b36; --text:#f2f4f8; --muted:#9aa3b2;}
    puts $fd {           color-scheme: dark; \}}
    puts $fd {  \}}
    puts $fd {  *\{box-sizing:border-box\}}
    puts $fd {  body\{margin:0;background:var(--bg);color:var(--text);}
    puts $fd {       font:15px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif\}}
    puts $fd {  .wrap\{max-width:1240px;margin:0 auto;padding:34px 22px 60px\}}
    puts $fd {  .technik\{font-size:12px;font-weight:700;letter-spacing:.1em;text-transform:uppercase;}
    puts $fd {           color:var(--ac);margin:0 0 10px\}}
    puts $fd {  h1\{font-size:clamp(30px,5vw,52px);line-height:1.05;margin:0 0 14px;letter-spacing:-.03em\}}
    puts $fd {  .lede\{font-size:16.5px;color:var(--muted);max-width:62ch;margin:0 0 26px\}}
    puts $fd {  .raster\{display:grid;grid-template-columns:minmax(0,1fr) 288px;gap:18px;align-items:start\}}
    puts $fd {  @media (max-width:880px)\{ .raster\{grid-template-columns:1fr\} \}}
    puts $fd {  .buehne\{position:relative;background:var(--buehne);border-radius:14px;overflow:hidden;}
    puts $fd {          min-height:520px;aspect-ratio:16/11\}}
    puts $fd {  .buehne canvas\{display:block;width:100%;height:100%\}}
    puts $fd {  .knoepfe\{position:absolute;top:14px;right:14px;display:flex;gap:8px;z-index:2\}}
    puts $fd {  button\{font:inherit;font-size:14px;font-weight:650;padding:9px 14px;border-radius:9px;}
    puts $fd {         border:1px solid var(--line);background:var(--panel);color:var(--text);cursor:pointer\}}
    puts $fd {  button:hover\{border-color:var(--ac)\}}
    puts $fd {  button[aria-pressed="true"]\{background:var(--ac);border-color:var(--ac);color:#fff\}}
    puts $fd {  .karte\{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:20px\}}
    puts $fd {  .karte h2\{font-size:11px;font-weight:700;letter-spacing:.09em;text-transform:uppercase;}
    puts $fd {            color:var(--muted);margin:0 0 12px\}}
    puts $fd {  .karte h3\{font-size:23px;margin:0 0 4px;letter-spacing:-.02em\}}
    puts $fd {  .karte .sub\{color:var(--muted);margin:0 0 18px;font-size:14.5px\}}
    puts $fd {  .feld\{border-top:1px solid var(--line);padding:12px 0 0;margin:0 0 12px\}}
    puts $fd {  .feld dt\{font-size:11px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;}
    puts $fd {           color:var(--muted);margin:0 0 3px\}}
    puts $fd {  .feld dd\{margin:0;font-weight:650\}}
    puts $fd {  .blaettern\{display:flex;gap:8px;margin-top:16px\}}
    puts $fd {  .blaettern button\{flex:1;text-align:center;line-height:1.25;padding:11px 8px\}}
    puts $fd {  .legende\{display:flex;gap:22px;flex-wrap:wrap;margin:16px 0 0;font-size:13.5px;color:var(--muted)\}}
    puts $fd {  .legende span\{display:inline-flex;align-items:center;gap:9px\}}
    puts $fd {  .strich\{width:30px;height:0;border-top-width:3px;border-top-style:solid;display:inline-block\}}
    puts $fd {  .fuss\{margin:14px 0 0;font-size:13px;color:var(--muted);max-width:80ch\}}
    puts $fd {  .fehler\{padding:40px;text-align:center;color:var(--muted)\}}
    puts $fd {  a\{color:var(--ac)\}}
    puts $fd {</style>}
    puts $fd {</head>}
    puts $fd {<body>}
    puts $fd {<div class="wrap">}
    puts $fd {}
    puts $fd {  <p class="technik">three.js · r128</p>}
    puts $fd {  <h1>Abstractions Manager</h1>}
    puts $fd {  <p class="lede">Von OpenClaw-Scripts in zehn Zielsprachen — drehen, zoomen, Knoten auswählen.</p>}
    puts $fd {}
    puts $fd {  <div class="raster">}
    puts $fd {    <div class="buehne" id="buehne">}
    puts $fd {      <div class="knoepfe">}
    puts $fd {        <button id="btn-plus" title="Näher">+</button>}
    puts $fd {        <button id="btn-minus" title="Weiter weg">−</button>}
    puts $fd {        <button id="btn-reset">Zurücksetzen</button>}
    puts $fd {        <button id="btn-iso" aria-pressed="true" title="Isometrisch oder perspektivisch">Iso</button>}
    puts $fd {      </div>}
    puts $fd {    </div>}
    puts $fd {}
    puts $fd {    <aside class="karte">}
    puts $fd {      <h2>Ausgewählter Knoten</h2>}
    puts $fd {      <h3 id="k-name">—</h3>}
    puts $fd {      <p class="sub" id="k-sub">Knoten anklicken oder durchblättern</p>}
    puts $fd {      <dl class="feld"><dt>Schicht</dt><dd id="k-schicht">—</dd></dl>}
    puts $fd {      <dl class="feld"><dt>ID</dt><dd id="k-id">—</dd></dl>}
    puts $fd {      <div class="blaettern">}
    puts $fd {        <button id="btn-prev">←<br>Vorheriger</button>}
    puts $fd {        <button id="btn-next">Nächster<br>→</button>}
    puts $fd {      </div>}
    puts $fd {    </aside>}
    puts $fd {  </div>}
    puts $fd {}
    puts $fd {  <div class="legende" id="legende"></div>}
    puts $fd {  <p class="fuss">Schematische Dokumentationsansicht — Blockgrößen messen weder Datenmenge noch Leistung. Keine Telemetrie, keine Fernabfragen: Die Seite lädt einmalig three.js vom CDN und rechnet danach ausschließlich lokal.</p>}
    puts $fd {}
    puts $fd {</div>}
    puts $fd {}
    puts $fd {<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>}
    puts $fd {<script>}
    puts $fd {(function()\{}
    puts $fd {  "use strict";}
    puts $fd {  var SPEC = \{"schichten": [\{"name": "Eingaben", "farbe": "#5f6773", "blocks": [\{"id": "openclaw-scripts", "name": "OpenClaw-Scripts", "untertitel": "Quellen"\}, \{"id": "env", "name": ".env", "untertitel": "Umgebung"\}, \{"id": "repo-init", "name": "Repo-Init", "untertitel": "Erstinstallation"\}\]\}, \{"name": "Portierung", "farbe": "#2481cc", "blocks": [\{"id": "create-abstraction-py", "name": "create_abstraction.py", "untertitel": "Portierung"\}, \{"id": "10-zielsprachen", "name": "10 Zielsprachen", "untertitel": "je Lauf"\}, \{"id": "json-processor-js", "name": "json_processor.js", "untertitel": "Node-Teil"\}\]\}, \{"name": "Verwaltung", "farbe": "#6d5bd0", "blocks": [\{"id": "db-manager-py", "name": "db_manager.py", "untertitel": "Zustand"\}, \{"id": "logger-py", "name": "logger.py", "untertitel": "Protokoll"\}, \{"id": "exceptions-py", "name": "exceptions.py", "untertitel": "Fehlerklassen"\}\]\}, \{"name": "Pruefung", "farbe": "#b45309", "blocks": [\{"id": "check-live-js", "name": "check-live.js", "untertitel": "Live-Pruefung"\}, \{"id": "code-review-full", "name": "CODE_REVIEW_FULL", "untertitel": "Durchsicht"\}, \{"id": "python-hardener", "name": "python-hardener", "untertitel": "Haertung"\}\]\}, \{"name": "Ausgabe", "farbe": "#0f766e", "blocks": [\{"id": "status-report", "name": "Status-Report", "untertitel": "was ist wo"\}, \{"id": "doku-db", "name": "Doku-DB", "untertitel": "Datenbanken"\}, \{"id": "cron-alle-6-h", "name": "Cron alle 6 h", "untertitel": "Takt"\}\]\]\}, "kanten": [\{"von": "openclaw-scripts", "nach": "create-abstraction-py", "art": "fluss"\}, \{"von": "env", "nach": "10-zielsprachen", "art": "fluss"\}, \{"von": "repo-init", "nach": "json-processor-js", "art": "fluss"\}, \{"von": "create-abstraction-py", "nach": "db-manager-py", "art": "fluss"\}, \{"von": "10-zielsprachen", "nach": "logger-py", "art": "fluss"\}, \{"von": "json-processor-js", "nach": "exceptions-py", "art": "fluss"\}, \{"von": "db-manager-py", "nach": "check-live-js", "art": "fluss"\}, \{"von": "logger-py", "nach": "code-review-full", "art": "fluss"\}, \{"von": "exceptions-py", "nach": "python-hardener", "art": "fluss"\}, \{"von": "check-live-js", "nach": "status-report", "art": "fluss"\}, \{"von": "code-review-full", "nach": "doku-db", "art": "fluss"\}, \{"von": "python-hardener", "nach": "cron-alle-6-h", "art": "fluss"\}\], "kantenarten": [\{"art": "fluss", "farbe": "#0f766e", "stil": "voll", "text": "Fluss von unten nach oben"\}\]\};}
    puts $fd {}
    puts $fd {  var buehne = document.getElementById("buehne");}
    puts $fd {  if (typeof THREE === "undefined")\{}
    puts $fd {    buehne.insertAdjacentHTML("beforeend",}
    puts $fd {      '<div class="fehler">three.js konnte nicht geladen werden. ' +}
    puts $fd {      'Die Seite braucht einmalig Netzzugang zum CDN.</div>');}
    puts $fd {    return;}
    puts $fd {  \}}
    puts $fd {}
    puts $fd {  // ---------------------------------------------------------------- Szene ---}
    puts $fd {  var szene = new THREE.Scene();}
    puts $fd {  szene.background = new THREE.Color(0x0e1420);}
    puts $fd {  var renderer = new THREE.WebGLRenderer(\{antialias:true\});}
    puts $fd {  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));}
    puts $fd {  buehne.appendChild(renderer.domElement);}
    puts $fd {}
    puts $fd {  var D = 26, radius = 82, aspekt = 1;}
    puts $fd {  var kameraIso = new THREE.OrthographicCamera(-D, D, D, -D, 0.1, 600);}
    puts $fd {  var kameraPersp = new THREE.PerspectiveCamera(42, 1, 0.1, 600);}
    puts $fd {  var kamera = kameraIso, iso = true;}
    puts $fd {}
    puts $fd {  szene.add(new THREE.AmbientLight(0xffffff, 0.66));}
    puts $fd {  var licht = new THREE.DirectionalLight(0xffffff, 0.8);}
    puts $fd {  licht.position.set(30, 46, 26); szene.add(licht);}
    puts $fd {  var gegen = new THREE.DirectionalLight(0x8ea2ff, 0.3);}
    puts $fd {  gegen.position.set(-32, 16, -28); szene.add(gegen);}
    puts $fd {}
    puts $fd {  var raster = new THREE.GridHelper(110, 34, 0x25324a, 0x1a2333);}
    puts $fd {  raster.position.y = -24; szene.add(raster);}
    puts $fd {}
    puts $fd {  // ------------------------------------------------------------ Schilder ---}
    puts $fd {  // Text auf eine Textur, dann als Billboard — bleibt bei jeder Drehung lesbar.}
    puts $fd {  function schild(text, unter)\{}
    puts $fd {    var c = document.createElement("canvas"), x = c.getContext("2d");}
    puts $fd {    var f1 = "700 40px -apple-system,Segoe UI,Roboto,sans-serif";}
    puts $fd {    var f2 = "500 27px -apple-system,Segoe UI,Roboto,sans-serif";}
    puts $fd {    x.font = f1; var w1 = x.measureText(text).width;}
    puts $fd {    x.font = f2; var w2 = unter ? x.measureText(unter).width : 0;}
    puts $fd {    var w = Math.ceil(Math.max(w1, w2)) + 40, h = unter ? 96 : 62;}
    puts $fd {    c.width = w; c.height = h;}
    puts $fd {    x = c.getContext("2d");}
    puts $fd {    x.fillStyle = "rgba(255,255,255,.95)";}
    puts $fd {    if (x.roundRect)\{ x.beginPath(); x.roundRect(0,0,w,h,13); x.fill(); \}}
    puts $fd {    else x.fillRect(0,0,w,h);}
    puts $fd {    x.fillStyle = "#16191d"; x.font = f1; x.textBaseline = "middle";}
    puts $fd {    x.fillText(text, 20, unter ? 32 : 31);}
    puts $fd {    if (unter)\{ x.fillStyle = "#5f6773"; x.font = f2; x.fillText(unter, 20, 68); \}}
    puts $fd {    var t = new THREE.CanvasTexture(c); t.minFilter = THREE.LinearFilter;}
    puts $fd {    var s = new THREE.Sprite(new THREE.SpriteMaterial(\{map:t, transparent:true, depthTest:false\}));}
    puts $fd {    s.scale.set(w/62*2.5, h/62*2.5, 1);}
    puts $fd {    s.renderOrder = 999;}
    puts $fd {    return s;}
    puts $fd {  \}}
    puts $fd {}
    puts $fd {  // -------------------------------------------------------------- Aufbau ---}
    puts $fd {  var BW = 7.4, BD = 4.2, BH = 1.7, LUFT = 1.3, ABSTAND = 11.4, START = -17;}
    puts $fd {  var knoten = [], nachId = \{\}, klickbar = [];}
    puts $fd {  var gruppe = new THREE.Group();}
    puts $fd {}
    puts $fd {  SPEC.schichten.forEach(function(sch, si)\{}
    puts $fd {    var y = START + si * ABSTAND;}
    puts $fd {    var bl = sch.blocks.map(function(b)\{}
    puts $fd {      return (typeof b === "string") ? \{id:null, name:b, untertitel:""\} : b;}
    puts $fd {    \});}
    puts $fd {    var spalten = Math.max(1, Math.ceil(bl.length / 2));}
    puts $fd {    var reihen = bl.length <= 1 ? 1 : 2;}
    puts $fd {    var gx = spalten*BW + (spalten-1)*LUFT, gz = reihen*BD + (reihen-1)*LUFT;}
    puts $fd {}
    puts $fd {    var platte = new THREE.Mesh(}
    puts $fd {      new THREE.BoxGeometry(gx+3, 0.6, gz+3),}
    puts $fd {      new THREE.MeshLambertMaterial(\{color:new THREE.Color(sch.farbe).multiplyScalar(0.4)\}));}
    puts $fd {    platte.position.set(0, y-1.7, 0); gruppe.add(platte);}
    puts $fd {}
    puts $fd {    bl.forEach(function(b, i)\{}
    puts $fd {      var sp = i % spalten, re = Math.floor(i / spalten);}
    puts $fd {      var x = -gx/2 + BW/2 + sp*(BW+LUFT), z = -gz/2 + BD/2 + re*(BD+LUFT);}
    puts $fd {      var mat = new THREE.MeshLambertMaterial(\{color:sch.farbe\});}
    puts $fd {      var m = new THREE.Mesh(new THREE.BoxGeometry(BW, BH, BD), mat);}
    puts $fd {      m.position.set(x, y, z);}
    puts $fd {      gruppe.add(m); klickbar.push(m);}
    puts $fd {      var kante = new THREE.LineSegments(new THREE.EdgesGeometry(m.geometry),}
    puts $fd {        new THREE.LineBasicMaterial(\{color:0x0e1420, transparent:true, opacity:.55\}));}
    puts $fd {      kante.position.copy(m.position); gruppe.add(kante);}
    puts $fd {}
    puts $fd {      var s = schild(b.name, b.untertitel);}
    puts $fd {      s.position.set(x, y + BH/2 + (b.untertitel ? 2.1 : 1.6), z);}
    puts $fd {      gruppe.add(s);}
    puts $fd {}
    puts $fd {      var id = b.id || (b.name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""));}
    puts $fd {      var eintrag = \{id:id, name:b.name, untertitel:b.untertitel||"", schicht:sch.name,}
    puts $fd {                     mesh:m, mat:mat, farbe:new THREE.Color(sch.farbe), pos:m.position\};}
    puts $fd {      m.userData.index = knoten.length;}
    puts $fd {      knoten.push(eintrag); nachId[id] = eintrag;}
    puts $fd {    \});}
    puts $fd {  \});}
    puts $fd {}
    puts $fd {  // -------------------------------------------------------------- Kanten ---}
    puts $fd {  var STIL = \{\};}
    puts $fd {  (SPEC.kantenarten || []).forEach(function(a)\{ STIL[a.art] = a; \});}
    puts $fd {}
    puts $fd {  (SPEC.kanten || []).forEach(function(k)\{}
    puts $fd {    var a = nachId[k.von], b = nachId[k.nach];}
    puts $fd {    if (!a || !b) return;}
    puts $fd {    var art = STIL[k.art] || \{farbe:"#8ea2ff", stil:"voll"\};}
    puts $fd {    var g = new THREE.BufferGeometry().setFromPoints([}
    puts $fd {      a.pos.clone().setY(a.pos.y + 0.9), b.pos.clone().setY(b.pos.y - 0.9)]);}
    puts $fd {    var linie;}
    puts $fd {    if (art.stil === "gestrichelt")\{}
    puts $fd {      linie = new THREE.Line(g, new THREE.LineDashedMaterial(}
    puts $fd {        \{color:art.farbe, dashSize:1.4, gapSize:1.0, transparent:true, opacity:.9\}));}
    puts $fd {      linie.computeLineDistances();}
    puts $fd {    \} else \{}
    puts $fd {      linie = new THREE.Line(g, new THREE.LineBasicMaterial(}
    puts $fd {        \{color:art.farbe, transparent:true, opacity:.85\}));}
    puts $fd {    \}}
    puts $fd {    gruppe.add(linie);}
    puts $fd {  \});}
    puts $fd {}
    puts $fd {  szene.add(gruppe);}
    puts $fd {}
    puts $fd {  var leg = document.getElementById("legende");}
    puts $fd {  (SPEC.kantenarten || []).forEach(function(a)\{}
    puts $fd {    var s = document.createElement("span");}
    puts $fd {    s.innerHTML = '<i class="strich" style="border-top-color:' + a.farbe +}
    puts $fd {                  ';border-top-style:' + (a.stil === "gestrichelt" ? "dashed" : "solid") +}
    puts $fd {                  '"></i>' + a.text;}
    puts $fd {    leg.appendChild(s);}
    puts $fd {  \});}
    puts $fd {}
    puts $fd {  // ------------------------------------------------------------- Auswahl ---}
    puts $fd {  var aktiv = -1;}
    puts $fd {  function waehle(i)\{}
    puts $fd {    if (aktiv >= 0)\{}
    puts $fd {      knoten[aktiv].mat.color.copy(knoten[aktiv].farbe);}
    puts $fd {      knoten[aktiv].mat.emissive.setHex(0x000000);}
    puts $fd {      knoten[aktiv].mesh.scale.set(1,1,1);}
    puts $fd {    \}}
    puts $fd {    aktiv = ((i % knoten.length) + knoten.length) % knoten.length;}
    puts $fd {    var k = knoten[aktiv];}
    puts $fd {    k.mat.emissive.setHex(0x333333);}
    puts $fd {    k.mesh.scale.set(1.1, 1.5, 1.1);}
    puts $fd {    document.getElementById("k-name").textContent = k.name;}
    puts $fd {    document.getElementById("k-sub").textContent = k.untertitel || "—";}
    puts $fd {    document.getElementById("k-schicht").textContent = k.schicht;}
    puts $fd {    document.getElementById("k-id").textContent = k.id;}
    puts $fd {  \}}
    puts $fd {}
    puts $fd {  var strahl = new THREE.Raycaster(), zeiger = new THREE.Vector2();}
    puts $fd {  renderer.domElement.addEventListener("click", function(e)\{}
    puts $fd {    if (gezogen) return;}
    puts $fd {    var r = renderer.domElement.getBoundingClientRect();}
    puts $fd {    zeiger.x = ((e.clientX - r.left) / r.width) * 2 - 1;}
    puts $fd {    zeiger.y = -((e.clientY - r.top) / r.height) * 2 + 1;}
    puts $fd {    strahl.setFromCamera(zeiger, kamera);}
    puts $fd {    var treffer = strahl.intersectObjects(klickbar, false);}
    puts $fd {    if (treffer.length) waehle(treffer[0].object.userData.index);}
    puts $fd {  \});}
    puts $fd {  document.getElementById("btn-prev").addEventListener("click", function()\{ waehle(aktiv - 1); \});}
    puts $fd {  document.getElementById("btn-next").addEventListener("click", function()\{ waehle(aktiv + 1); \});}
    puts $fd {}
    puts $fd {  // ------------------------------------------------------------- Kamera ----}
    puts $fd {  var azimut = Math.PI/4, elevation = 0.62, rotiert = true;}
    puts $fd {  function stelle()\{}
    puts $fd {    var x = radius*Math.cos(elevation)*Math.sin(azimut);}
    puts $fd {    var y = radius*Math.sin(elevation);}
    puts $fd {    var z = radius*Math.cos(elevation)*Math.cos(azimut);}
    puts $fd {    kamera.position.set(x, y, z); kamera.lookAt(0, 0, 0);}
    puts $fd {  \}}
    puts $fd {  var zieht = false, gezogen = false, lx = 0, ly = 0;}
    puts $fd {  renderer.domElement.addEventListener("pointerdown", function(e)\{}
    puts $fd {    zieht = true; gezogen = false; lx = e.clientX; ly = e.clientY;}
    puts $fd {  \});}
    puts $fd {  window.addEventListener("pointermove", function(e)\{}
    puts $fd {    if (!zieht) return;}
    puts $fd {    if (Math.abs(e.clientX-lx) + Math.abs(e.clientY-ly) > 3)\{ gezogen = true; rotiert = false; \}}
    puts $fd {    azimut -= (e.clientX - lx) * 0.006;}
    puts $fd {    elevation = Math.max(0.08, Math.min(1.45, elevation + (e.clientY - ly) * 0.005));}
    puts $fd {    lx = e.clientX; ly = e.clientY;}
    puts $fd {  \});}
    puts $fd {  window.addEventListener("pointerup", function()\{ zieht = false; setTimeout(function()\{ gezogen = false; \}, 0); \});}
    puts $fd {}
    puts $fd {  function zoom(f)\{}
    puts $fd {    if (iso)\{ D = Math.max(11, Math.min(54, D * f)); groesse(); \}}
    puts $fd {    else \{ radius = Math.max(32, Math.min(160, radius * f)); \}}
    puts $fd {  \}}
    puts $fd {  document.getElementById("btn-plus").addEventListener("click", function()\{ zoom(0.85); \});}
    puts $fd {  document.getElementById("btn-minus").addEventListener("click", function()\{ zoom(1.18); \});}
    puts $fd {  renderer.domElement.addEventListener("wheel", function(e)\{}
    puts $fd {    e.preventDefault(); zoom(e.deltaY > 0 ? 1.08 : 0.93);}
    puts $fd {  \}, \{passive:false\});}
    puts $fd {  document.getElementById("btn-reset").addEventListener("click", function()\{}
    puts $fd {    azimut = Math.PI/4; elevation = 0.62; D = 26; radius = 82; rotiert = true;}
    puts $fd {    iso = true; kamera = kameraIso;}
    puts $fd {    document.getElementById("btn-iso").setAttribute("aria-pressed", "true");}
    puts $fd {    document.getElementById("btn-iso").textContent = "Iso";}
    puts $fd {    waehle(0); groesse();}
    puts $fd {  \});}
    puts $fd {  document.getElementById("btn-iso").addEventListener("click", function()\{}
    puts $fd {    iso = !iso; kamera = iso ? kameraIso : kameraPersp;}
    puts $fd {    this.setAttribute("aria-pressed", String(iso));}
    puts $fd {    this.textContent = iso ? "Iso" : "Persp";}
    puts $fd {    groesse();}
    puts $fd {  \});}
    puts $fd {}
    puts $fd {  function groesse()\{}
    puts $fd {    var w = buehne.clientWidth, h = buehne.clientHeight;}
    puts $fd {    aspekt = w / h;}
    puts $fd {    kameraIso.left = -D*aspekt; kameraIso.right = D*aspekt;}
    puts $fd {    kameraIso.top = D; kameraIso.bottom = -D; kameraIso.updateProjectionMatrix();}
    puts $fd {    kameraPersp.aspect = aspekt; kameraPersp.updateProjectionMatrix();}
    puts $fd {    renderer.setSize(w, h, false);}
    puts $fd {  \}}
    puts $fd {  window.addEventListener("resize", groesse);}
    puts $fd {}
    puts $fd {  groesse();}
    puts $fd {  waehle(0);}
    puts $fd {  (function schleife()\{}
    puts $fd {    requestAnimationFrame(schleife);}
    puts $fd {    if (rotiert) azimut += 0.003;}
    puts $fd {    stelle();}
    puts $fd {    renderer.render(szene, kamera);}
    puts $fd {  \})();}
    puts $fd {  \})();}
    puts $fd {</script>}
    puts $fd {</body>}
    puts $fd {</html>}
    
    close $fd
}

# Main execution
if {$argc != 1} {
    puts stderr "Usage: $argv0 <output-file>"
    exit 1
}

set output_file [lindex $argv 0]
write_3d_html $output_file
