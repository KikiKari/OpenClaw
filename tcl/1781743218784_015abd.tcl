#!/usr/bin/env tclsh
# 1781743218784_015abd.js — portiert nach tcl
# Quelle: javascript, Projects@abstractions:javascript/1781743218784_015abd.js
# Erzeugt: 2026-10-25 durch ABSTRACTIONS_MANAGER.py

# 1781743218784_015abd.pl — portiert nach javascript
# Quelle: perl5, Projects@abstractions:perl5/1781743218784_015abd.pl
# Erzeugt: 2026-10-25 durch ABSTRACTIONS_MANAGER.py

proc generate_html {} {
    return {<!DOCTYPE html>
<script type="application/json" id="cowork-artifact-meta">
{
  "name": "Secret Vault Public",
  "schemaVersion": 1,
  "description": "Secret-Vault Public als interaktives Browser-Artefakt: verschlüsselter Secret-Container vollständig client-seitig (WebCrypto, AES-256-GCM + PBKDF2). Öffnen/Anlegen, Anbieter/Felder ergänzen und ersetzen (Rotation), verschlüsseln und als .svpb herunterladen oder Klartext-JSON exportieren. DE/EN nach Browsersprache. Eigenes Format (nicht kompatibel mit dem scrypt-Python-Tool). Keine Secrets eingebettet.",
  "mcpTools": [],
  "mcpServerNames": []
}
</script>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Secret-Vault Public</title>
<style>
:root{ color-scheme:light; --ink:#1b1c1f; --muted:#6c6e75; --faint:#9a9ca3; --card:#fff; --line:#e9eaee; --accent:#5b5bd6; --accent2:#7c5cff; --ok:#22a06b; --err:#e0533d; --radius:16px; --shadow:0 1px 2px rgba(20,20,40,.04),0 6px 20px rgba(20,20,40,.06);}
*{box-sizing:border-box;}
body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;color:var(--ink);min-height:100vh;background:radial-gradient(1100px 560px at 100% -10%,#e8ecff 0%,rgba(232,236,255,0) 55%),linear-gradient(180deg,#eef1f6,#f7f7f8 42%);background-attachment:fixed;}
.wrap{max-width:820px;margin:0 auto;padding:24px 18px 70px;}
.brand{display:flex;align-items:center;gap:12px;margin-bottom:4px;}
.mark{width:32px;height:32px;border-radius:9px;background:linear-gradient(135deg,var(--accent),var(--accent2));box-shadow:0 4px 12px rgba(91,91,214,.35);position:relative;flex:0 0 auto;}
.mark:after{content:"";position:absolute;inset:8px;border-radius:4px;border:2px solid rgba(255,255,255,.92);}
h1{font-size:21px;margin:0 0 4px;font-weight:700;}
.sub{color:var(--muted);font-size:13px;margin:2px 0 16px;}
.card{background:var(--card);border:1px solid var(--line);border-radius:var(--radius);box-shadow:var(--shadow);padding:16px;margin-bottom:14px;}
.card h2{font-size:14px;margin:0 0 10px;}
label.lab{display:block;font-size:12px;font-weight:600;color:var(--muted);margin:8px 0 3px;}
input,textarea{width:100%;font-size:13px;padding:8px 10px;border:1px solid var(--line);border-radius:9px;font-family:ui-monospace,Menlo,Consolas,monospace;background:#fff;}
textarea{min-height:90px;white-space:pre;overflow:auto;}
.row{display:flex;gap:8px;flex-wrap:wrap;align-items:center;}
.btn{font-size:13px;font-weight:600;padding:8px 14px;border:1px solid var(--line);border-radius:10px;background:#fff;cursor:pointer;box-shadow:var(--shadow);transition:transform .1s;}
.btn:hover{transform:translateY(-1px);}
.btn.primary{background:linear-gradient(135deg,var(--accent),var(--accent2));color:#fff;border-color:transparent;}
.btn.sm{padding:5px 9px;font-size:12px;}
.msg{font-size:12px;margin-left:6px;}
.msg.ok{color:var(--ok);} .msg.err{color:var(--err);}
.prov{border:1px solid var(--line);border-radius:12px;padding:10px 12px;margin-bottom:10px;}
.prov h3{margin:0 0 6px;font-size:13.5px;display:flex;align-items:center;gap:8px;}
.kv{display:grid;grid-template-columns:180px 1fr auto;gap:6px;margin:4px 0;align-items:center;}
.kv input{font-size:12px;padding:5px 7px;}
.kv .k{color:var(--muted);font-weight:600;}
.muted{color:var(--faint);font-size:13px;}
.hide{display:none;}
.foot{color:var(--faint);font-size:11.5px;text-align:center;margin-top:18px;line-height:1.5;}
a{color:var(--accent);}
</style>
</head>
<body>
<div class="wrap">
  <div class="brand"><div class="mark"></div><h1 id="title">Secret-Vault Public</h1></div>
  <div class="sub" id="sub">Verschlüsselte Secret-Vault (AES-256-GCM, PBKDF2) — alles im Browser, kein Server.</div>

  <div class="card">
    <h2 id="h-open">Öffnen oder neu</h2>
    <label class="lab" id="l-pass">Passphrase</label>
    <input id="pass" type="password" placeholder="Passphrase…">
    <label class="lab" id="l-file">Vault laden (Datei oder Base64 einfügen)</label>
    <input id="file" type="file" accept=".svpb,.txt,.vault,.b64">
    <textarea id="blob" placeholder="…oder Base64 hier einfügen"></textarea>
    <div class="row" style="margin-top:10px">
      <button class="btn primary" id="openBtn">Öffnen / Entschlüsseln</button>
      <button class="btn" id="newBtn">Neuer leerer Vault</button>
      <span class="msg" id="openMsg"></span>
    </div>
  </div>

  <div class="card hide" id="editor">
    <h2 id="h-edit">Inhalt</h2>
    <div id="provs"></div>
    <div class="row" style="margin-top:8px">
      <input id="newProv" placeholder="Neuer Anbieter (Name)" style="max-width:280px">
      <button class="btn sm" id="addProvBtn">+ Anbieter</button>
    </div>
  </div>

  <div class="card hide" id="out">
    <h2 id="h-save">Speichern / Export</h2>
    <div class="row">
      <button class="btn primary" id="encBtn">Verschlüsseln</button>
      <button class="btn" id="dlBtn">Als .svpb herunterladen</button>
      <button class="btn" id="expBtn">Klartext-JSON exportieren</button>
      <span class="msg" id="saveMsg"></span>
    </div>
    <label class="lab" id="l-resu
