#!/usr/bin/env tclsh
# index.html — portiert nach tcl
# Quelle: html, Projects@Telegram-Monitor:public/index.html
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 script to generate the index.html file
# Usage: tclsh this_script.tcl output_file.html

if {$argc != 1} {
    puts stderr "Usage: $argv0 output_file.html"
    exit 1
}

set output_file [lindex $argv 0]

# Open the output file for writing
set fd [open $output_file w]

# Write the HTML document structure
puts $fd {<!DOCTYPE html>}
puts $fd {<html lang="de">}
puts $fd {<head>}
puts $fd {<meta charset="utf-8">}
puts $fd {<meta name="viewport" content="width=device-width, initial-scale=1">}
puts $fd {<title>Telegram Monitor — lokaler Beobachtungs-Companion</title>}
puts $fd {<meta name="description" content="Beobachtet öffentliche Telegram-Kanäle und TikTok-Konten auf dem eigenen Rechner und meldet den Livegang. Keine Cloud, keine Anmeldung.">}
puts $fd {<meta name="theme-color" content="#2481cc">}
puts $fd {<meta property="og:title" content="Telegram Monitor">}
puts $fd {<meta property="og:description" content="Lokaler Beobachtungs-Companion. Docker, PWA, Meldung beim Livegang.">}
puts $fd {<meta property="og:type" content="website">}
puts $fd {<style>}
puts $fd {  :root\{}
puts $fd {    --bg:#ffffff; --soft:#f6f7f9; --line:#e3e6ea; --text:#16191d; --muted:#5f6773;}
puts $fd {    --tg:#2481cc; --tg-soft:#e8f2fb; --tt:#fe2c55;}
puts $fd {    --ok:#15803d; --ok-soft:#e7f6ec; --warn:#b45309; --warn-soft:#fdf3e3;}
puts $fd {    color-scheme: light;}
puts $fd {  \}}
puts $fd {  @media (prefers-color-scheme: dark)\{}
puts $fd {    :root\{ --bg:#0f1115; --soft:#171a21; --line:#262b36; --text:#f2f4f8; --muted:#9aa3b2;}
puts $fd {           --tg-soft:#132a3d; --ok-soft:#12261a; --warn-soft:#2c2110; color-scheme: dark; \}}
puts $fd {  \}}
puts $fd {  *\{box-sizing:border-box\}}
puts $fd {  body\{margin:0;background:var(--bg);color:var(--text);}
puts $fd {       font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif\}}
puts $fd {  .wrap\{max-width:820px;margin:0 auto;padding:0 20px 72px\}}
puts $fd {  header\{padding:64px 0 40px;border-bottom:1px solid var(--line);margin-bottom:8px\}}
puts $fd {  h1\{font-size:34px;line-height:1.2;margin:0 0 12px;letter-spacing:-.02em\}}
puts $fd {  .lede\{font-size:18px;color:var(--muted);margin:0 0 22px;max-width:60ch\}}
puts $fd {  h2\{font-size:13px;margin:44px 0 14px;text-transform:uppercase;letter-spacing:.06em;}
puts $fd {     color:var(--muted);font-weight:650\}}
puts $fd {  h3\{font-size:17px;margin:26px 0 6px\}}
puts $fd {  p\{margin:0 0 14px;max-width:68ch\}}
puts $fd {  .badges\{display:flex;gap:7px;flex-wrap:wrap;margin-bottom:22px\}}
puts $fd {  .badge\{font-size:12px;font-weight:650;padding:4px 11px;border-radius:99px;}
puts $fd {         background:var(--soft);color:var(--muted);border:1px solid var(--line)\}}
puts $fd {  .badge.on\{background:var(--ok-soft);color:var(--ok);border-color:transparent\}}
puts $fd {  .cta\{display:flex;gap:10px;flex-wrap:wrap\}}
puts $fd {  .btn\{display:inline-block;font-weight:650;font-size:15px;padding:11px 20px;}
puts $fd {       border-radius:9px;text-decoration:none;border:1px solid var(--line);}
puts $fd {       background:var(--bg);color:var(--text)\}}
puts $fd {  .btn.primary\{background:var(--tg);border-color:var(--tg);color:#fff\}}
puts $fd {  .btn:hover\{border-color:var(--tg)\}}
puts $fd {  .grid\{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:14px\}}
puts $fd {  .card\{border:1px solid var(--line);border-radius:12px;padding:16px 18px;background:var(--bg)\}}
puts $fd {  .card h3\{margin-top:0;font-size:15.5px\}}
puts $fd {  .card p\{font-size:14px;color:var(--muted);margin:0\}}
puts $fd {  ol.steps\{list-style:none;counter-reset:s;padding:0;margin:0\}}
puts $fd {  ol.steps li\{counter-increment:s;position:relative;padding:0 0 20px 40px;}
puts $fd {              border-left:2px solid var(--line);margin-left:11px\}}
puts $fd {  ol.steps li:last-child\{border-left-color:transparent;padding-bottom:0\}}
puts $fd {  ol.steps li::before\{content:counter(s);position:absolute;left:-13px;top:0;}
puts $fd {       width:24px;height:24px;border-radius:50%;background:var(--tg);color:#fff;}
puts $fd {       display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700\}}
puts $fd {  ol.steps b\{display:block;margin-bottom:3px\}}
puts $fd {  ol.steps p\{font-size:14.5px;color:var(--muted);margin:0 0 8px\}}
puts $fd {  code\{background:var(--soft);padding:2px 7px;border-radius:5px;font-size:13.5px;}
puts $fd {       font-family:ui-monospace,SFMono-Regular,Menlo,monospace;word-break:break-word\}}
puts $fd {  pre\{background:var(--soft);border:1px solid var(--line);border-radius:10px;}
puts $fd {      padding:13px 15px;overflow-x:auto;margin:0 0 14px\}}
puts $fd {  pre code\{background:none;padding:0;font-size:13.5px;line-height:1.7\}}
puts $fd {  table\{width:100%;border-collapse:collapse;font-size:14.5px;margin:0 0 16px\}}
puts $fd {  th,td\{text-align:left;padding:9px 11px;border-bottom:1px solid var(--line);vertical-align:top\}}
puts $fd {  th\{color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.04em;font-weight:650\}}
puts $fd {  .note\{border-left:3px solid var(--warn);background:var(--warn-soft);}
puts $fd {        border-radius:0 9px 9px 0;padding:13px 16px;margin:0 0 16px;font-size:14.5px\}}
puts $fd {  .note b\{display:block;margin-bottom:3px\}}
puts $fd {  a\{color:var(--tg)\}}
puts $fd {  footer\{margin-top:52px;padding-top:22px;border-top:1px solid var(--line);}
puts $fd {         font-size:13.5px;color:var(--muted)\}}
puts $fd {</style>}
puts $fd {</head>}
puts $fd {<body>}
puts $fd {<div class="wrap">}

puts $fd {<header>}
puts $fd {  <h1>Telegram Monitor</h1>}
puts $fd {  <p class="lede">Beobachtet öffentliche Telegram-Kanäle und TikTok-Konten auf}
puts $fd {     deinem eigenen Rechner und meldet sich, wenn jemand live geht. Keine Cloud,}
puts $fd {     kein Konto, keine App-Installation auf dem Telefon nötig.</p>}
puts $fd {  <div class="badges">}
puts $fd {    <span class="badge on">Standardbibliothek</span>}
puts $fd {    <span class="badge on">Docker</span>}
puts $fd {    <span class="badge on">installierbar als App</span>}
puts $fd {    <span class="badge on">Browser-Erweiterung</span>}
puts $fd {    <span class="badge">Windows · macOS · Linux</span>}
puts $fd {  </div>}
puts $fd {  <div class="cta">}
puts $fd {    <a class="btn primary" href="https://github.com/KikiKari/Projects/tree/Telegram-Monitor">Quelltext auf GitHub</a>}
puts $fd {    <a class="btn" href="/viewer">Live-Viewer öffnen</a>}
puts $fd {  </div>}
puts $fd {</header>}

puts $fd {<h2>Was es tut</h2>}
puts $fd {<div class="grid">}
puts $fd {  <div class="card">}
puts $fd {    <h3>Beobachten</h3>}
puts $fd {    <p>Fragt jeden Kanal im eingestellten Turnus ab und sammelt den Verlauf auf}
puts $fd {       der Platte — neueste Beiträge oben, anders als in Telegram selbst.</p>}
puts $fd {  </div>}
puts $fd {  <div class="card">}
puts $fd {    <h3>Erkennen</h3>}
puts $fd {    <p>Vergleicht den Zustand mit dem letzten Durchlauf. Gemeldet wird nur ein}
puts $fd {       echter Wechsel; ein fehlgeschlagener Abruf gilt nicht als „offline".</p>}
puts $fd {  </div>}
puts $fd {  <div class="card">}
puts $fd {    <h3>Melden</h3>}
puts $fd {    <p>Drei Wege gleichzeitig: Ereignisprotokoll, Systemmeldung und Webhook.}
puts $fd {       Fällt einer aus, steht der Wechsel trotzdem mit Zeitstempel fest.</p>}
puts $fd {  </div>}
puts $fd {</div>}

puts $fd {<h2>Drei Zugänge, ein Monitor</h2>}
puts $fd {<table>}
puts $fd {  <tr><th>Zugang</th><th>wofür</th></tr>}
puts $fd {  <tr><td><b>Installierte App</b></td>}
puts $fd {      <td>Vollständige Oberfläche mit allen Reitern, eigenes Fenster ohne}
puts $fd {          Adressleiste, Symbol im Startmenü</td></tr>}
puts $fd {  <tr><td><b>Browser-Erweiterung</b></td>}
puts $fd {      <td>Meldung beim Livegang, ohne dass ein Tab offen sein muss</td></tr>}
puts $fd {  <tr><td><b>Live-Viewer</b></td>}
puts $fd {      <td>Bettet den offiziellen Player ein — ohne Anmeldung, ohne Geschenk-}
puts $fd {          oder Kauf-Oberfläche. <a href="/viewer">Hier direkt ausprobieren.</a></td></tr>}
puts $fd {</table>}

puts $fd {<h2>Einrichten</h2>}
puts $fd {<ol class="steps">}
puts $fd {  <li>}
puts $fd {    <b>Repository holen</b>}
puts $fd {    <p>Branch <code>Telegram-Monitor</code> auschecken.</p>}
puts $fd {<pre><code>git clone -b Telegram-Monitor https://github.com/KikiKari/Projects.git}
puts $fd {cd Projects</code></pre>}
puts $fd {  </li>}
puts $fd {  <li>}
puts $fd {    <b>Dauerhaft starten</b>}
puts $fd {    <p>Bindet an <code>127.0.0.1:8765</code>, der Verlauf liegt im Volume}
puts $fd {       <code>monitor-data</code> und überlebt jedes Neubauen. Unter Windows}
puts $fd {       genügt ein Doppelklick auf <code>Telegram Monitor - Docker.cmd</code>.</p>}
puts $fd {<pre><code>docker compose up -d --build</code></pre>}
puts $fd {  </li>}
puts $fd {  <li>}
puts $fd {    <b>Ohne Docker</b>}
puts $fd {    <p>Der Kern braucht nur die Standardbibliothek — nichts zu installieren.</p>}
puts $fd {<pre><code>python server.py --poll-interval 120</code></pre>}
puts $fd {  </li>}
puts $fd {  <li>}
puts $fd {    <b>Als App einrichten</b>}
puts $fd {    <p>In der geöffneten Oberfläche auf <b>Als App installieren</b> klicken.}
puts $fd {       Danach liegt der Monitor als eigenes Programm im Startmenü.</p>}
puts $fd {  </li>}
puts $fd {  <li>}
puts $fd {    <b>Aufs Telefon bringen</b>}
puts $fd {    <p>Über das eigene VPN freigeben, dann die <code>https</code>-Adresse auf}
puts $fd {       dem Telefon öffnen und dort installieren. Eine <code>.apk</code> gibt es}
puts $fd {       nicht und wird auch nicht gebraucht.</p>}
puts $fd {<pre><code>tailscale serve --bg 8765</code></pre>}
puts $fd {  </li>}
puts $fd {</ol>}

puts $fd {<h2>Was hier nicht läuft</h2>}
puts $fd {<div class="note">}
puts $fd {  <b>Diese Seite ist nur die Visitenkarte.</b>}
puts $fd {  Der Monitor selbst läuft <i>nicht</i> im Web. Sein Kern ist ein}
puts $fd {  Hintergrundprozess, der dauerhaft abfragt und Zustand auf die Platte}
puts $fd {  schreibt — beides gibt es in einer serverlosen Umgebung nicht. Ausgeliefert}
puts $fd {  werden hier nur diese Seite und der Viewer, der ohnehin ohne Server}
puts $fd {  auskommt. Beobachtet wird auf deinem Rechner.}
puts $fd {</div>}

puts $fd {<h2>Grenzen</h2>}
puts $fd {<p>Gelesen wird ausschließlich, was öffentlich abrufbar ist. Anmeldeschranken}
puts $fd {   und Zugriffssperren werden nicht umgangen — wo es offizielle Einbettungen}
puts $fd {   gibt, werden die genommen. Private Telegram-Konten liefern nur Name und Bio;}
puts $fd {   das ist eine Einschränkung von Telegram, kein Fehler.</p>}
puts $fd {<p>Der Turnus bleibt höflich: ein bis fünf Minuten. Sekundentakt bringt selten}
puts $fd {   mehr Information und handelt eine Sperre ein.</p>}

puts $fd {<footer>}
puts $fd {  Läuft lokal, gehört dir. Das wiederverwendbare Muster dahinter steckt im Skill}
puts $fd {  <code>lokaler-companion</code>.}
puts $fd {</footer>}

puts $fd {}
puts $fd {</div>}
puts $fd {</body>}
puts $fd {</html>}

# Close the file
close $fd

# Print success message
puts "HTML file generated successfully: $output_file"
