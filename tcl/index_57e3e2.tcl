#!/usr/bin/env tclsh
# index.html — portiert nach tcl
# Quelle: html, Projects@tagesstatus-live-public:tagesstatus-live-public/index.html
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

package require http
package require json
package require json::write

# Create HTML document for Tagesstatus Live Public
proc create_html {} {
    set html {}
    append html {<!DOCTYPE html>}
    append html "\n" {<script type="application/json" id="cowork-artifact-meta">}
    append html "\n" [json::write object \
        name "Tagesstatus Live Public" \
        schemaVersion 1 \
        description "Öffentliche, umgebungs-unabhängige Status-Seite ohne eingebettete Keys. Fragt Tokens beim Öffnen ab (nur localStorage), zeigt ohne Key keine Daten. Holt Daten per direktem Browser-Abruf (GitHub, OpenRouter, OpenAI, Anthropic, Tailscale, ClawHub) — funktioniert voll nur gehostet/lokal außerhalb der Sandbox; CORS-geschützte Quellen brauchen ggf. einen Proxy." \
        mcpTools [json::write array] \
        mcpServerNames [json::write array]]
    append html "\n" {</script>}
    append html "\n" {<html lang="de">}
    append html "\n" {<head>}
    append html "\n" {<meta charset="utf-8">}
    append html "\n" {<meta name="viewport" content="width=device-width, initial-scale=1">}
    append html "\n" {<title>Tagesstatus Live — Public</title>}
    append html "\n" {<style>}
    append html "\n" {:root { color-scheme: light; }}
    append html "\n" {* { box-sizing: border-box; }}
    append html "\n" {body { margin:0; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif; background:#f7f7f5; color:#1d1c1a; }}
    append html "\n" {.wrap { max-width:880px; margin:0 auto; padding:20px 16px 60px; }}
    append html "\n" {h1 { font-size:22px; margin:0 0 2px; }}
    append html "\n" {.sub { color:#6b6a66; font-size:13px; margin-bottom:16px; }}
    append html "\n" {.bar { display:flex; gap:10px; align-items:center; margin-bottom:16px; flex-wrap:wrap; }}
    append html "\n" {button { font-size:13px; font-weight:600; padding:7px 13px; border:1px solid #d9d8d3; border-radius:8px; background:#fff; cursor:pointer; }}
    append html "\n" {button:hover { background:#f2f1ec; }}
    append html "\n" {button.primary { background:#1d1c1a; color:#fff; border-color:#1d1c1a; }}
    append html "\n" {.note { background:#fffdf4; border:1px solid #f0e9c8; border-radius:10px; padding:12px 14px; font-size:13px; color:#4a4734; margin-bottom:16px; line-height:1.5; }}
    append html "\n" {.section { background:#fff; border:1px solid #e8e7e3; border-radius:12px; margin-bottom:14px; overflow:hidden; }}
    append html "\n" {.section > h2 { font-size:15px; margin:0; padding:13px 16px; border-bottom:1px solid #efeee9; display:flex; align-items:center; gap:9px; }}
    append html "\n" {.section > h2 .badge { margin-left:auto; font-size:12px; font-weight:600; background:#efeee9; color:#5a5852; padding:2px 9px; border-radius:20px; }}
    append html "\n" {.body { padding:8px 16px 14px; font-size:14px; }}
    append html "\n" {.muted { color:#8a8884; }}
    append html "\n" {.err { color:#c0392b; }}
    append html "\n" {.kv { display:flex; justify-content:space-between; padding:4px 0; border-bottom:1px solid #f4f3ee; }}
    append html "\n" {.kv:last-child { border:none; }}
    append html "\n" {.kv .k { color:#6b6a66; }} 
    append html "\n" {.kv .v { font-weight:600; }}
    append html "\n" {a { color:#2b5cc4; text-decoration:none; }} 
    append html "\n" {a:hover { text-decoration:underline; }}
    append html "\n" {/* settings modal */}
    append html "\n" {.modal { position:fixed; inset:0; background:rgba(0,0,0,.35); display:none; align-items:flex-start; justify-content:center; padding:40px 16px; overflow:auto; }}
    append html "\n" {.modal.open { display:flex; }}
    append html "\n" {.card { background:#fff; border-radius:14px; max-width:560px; width:100%; padding:20px; }}
    append html "\n" {.card h3 { margin:0 0 4px; font-size:17px; }}
    append html "\n" {.card p.hint { margin:0 0 16px; font-size:12px; color:#8a8884; }}
    append html "\n" {.field { margin-bottom:12px; }}
    append html "\n" {.field label { display:block; font-size:12px; font-weight:600; color:#5a5852; margin-bottom:3px; }}
    append html "\n" {.field input { width:100%; font-size:13px; padding:7px 9px; border:1px solid #d9d8d3; border-radius:7px; font-family:ui-monospace,Menlo,monospace; }}
    append html "\n" {.field .desc { font-size:11px; color:#a8a6a1; margin-top:2px; }}
    append html "\n" {.actions { display:flex; gap:10px; justify-content:flex-end; margin-top:8px; }}
    append html "\n" {.warn { background:#fdf3f3; border:1px solid #f3d9d9; color:#9a3b3b; border-radius:8px; padding:10px 12px; font-size:12px; margin-bottom:14px; }}
    append html "\n" {</style>}
    append html "\n" {</head>}
    append html "\n" {<body>}
    append html "\n" {<div class="wrap">}
    append html "\n" {  <h1>Tagesstatus Live — Public</h1>}
    append html "\n" {  <div class="sub" id="sub">Eigenständige Version · keine Daten ohne hinterlegte Keys</div>}
    append html "\n" {}
    append html "\n" {  <div class="bar">}
    append html "\n" {    <button class="primary" id="cfgBtn">🔑 Keys eingeben / verwalten</button>}
    append html "\n" {    <button id="reloadBtn">↻ Aktualisieren</button>}
    append html "\n" {    <button id="clearBtn">Keys löschen</button>}
    append html "\n" {  </div>}
    append html "\n" {}
    append html "\n" {  <div class="note">}
    append html "\n" {    Diese Seite ist <b>nicht</b> mit einer Umgebung verbunden und enthält <b>keine</b> eingebetteten Keys.}
    append html "\n" {    Beim ersten Öffnen fragt sie deine Tokens ab; sie werden nur lokal im Browser (localStorage) gespeichert.}
    append html "\n" {    Ohne hinterlegten Key zeigt der jeweilige Abschnitt „keine Daten". Daten werden direkt per Browser-Abruf}
    append html "\n" {    bei den Anbietern geholt — das funktioniert nur außerhalb eingeschränkter Sandboxes (also als gehostete/lokale Datei).}
    append html "\n" {  </div>}
    append html "\n" {  <div class="warn">}
    append html "\n" {    Sicherheit: Keys liegen im Klartext im Browser dieses Geräts. Manche Anbieter (OpenAI, Anthropic, Tailscale)}
    append html "\n" {    blockieren Browser-Abrufe per CORS bzw. raten von Client-seitigen Keys ab — dort kann statt Daten ein}
    append html "\n" {    CORS-/401-Fehler erscheinen. Für solche Quellen ist ein kleiner Server-Proxy nötig.}
    append html "\n" {  </div>}
    append html "\n" {}
    append html "\n" {  <div id="sections"></div>}
    append html "\n" {</div>}
    append html "\n" {}
    append html "\n" {<div class="modal" id="modal">}
    append html "\n" {  <div class="card">}
    append html "\n" {    <h3>Zugangsdaten</h3>}
    append html "\n" {    <p class="hint">Leer lassen = Quelle wird übersprungen. Speicherung nur lokal (localStorage).</p>}
    append html "\n" {    <div class="field"><label>GitHub Repo (owner/repo)</label><input id="f_ghrepo" placeholder="KikiKari/OpenClaw"><div class="desc">Öffentliche Repos gehen ohne Token.</div></div>}
    append html "\n" {    <div class="field"><label>GitHub Token (optional, für privat/Codespaces)</label><input id="f_ghtoken" placeholder="github_pat_… oder ghp_…"></div>}
    append html "\n" {    <div class="field"><label>OpenRouter API Key</label><input id="f_or" placeholder="sk-or-v1-…"><div class="desc">Verbrauch & Restguthaben.</div></div>}
    append html "\n" {    <div class="field"><label>OpenAI Admin Key</label><input id="f_oai" placeholder="sk-admin-…"><div class="desc">Org-Kosten (CORS evtl. blockiert).</div></div>}
    append html "\n" {    <div class="field"><label>Anthropic Admin Key</label><input id="f_anth" placeholder="sk-ant-admin…"><div class="desc">Claude Kosten/Nutzung (CORS evtl. blockiert).</div></div>}
    append html "\n" {    <div class="field"><label>Tailscale API Token + Tailnet</label><input id="f_ts" placeholder="tskey-api-…"><input id="f_tsnet" placeholder="Tailnet, z.B. example.org oder -" style="margin-top:6px"><div class="desc">Geräte/Status (CORS evtl. blockiert).</div></div>}
    append html "\n" {    <div class="field"><label>ClawHub Skill-Slugs (kommagetrennt)</label><input id="f_clawhub" placeholder="cluster-gateway, mcp-tool-utils, json-utils"><div class="desc">Öffentliche ClawHub-API je Skill (kein Token nötig, CORS erlaubt) — Version, Downloads, Scan-Status.</div></div>}
    append html "\n" {    <div class="actions"><button id="cancelBtn">Abbrechen</button><button class="primary" id="saveBtn">Speichern & laden</button></div>}
    append html "\n" {  </div>}
    append html "\n" {</div>}
    append html "\n" {}
    append html "\n" {<script>}
    append html "\n" {const LS = \"tsl_public_keys\";}
    append html "\n" {const esc = s => (s==null?\"\":String(s)).replace(/[&<>\"/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;'}[c]));}
    append html "\n" {function getKeys(){ try { return JSON.parse(localStorage.getItem(LS)||\"{}\"; } catch(e){ return {}; } }}
    append html "\n" {function setKeys(o){ localStorage.setItem(LS, JSON.stringify(o)); }}
    append html "\n" {}
    append html "\n" {// ---- Modal ----}
    append html "\n" {const modal = document.getElementById(\"modal\";}
    append html "\n" {function openCfg(){}
    append html "\n" {  const k = getKeys();}"
    append html "\n" {  f_ghrepo.value=k.ghrepo||\"\"; f_ghtoken.value=k.ghtoken||\"\"; f_or.value=k.or||\"\";"
    append html "\n" {  f_oai.value=k.oai||\"\"; f_anth.value=k.anth||\"\"; f_ts.value=k.ts||\"\"; f_tsnet.value=k.tsnet||\"\"; f_clawhub.value=k.clawhub||\"\";"
    append html "\n" {  modal.classList.add(\"open\";"
    append html "\n" {}
    append html "\n" {function closeCfg(){ modal.classList.remove(\"open\"; }}"
    append html "\n" {cfgBtn.onclick=openCfg; cancelBtn.onclick=closeCfg;"
    append html "\n" {saveBtn.onclick=()=>{ setKeys({ ghrepo:f_ghrepo.value.trim(), ghtoken:f_ghtoken.value.trim(), or:f_or.value.trim(), oai:f_oai.value.trim(), anth:f_anth.value.trim(), ts:f_ts.value.trim(), tsnet:f_tsnet.value.trim(), clawhub:f_clawhub.value.trim() }); closeCfg(); loadAll(); };"
    append html "\n" {clearBtn.onclick=()=>{ if(confirm(\"Alle hinterlegten Keys löschen?\")){ localStorage.removeItem(LS; loadAll(); } };"
    append html "\n" {reloadBtn.onclick=()=>loadAll();"
    append html "\n" {}
    append html "\n" {// ---- Sections scaffold ----}
    append html "\n" {const SECTIONS = ["
    append html "\n" {  {id:\"github\", title:\"GitHub — PRs & Branches\"},"
    append html "\n" {  {id:\"openrouter\", title:\"OpenRouter — Verbrauch & Guthaben\"},"
    append html "\n" {  {id:\"openai\", title:\"OpenAI — Kosten (30 Tage\"},"
    append html "\n" {  {id:\"anthropic\", title:\"Claude / Anthropic — Kosten (30 Tage\"},"
    append html "\n" {  {id:\"tailscale\", title:\"Tailscale — Geräte\"},"
    append html "\n" {  {id:\"clawhub\", title:\"ClawHub — meine Skills\"},"
    append html "\n" {  {id:\"perplexity\", title:\"Perplexity — Hinweis\"}"
    append html "\n" {];"
    append html "\n" {function scaffold(){"
    append html "\n" {  document.getElementById(\"sections\").innerHTML = SECTIONS.map(s =>"
    append html "\n" {    '<div class=\"section\"><h2>'+esc(s.title)+'<span class=\"badge\" id=\"b-'+s.id+'\">–</span></h2>'+"
    append html "\n" {    '<div class=\"body\" id=\"c-'+s.id+'\"><span class=\"muted\">…</span></div></div>').join(\"\";"
    append html "\n" {}
    append html "\n" {function setB(id,v){ const e=document.getElementById(\"b-\"+id; if(e) e.textContent=v; }}"
    append html "\n" {function render(id,html){ const e=document.getElementById(\"c-\"+id; if(e) e.innerHTML=html; }}"
    append html "\n" {const noKey = id => { setB(id,\"–\"; render(id,'<span class=\"muted\">Kein Token hinterlegt — keine Daten.</span>'); };"
    append html "\n" {}
    append html "\n" {async function fetchJson(url, headers){"
    append html "\n" {  const r = await fetch(url, { headers: headers||{} });"
    append html "\n" {  const txt = await r.text();"
    append html "\n" {  let data=null; try { data = JSON.parse(txt; } catch(e){}"
    append html "\n" {  if(!r.ok) throw new Error(\"HTTP \"+r.status+(data&&data.error?(\" · \"+(data.error.message||data.error)) : \"\";"
    append html "\n" {  return data;"
    append html "\n" {}
    append html "\n" {async function loadGitHub(){"
    append html "\n" {  const k=getKeys(); const repo=k.ghrepo||\"\";"
    append html "\n" {  if(!repo){ noKey(\"github\"; return; }}"
    append html "\n" {  try {"
    append html "\n" {    const h = k.ghtoken ? {Authorization:\"Bearer \"+k.ghtoken, Accept:\"application/vnd.github+json\"} : {Accept:\"application/vnd.github+json\"};"
    append html "\n" {    const [prs, br] = await Promise.all(["
    append html "\n" {      fetchJson(\"https://api.github.com/repos/\"+repo+\"/pulls?state=open&per_page=20\", h,"
    append html "\n" {      fetchJson(\"https://api.github.com/repos/\"+repo+\"/branches?per_page=100\", h"
    append html "\n" {    ]"
    append html "\n" {    setB(\"github\", (prs||[]).length;"
    append html "\n" {    let html = (prs&&prs.length) ? prs.map(p=>'<div class=\"kv\"><span class=\"k\"><a href=\"'+esc(p.html_url)+'\" target=\"_blank\">#'+p.number+' '+esc(p.title)+'</a></span><span class=\"v\">'+esc((p.user&&p.user.login)||\"\")+'</span></div>').join(\"\" : '<span class=\"muted\">Keine offenen PRs.</span>';"
    append html "\n" {    if(br&&br.length) html+='<div class=\"kv\"><span class=\"k\">Branches</span><span class=\"v\">'+br.length+'</span></div>';"
    append html "\n" {    render(\"github\", html;"
    append html "\n" {  } catch(e){ setB(\"github\",\"!\"; render(\"github\",'<span class=\"err\">'+esc(e.message)+'</span>'; }}"
    append html "\n" {async function loadOpenRouter(){"
    append html "\n" {  const k=getKeys(); if(!k.or){ noKey(\"openrouter\"; return; }}"
    append html "\n" {  try {"
    append html "\n" {    const d = await fetchJson(\"https://openrouter.ai/api/v1/key\", {Authorization:\"Bearer \"+k.or});"
    append html "\n" {    const x = (d&&d.data)||{};"
    append html "\n" {    setB(\"openrouter\",\"ok\";"
    append html "\n" {    render(\"openrouter\","
    append html "\n" {      '<div class=\"kv\"><span class=\"k\">Verbraucht (gesamt)</span><span class=\"v\">'+esc(x.usage)+'</span></div>'+"
    append html "\n" {      '<div class=\"kv\"><span class=\"k\">Heute / Woche / Monat</span><span class=\"v\">'+esc(x.usage_daily)+' / '+esc(x.usage_weekly)+' / '+esc(x.usage_monthly)+'</span></div>'+"
    append html "\n" {      '<div class=\"kv\"><span class=\"k\">Limit / Rest</span><span class=\"v\">'+esc(x.limit==null?\"∞\":x.limit)+' / '+esc(x.limit_remaining==null?\"∞\":x.limit_remaining)+'</span></div>');"
    append html "\n" {  } catch(e){ setB(\"openrouter\",\"!\"; render(\"openrouter\",'<span class=\"err\">'+esc(e.message)+'</span>'; }}"
    append html "\n" {function iso30(){ const d=new Date(); d.setDate(d.getDate()-30; return d.toISOString().slice(0,10; }}"
    append html "\n" {async function loadOpenAI(){"
    append html "\n" {  const k=getKeys(); if(!k.oai){ noKey(\"openai\"; return; }}"
    append html "\n" {  try {"
    append html "\n" {    const start = Math.floor((Date.now()-30*864e5/1000;"
    append html "\n" {    const d = await fetchJson(\"https://api.openai.com/v1/organization/costs?start_time=\"+start+\"&limit=30\", {Authorization:\"Bearer \"+k.oai});"
    append html "\n" {    let total=0; (d&&d.data||[]).forEach(b=>(b.results||[]).forEach(r=>{ total += (r.amount&&r.amount.value||0; }));"
    append html "\n" {    setB(\"openai\",\"ok\";"
    append html "\n" {    render(\"openai\",'<div class=\"kv\"><span class=\"k\">Kosten 30 Tage (USD)</span><span class=\"v\">'+total.toFixed(2)+'</span></div>');"
    append html "\n" {  } catch(e){ setB(\"openai\",\"!\"; render(\"openai\",'<span class=\"err\">'+esc(e.message)+' (oft CORS/Admin-Key nötig)</span>'; }}"
    append html "\n" {async function loadAnthropic(){"
    append html "\n" {  const k=getKeys(); if(!k.anth){ noKey(\"anthropic\"; return; }}"
    append html "\n" {  try {"
    append html "\n" {    const d = await fetchJson(\"https://api.anthropic.com/v1/organizations/cost_report?starting_at=\"+iso30(), {\"x-api-key\":k.anth,\"anthropic-version\":\"2023-06-01\"});"
    append html "\n" {    setB(\"anthropic\",\"ok\";"
    append html "\n" {    render(\"anthropic\",'<div class=\"kv\"><span class=\"k\">Cost-Report</span><span class=\"v\">'+esc(JSON.stringify(d).slice(0,80))+'…</span></div>');"
    append html "\n" {  } catch(e){ setB(\"anthropic\",\"!\"; render(\"anthropic\",'<span class=\"err\">'+esc(e.message)+' (Browser-CORS oft blockiert)</span>'; }}"
    append html "\n" {async function loadTailscale(){"
    append html "\n" {  const k=getKeys(); if(!k.ts){ noKey(\"tailscale\"; return; }}"
    append html "\n" {  try {"
    append html "\n" {    const net = k.tsnet||\"-\";"
    append html "\n" {    const d = await fetchJson(\"https://api.tailscale.com/api/v2/tailnet/\"+encodeURIComponent(net)+\"/devices\", {Authorization:\"Bearer \"+k.ts});"
    append html "\n" {    const dev = (d&&d.devices)||[];"
    append html "\n" {    setB(\"tailscale\", dev.length;"
    append html "\n" {    render(\"tailscale\", dev.length ? dev.map(x=>'<div class=\"kv\"><span class=\"k\">'+esc(x.hostname||x.name)+'</span><span class=\"v\">'+(x.lastSeen?esc(x.lastSeen.slice(0,10:\"\"+'</span></div>').join(\"\" : '<span class=\"muted\">Keine Geräte.</span>';"
    append html "\n" {  } catch(e){ setB(\"tailscale\",\"!\"; render(\"tailscale\",'<span class=\"err\">'+esc(e.message)+' (Browser-CORS oft blockiert)</span>'; }}"
    append html "\n" {async function loadClawHub(){"
    append html "\n" {  const k=getKeys(); const slugs=(k.clawhub||\"\").split(\",\").map(s=>s.trim().filter(Boolean;"
    append html "\n" {  if(!slugs.length){ noKey(\"clawhub\"; return; }}"
    append html "\n" {  const rows=[]; let okc=0, total=0;"
    append html "\n" {  for(const slug of slugs){"
    append html "\n" {    try {"
    append html "\n" {      const d = await fetchJson(\"https://clawhub.ai/api/v1/skills/\"+encodeURIComponent(slug));"
    append html "\n" {      const sk=(d&&d.skill)||{}; const ver=(d&&d.latestVersion&&d.latestVersion.version)||(sk.tags&&sk.tags.latest)||\"?\";"
    append html "\n" {      const dl=(sk.stats&&(sk.stats.downloads!=null?sk.stats.downloads:sk.stats.downloadsAllTime));"
    append html "\n" {      const verdict=(d&&d.moderation&&d.moderation.verdict)|| (d&&d.moderation&&d.moderation.isSuspicious?\"suspicious\":\"clean\");"
    append html "\n" {      total+=(dl||0;"
    append html "\n" {      rows.push('<div class=\"kv\"><span class=\"k\"><a href=\"https://clawhub.ai/'+esc(sk.ownerHandle||\"\")+'/'+esc(slug)+'\" target=\"_blank\">'+esc(sk.displayName||slug)+'</a> · v'+esc(ver)+'</span><span class=\"v\">'+(dl!=null?dl+' DL':'')+' · '+esc(verdict)+'</span></div>');"
    append html "\n" {      okc++;"
    append html "\n" {    } catch(e){ rows.push('<div class=\"kv\"><span class=\"k\">'+esc(slug)+'</span><span class=\"v err\">'+esc(e.message)+'</span></div>'); }}"
    append html "\n" {  setB(\"clawhub\", okc+\"/\"+slugs.length;"
    append html "\n" {  render(\"clawhub\", rows.join(\"\" + (total?'<div class=\"kv\"><span class=\"k\">Downloads gesamt</span><span class=\"v\">'+total+'</span></div>':''))"
    append html "\n" {function loadPerplexity(){"
    append html "\n" {  setB(\"perplexity\",\"i\";"
    append html "\n" {  render(\"perplexity\",'<span class=\"muted\">Perplexity bietet keinen Verbrauchs-/Credits-Endpunkt. Credits nur im Dashboard sichtbar — daher hier keine Live-Daten.</span>');"
    append html "\n" {}
    append html "\n" {function loadAll(){"
    append html "\n" {  scaffold();"
    append html "\n" {  const k=getKeys();"
    append html "\n" {  document.getElementById(\"sub\").textContent = Object.values(k).some(Boolean) ? \"Eigenständige Version · \"+(new Date()).toLocaleString(\"de-DE\" : \"Eigenständige Version · keine Keys hinterlegt — klicke „Keys eingeben\".;"
    append html "\n" {  loadGitHub(); loadOpenRouter(); loadOpenAI(); loadAnthropic(); loadTailscale(); loadClawHub(); loadPerplexity();"
    append html "\n" {}
    append html "\n" {scaffold();"
    append html "\n" {if(!Object.values(getKeys()).some(Boolean)) openCfg();"
    append html "\n" {loadAll();"
    append html "\n" {</script>}
    append html "\n" {</body>}
    append html "\n" {</html>}
    return $html
}

# Main execution
if {$argc != 1} {
    puts stderr "Usage: $argv0 <output-file>"
    exit 1
}

set output_file [lindex $argv 0]
set html_content [create_html]

if {[catch {open $output_file w} fid]} {
    puts stderr "Error: Could not open file '$output_file' for writing"
    exit 1
}

puts $fid $html_content
close $fid

puts "HTML file generated successfully: $output_file"
