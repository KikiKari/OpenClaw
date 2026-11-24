// abstraction-provenance: {"artifact_sha256": "132326ec4e179efc51e48933b15b5e021b6dbc97fe32e20f2fc3e0183c9dea92", "source_sha256": "57e3e28b7c96948ea289f7d9401b6d0bf990d118129de570394784d35e23cf4c", "target_language": "cpp"}
// index.html — portiert nach cpp
// Quelle: html, Projects@tagesstatus-live-public:tagesstatus-live-public/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <string>
#include <sstream>
#include <map>
#include <vector>
#include <algorithm>
#include <iomanip>
#include <ctime>

class HTMLGenerator {
private:
    std::ofstream file;
    
public:
    HTMLGenerator(const std::string& filename) {
        file.open(filename);
        if (!file.is_open()) {
            throw std::runtime_error("Could not open file: " + filename);
        }
    }
    
    ~HTMLGenerator() {
        if (file.is_open()) {
            file.close();
        }
    }
    
    void generateHTML() {
        // DOCTYPE
        file << "<!DOCTYPE html>\n";
        
        // Script tag with JSON metadata
        file << "<script type=\"application/json\" id=\"cowork-artifact-meta\">\n";
        file << "{\n";
        file << "  \"name\": \"Tagesstatus Live Public\",\n";
        file << "  \"schemaVersion\": 1,\n";
        file << "  \"description\": \"Öffentliche, umgebungs-unabhängige Status-Seite ohne eingebettete Keys. Fragt Tokens beim Öffnen ab (nur localStorage), zeigt ohne Key keine Daten. Holt Daten per direktem Browser-Abruf (GitHub, OpenRouter, OpenAI, Anthropic, Tailscale, ClawHub) — funktioniert voll nur gehostet/lokal außerhalb der Sandbox; CORS-geschützte Quellen brauchen ggf. einen Proxy.\",\n";
        file << "  \"mcpTools\": [],\n";
        file << "  \"mcpServerNames\": []\n";
        file << "}\n";
        file << "</script>\n";
        
        // HTML start
        file << "<html lang=\"de\">\n";
        file << "<head>\n";
        file << "<meta charset=\"utf-8\">\n";
        file << "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n";
        file << "<title>Tagesstatus Live — Public</title>\n";
        file << "<style>\n";
        file << ":root { color-scheme: light; }\n";
        file << "* { box-sizing: border-box; }\n";
        file << "body { margin:0; font-family:-apple-system,BlinkMacSystemFont,\"Segoe UI\",Roboto,Helvetica,Arial,sans-serif; background:#f7f7f5; color:#1d1c1a; }\n";
        file << ".wrap { max-width:880px; margin:0 auto; padding:20px 16px 60px; }\n";
        file << "h1 { font-size:22px; margin:0 0 2px; }\n";
        file << ".sub { color:#6b6a66; font-size:13px; margin-bottom:16px; }\n";
        file << ".bar { display:flex; gap:10px; align-items:center; margin-bottom:16px; flex-wrap:wrap; }\n";
        file << "button { font-size:13px; font-weight:600; padding:7px 13px; border:1px solid #d9d8d3; border-radius:8px; background:#fff; cursor:pointer; }\n";
        file << "button:hover { background:#f2f1ec; }\n";
        file << "button.primary { background:#1d1c1a; color:#fff; border-color:#1d1c1a; }\n";
        file << ".note { background:#fffdf4; border:1px solid #f0e9c8; border-radius:10px; padding:12px 14px; font-size:13px; color:#4a4734; margin-bottom:16px; line-height:1.5; }\n";
        file << ".section { background:#fff; border:1px solid #e8e7e3; border-radius:12px; margin-bottom:14px; overflow:hidden; }\n";
        file << ".section > h2 { font-size:15px; margin:0; padding:13px 16px; border-bottom:1px solid #efeee9; display:flex; align-items:center; gap:9px; }\n";
        file << ".section > h2 .badge { margin-left:auto; font-size:12px; font-weight:600; background:#efeee9; color:#5a5852; padding:2px 9px; border-radius:20px; }\n";
        file << ".body { padding:8px 16px 14px; font-size:14px; }\n";
        file << ".muted { color:#8a8884; }\n";
        file << ".err { color:#c0392b; }\n";
        file << ".kv { display:flex; justify-content:space-between; padding:4px 0; border-bottom:1px solid #f4f3ee; }\n";
        file << ".kv:last-child { border:none; }\n";
        file << ".kv .k { color:#6b6a66; } .kv .v { font-weight:600; }\n";
        file << "a { color:#2b5cc4; text-decoration:none; } a:hover { text-decoration:underline; }\n";
        file << "/* settings modal */\n";
        file << ".modal { position:fixed; inset:0; background:rgba(0,0,0,.35); display:none; align-items:flex-start; justify-content:center; padding:40px 16px; overflow:auto; }\n";
        file << ".modal.open { display:flex; }\n";
        file << ".card { background:#fff; border-radius:14px; max-width:560px; width:100%; padding:20px; }\n";
        file << ".card h3 { margin:0 0 4px; font-size:17px; }\n";
        file << ".card p.hint { margin:0 0 16px; font-size:12px; color:#8a8884; }\n";
        file << ".field { margin-bottom:12px; }\n";
        file << ".field label { display:block; font-size:12px; font-weight:600; color:#5a5852; margin-bottom:3px; }\n";
        file << ".field input { width:100%; font-size:13px; padding:7px 9px; border:1px solid #d9d8d3; border-radius:7px; font-family:ui-monospace,Menlo,monospace; }\n";
        file << ".field .desc { font-size:11px; color:#a8a6a1; margin-top:2px; }\n";
        file << ".actions { display:flex; gap:10px; justify-content:flex-end; margin-top:8px; }\n";
        file << ".warn { background:#fdf3f3; border:1px solid #f3d9d9; color:#9a3b3b; border-radius:8px; padding:10px 12px; font-size:12px; margin-bottom:14px; }\n";
        file << "</style>\n";
        file << "</head>\n";
        file << "<body>\n";
        file << "<div class=\"wrap\">\n";
        file << "  <h1>Tagesstatus Live — Public</h1>\n";
        file << "  <div class=\"sub\" id=\"sub\">Eigenständige Version · keine Daten ohne hinterlegte Keys</div>\n\n";
        file << "  <div class=\"bar\">\n";
        file << "    <button class=\"primary\" id=\"cfgBtn\">🔑 Keys eingeben / verwalten</button>\n";
        file << "    <button id=\"reloadBtn\">↻ Aktualisieren</button>\n";
        file << "    <button id=\"clearBtn\">Keys löschen</button>\n";
        file << "  </div>\n\n";
        file << "  <div class=\"note\">\n";
        file << "    Diese Seite ist <b>nicht</b> mit einer Umgebung verbunden und enthält <b>keine</b> eingebetteten Keys.\n";
        file << "    Beim ersten Öffnen fragt sie deine Tokens ab; sie werden nur lokal im Browser (localStorage) gespeichert.\n";
        file << "    Ohne hinterlegten Key zeigt der jeweilige Abschnitt „keine Daten\". Daten werden direkt per Browser-Abruf\n";
        file << "    bei den Anbietern geholt — das funktioniert nur außerhalb eingeschränkter Sandboxes (also als gehostete/lokale Datei).\n";
        file << "  </div>\n";
        file << "  <div class=\"warn\">\n";
        file << "    Sicherheit: Keys liegen im Klartext im Browser dieses Geräts. Manche Anbieter (OpenAI, Anthropic, Tailscale)\n";
        file << "    blockieren Browser-Abrufe per CORS bzw. raten von Client-seitigen Keys ab — dort kann statt Daten ein\n";
        file << "    CORS-/401-Fehler erscheinen. Für solche Quellen ist ein kleiner Server-Proxy nötig.\n";
        file << "  </div>\n\n";
        file << "  <div id=\"sections\"></div>\n";
        file << "</div>\n\n";
        file << "<div class=\"modal\" id=\"modal\">\n";
        file << "  <div class=\"card\">\n";
        file << "    <h3>Zugangsdaten</h3>\n";
        file << "    <p class=\"hint\">Leer lassen = Quelle wird übersprungen. Speicherung nur lokal (localStorage).</p>\n";
        file << "    <div class=\"field\"><label>GitHub Repo (owner/repo)</label><input id=\"f_ghrepo\" placeholder=\"KikiKari/OpenClaw\"><div class=\"desc\">Öffentliche Repos gehen ohne Token.</div></div>\n";
        file << "    <div class=\"field\"><label>GitHub Token (optional, für privat/Codespaces)</label><input id=\"f_ghtoken\" placeholder=\"github_pat_… oder ghp_…\"></div>\n";
        file << "    <div class=\"field\"><label>OpenRouter API Key</label><input id=\"f_or\" placeholder=\"sk-or-v1-…\"><div class=\"desc\">Verbrauch & Restguthaben.</div></div>\n";
        file << "    <div class=\"field\"><label>OpenAI Admin Key</label><input id=\"f_oai\" placeholder=\"sk-admin-…\"><div class=\"desc\">Org-Kosten (CORS evtl. blockiert).</div></div>\n";
        file << "    <div class=\"field\"><label>Anthropic Admin Key</label><input id=\"f_anth\" placeholder=\"sk-ant-admin…\"><div class=\"desc\">Claude Kosten/Nutzung (CORS evtl. blockiert).</div></div>\n";
        file << "    <div class=\"field\"><label>Tailscale API Token + Tailnet</label><input id=\"f_ts\" placeholder=\"tskey-api-…\"><input id=\"f_tsnet\" placeholder=\"Tailnet, z.B. example.org oder -\" style=\"margin-top:6px\"><div class=\"desc\">Geräte/Status (CORS evtl. blockiert).</div></div>\n";
        file << "    <div class=\"field\"><label>ClawHub Skill-Slugs (kommagetrennt)</label><input id=\"f_clawhub\" placeholder=\"cluster-gateway, mcp-tool-utils, json-utils\"><div class=\"desc\">Öffentliche ClawHub-API je Skill (kein Token nötig, CORS erlaubt) — Version, Downloads, Scan-Status.</div></div>\n";
        file << "    <div class=\"actions\"><button id=\"cancelBtn\">Abbrechen</button><button class=\"primary\" id=\"saveBtn\">Speichern & laden</button></div>\n";
        file << "  </div>\n";
        file << "</div>\n\n";
        
        // JavaScript section
        file << "<script>\n";
        file << "const LS = \"tsl_public_keys\";\n";
        file << "const esc = s => (s==null?\"\":String(s)).replace(/[&<>\\\"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\\\"':'&quot;'}[c]));\n";
        file << "function getKeys(){ try { return JSON.parse(localStorage.getItem(LS)||\"{}\"); } catch(e){ return {}; } }\n";
        file << "function setKeys(o){ localStorage.setItem(LS, JSON.stringify(o)); }\n\n";
        file << "// ---- Modal ----\n";
        file << "const modal = document.getElementById(\"modal\");\n";
        file << "function openCfg(){\n";
        file << "  const k = getKeys();\n";
        file << "  f_ghrepo.value=k.ghrepo||\"\"; f_ghtoken.value=k.ghtoken||\"\"; f_or.value=k.or||\"\";\n";
        file << "  f_oai.value=k.oai||\"\"; f_anth.value=k.anth||\"\"; f_ts.value=k.ts||\"\"; f_tsnet.value=k.tsnet||\"\"; f_clawhub.value=k.clawhub||\"\";\n";
        file << "  modal.classList.add(\"open\");\n";
        file << "}\n";
        file << "function closeCfg(){ modal.classList.remove(\"open\"); }\n";
        file << "cfgBtn.onclick=openCfg; cancelBtn.onclick=closeCfg;\n";
        file << "saveBtn.onclick=()=>{ setKeys({ ghrepo:f_ghrepo.value.trim(), ghtoken:f_ghtoken.value.trim(), or:f_or.value.trim(), oai:f_oai.value.trim(), anth:f_anth.value.trim(), ts:f_ts.value.trim(), tsnet:f_tsnet.value.trim(), clawhub:f_clawhub.value.trim() }); closeCfg(); loadAll(); };\n";
        file << "clearBtn.onclick=()=>{ if(confirm(\"Alle hinterlegten Keys löschen?\")){ localStorage.removeItem(LS); loadAll(); } };\n";
        file << "reloadBtn.onclick=()=>loadAll();\n\n";
        file << "// ---- Sections scaffold ----\n";
        file << "const SECTIONS = [\n";
        file << "  {id:\"github\", title:\"GitHub — PRs & Branches\"},\n";
        file << "  {id:\"openrouter\", title:\"OpenRouter — Verbrauch & Guthaben\"},\n";
        file << "  {id:\"openai\", title:\"OpenAI — Kosten (30 Tage)\"},\n";
        file << "  {id:\"anthropic\", title:\"Claude / Anthropic — Kosten (30 Tage)\"},\n";
        file << "  {id:\"tailscale\", title:\"Tailscale — Geräte\"},\n";
        file << "  {id:\"clawhub\", title:\"ClawHub — meine Skills\"},\n";
        file << "  {id:\"perplexity\", title:\"Perplexity — Hinweis\"}\n";
        file << "];\n";
        file << "function scaffold(){\n";
        file << "  document.getElementById(\"sections\").innerHTML = SECTIONS.map(s =>\n";
        file << "    '<div class=\"section\"><h2>'+esc(s.title)+'<span class=\"badge\" id=\"b-'+s.id+'\">–</span></h2>'+";
        file << "'<div class=\"body\" id=\"c-'+s.id+'\"><span class=\"muted\">…</span></div></div>').join(\"\");\n";
        file << "}\n";
        file << "function setB(id,v){ const e=document.getElementById(\"b-\"+id); if(e) e.textContent=v; }\n";
        file << "function render(id,html){ const e=document.getElementById(\"c-\"+id); if(e) e.innerHTML=html; }\n";
        file << "const noKey = id => { setB(id,\"–\"); render(id,'<span class=\"muted\">Kein Token hinterlegt — keine Daten.</span>'); };\n\n";
        file << "async function fetchJson(url, headers){\n";
        file << "  const r = await fetch(url, { headers: headers||{} });\n";
        file << "  const txt = await r.text();\n";
        file << "  let data=null; try { data = JSON.parse(txt); } catch(e){}\n";
        file << "  if(!r.ok) throw new Error(\"HTTP \"+r.status+(data&&data.error?(\" · \"+(data.error.message||data.error)) : \"\"));\n";
        file << "  return data;\n";
        file << "}\n\n";
        file << "async function loadGitHub(){\n";
        file << "  const k=getKeys(); const repo=k.ghrepo||\"\";\n";
        file << "  if(!repo){ noKey(\"github\"); return; }\n";
        file << "  try {\n";
        file << "    const h = k.ghtoken ? {Authorization:\"Bearer \"+k.ghtoken, Accept:\"application/vnd.github+json\"} : {Accept:\"application/vnd.github+json\"};\n";
        file << "    const [prs, br] = await Promise.all([\n";
        file << "      fetchJson(\"https://api.github.com/repos/\"+repo+\"/pulls?state=open&per_page=20\", h),\n";
        file << "      fetchJson(\"https://api.github.com/repos/\"+repo+\"/branches?per_page=100\", h)\n";
        file << "    ]);\n";
        file << "    setB(\"github\", (prs||[]).length);\n";
        file << "    let html = (prs&&prs.length) ? prs.map(p=>'<div class=\"kv\"><span class=\"k\"><a href=\"'+esc(p.html_url)+'\" target=\"_blank\">#'+p.number+' '+esc(p.title)+'</a></span><span class=\"v\">'+esc((p.user&&p.user.login)||\"\")+'</span></div>').join(\"\") : '<span class=\"muted\">Keine offenen PRs.</span>';\n";
        file << "    if(br&&br.length) html+='<div class=\"kv\"><span class=\"k\">Branches</span><span class=\"v\">'+br.length+'</span></div>';\n";
        file << "    render(\"github\", html);\n";
        file << "  } catch(e){ setB(\"github\",\"!\"); render(\"github\",'<span class=\"err\">'+esc(e.message)+'</span>'); }\n";
        file << "}\n";
        file << "async function loadOpenRouter(){\n";
        file << "  const k=getKeys(); if(!k.or){ noKey(\"openrouter\"); return; }\n";
        file << "  try {\n";
        file << "    const d = await fetchJson(\"https://openrouter.ai/api/v1/key\", {Authorization:\"Bearer \"+k.or});\n";
        file << "    const x = (d&&d.data)||{};\n";
        file << "    setB(\"openrouter\",\"ok\");\n";
        file << "    render(\"openrouter\",\n";
        file << "      '<div class=\"kv\"><span class=\"k\">Verbraucht (gesamt)</span><span class=\"v\">'+esc(x.usage)+'</span></div>'+";
        file << "'<div class=\"kv\"><span class=\"k\">Heute / Woche / Monat</span><span class=\"v\">'+esc(x.usage_daily)+' / '+esc(x.usage_weekly)+' / '+esc(x.usage_monthly)+'</span></div>'+";
        file << "'<div class=\"kv\"><span class=\"k\">Limit / Rest</span><span class=\"v\">'+esc(x.limit==null?\"∞\":x.limit)+' / '+esc(x.limit_remaining==null?\"∞\":x.limit_remaining)+'</span></div>');\n";
        file << "  } catch(e){ setB(\"openrouter\",\"!\"); render(\"openrouter\",'<span class=\"err\">'+esc(e.message)+'</span>'); }\n";
        file << "}\n";
        file << "function iso30(){ const d=new Date(); d.setDate(d.getDate()-30); return d.toISOString().slice(0,10); }\n";
        file << "async function loadOpenAI(){\n";
        file << "  const k=getKeys(); if(!k.oai){ noKey(\"openai\"); return; }\n";
        file << "  try {\n";
        file << "    const start = Math.floor((Date.now()-30*864e5)/1000);\n";
        file << "    const d = await fetchJson(\"https://api.openai.com/v1/organization/costs?start_time=\"+start+\"&limit=30\", {Authorization:\"Bearer \"+k.oai});\n";
        file << "    let total=0; (d&&d.data||[]).forEach(b=>(b.results||[]).forEach(r=>{ total += (r.amount&&r.amount.value)||0; }));\n";
        file << "    setB(\"openai\",\"ok\");\n";
        file << "    render(\"openai\",'<div class=\"kv\"><span class=\"k\">Kosten 30 Tage (USD)</span><span class=\"v\">'+total.toFixed(2)+'</span></div>');\n";
        file << "  } catch(e){ setB(\"openai\",\"!\"); render(\"openai\",'<span class=\"err\">'+esc(e.message)+' (oft CORS/Admin-Key nötig)</span>'); }\n";
        file << "}\n";
        file << "async function loadAnthropic(){\n";
        file << "  const k=getKeys(); if(!k.anth){ noKey(\"anthropic\"); return; }\n";
        file << "  try {\n";
        file << "    const d = await fetchJson(\"https://api.anthropic.com/v1/organizations/cost_report?starting_at=\"+iso30(), {\"x-api-key\":k.anth,\"anthropic-version\":\"2023-06-01\"});\n";
        file << "    setB(\"anthropic\",\"ok\");\n";
        file << "    render(\"anthropic\",'<div class=\"kv\"><span class=\"k\">Cost-Report</span><span class=\"v\">'+esc(JSON.stringify(d).slice(0,80))+'…</span></div>');\n";
        file << "  } catch(e){ setB(\"anthropic\",\"!\"); render(\"anthropic\",'<span class=\"err\">'+esc(e.message)+' (Browser-CORS oft blockiert)</span>'); }\n";
        file << "}\n";
        file << "async function loadTailscale(){\n";
        file << "  const k=getKeys(); if(!k.ts){ noKey(\"tailscale\"); return; }\n";
        file << "  try {\n";
        file << "    const net = k.tsnet||\"-\";\n";
        file << "    const d = await fetchJson(\"https://api.tailscale.com/api/v2/tailnet/\"+encodeURIComponent(net)+\"/devices\", {Authorization:\"Bearer \"+k.ts});\n";
        file << "    const dev = (d&&d.devices)||[];\n";
        file << "    setB(\"tailscale\", dev.length);\n";
        file << "    render(\"tailscale\", dev.length ? dev.map(x=>'<div class=\"kv\"><span class=\"k\">'+esc(x.hostname||x.name)+'</span><span class=\"v\">'+(x.lastSeen?esc(x.lastSeen.slice(0,10)):\"\")+'</span></div>').join(\"\") : '<span class=\"muted\">Keine Geräte.</span>');\n";
        file << "  } catch(e){ setB(\"tailscale\",\"!\"); render(\"tailscale\",'<span class=\"err\">'+esc(e.message)+' (Browser-CORS oft blockiert)</span>'); }\n";
        file << "}\n";
        file << "async function loadClawHub(){\n";
        file << "  const k=getKeys(); const slugs=(k.clawhub||\"\").split(\",\").map(s=>s.trim()).filter(Boolean);\n";
        file << "  if(!slugs.length){ noKey(\"clawhub\"); return; }\n";
        file << "  const rows=[]; let okc=0, total=0;\n";
        file << "  for(const slug of slugs){\n";
        file << "    try {\n";
        file << "      const d = await fetchJson(\"https://clawhub.ai/api/v1/skills/\"+encodeURIComponent(slug));\n";
        file << "      const sk=(d&&d.skill)||{}; const ver=(d&&d.latestVersion&&d.latestVersion.version)||(sk.tags&&sk.tags.latest)||\"?\";\n";
        file << "      const dl=(sk.stats&&(sk.stats.downloads!=null?sk.stats.downloads:sk.stats.downloadsAllTime));\n";
        file << "      const verdict=(d&&d.moderation&&d.moderation.verdict)|| (d&&d.moderation&&d.moderation.isSuspicious?\"suspicious\":\"clean\");\n";
        file << "      total+=(dl||0);\n";
        file << "      rows.push('<div class=\"kv\"><span class=\"k\"><a href=\"https://clawhub.ai/'+esc(sk.ownerHandle||\"\")+'/'+esc(slug)+'\" target=\"_blank\">'+esc(sk.displayName||slug)+'</a> · v'+esc(ver)+'</span><span class=\"v\">'+(dl!=null?dl+' DL':'')+' · '+esc(verdict)+'</span></div>');\n";
        file << "      okc++;\n";
        file << "    } catch(e){ rows.push('<div class=\"kv\"><span class=\"k\">'+esc(slug)+'</span><span class=\"v err\">'+esc(e.message)+'</span></div>'); }\n";
        file << "  }\n";
        file << "  setB(\"clawhub\", okc+\"/\"+slugs.length);\n";
        file << "  render(\"clawhub\", rows.join(\"\") + (total?'<div class=\"kv\"><span class=\"k\">Downloads gesamt</span><span class=\"v\">'+total+'</span></div>':''));\n";
        file << "}\n";
        file << "function loadPerplexity(){\n";
        file << "  setB(\"perplexity\",\"i\");\n";
        file << "  render(\"perplexity\",'<span class=\"muted\">Perplexity bietet keinen Verbrauchs-/Credits-Endpunkt. Credits nur im Dashboard sichtbar — daher hier keine Live-Daten.</span>');\n";
        file << "}\n\n";
        file << "function loadAll(){\n";
        file << "  scaffold();\n";
        file << "  const k=getKeys();\n";
        file << "  document.getElementById(\"sub\").textContent = Object.values(k).some(Boolean) ? \"Eigenständige Version · \"+(new Date()).toLocaleString(\"de-DE\") : \"Eigenständige Version · keine Keys hinterlegt — klicke \\\"Keys eingeben\\\".\";\n";
        file << "  loadGitHub(); loadOpenRouter(); loadOpenAI(); loadAnthropic(); loadTailscale(); loadClawHub(); loadPerplexity();\n";
        file << "}\n\n";
        file << "scaffold();\n";
        file << "if(!Object.values(getKeys()).some(Boolean)) openCfg();\n";
        file << "loadAll();\n";
        file << "</script>\n";
        file << "</body>\n";
        file << "</html>\n";
    }
};

int main(int argc, char* argv[]) {
    try {
        std::string filename = "index.html";
        if (argc > 1) {
            filename = argv[1];
        }
        
        HTMLGenerator generator(filename);
        generator.generateHTML();
        
        std::cout << "Generated HTML file: " << filename << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
    
    return 0;
}
