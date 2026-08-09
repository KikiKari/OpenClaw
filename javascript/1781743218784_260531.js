#!/usr/bin/env node
// 1781743218784.tcl — portiert nach javascript
// Quelle: tcl, Projects@abstractions:tcl/1781743218784.tcl
// Erzeugt: 2026-08-08 durch ABSTRACTIONS_MANAGER.py

// 1781743218784.html — portiert nach tcl
// Quelle: html, Projects@secret-vault-public:secret-vault-public/versions/1781743218784.html
// Erzeugt: 2026-08-08 durch ABSTRACTIONS_MANAGER.py

// Node.js script to generate the Secret Vault Public HTML file
// Usage: node this_script.js output_file.html

const fs = require('fs');
const path = require('path');

if (process.argv.length !== 3) {
    console.log("Usage: node " + path.basename(process.argv[1]) + " output_file.html");
    process.exit(1);
}

const outputFile = process.argv[2];
const fd = fs.openSync(outputFile, 'w');

function writeLine(line) {
    fs.writeSync(fd, line + '\n');
}

// Write DOCTYPE and main script tag
writeLine('<!DOCTYPE html>');
writeLine('<script type="application/json" id="cowork-artifact-meta">');
writeLine('{');
writeLine('  "name": "Secret Vault Public",');
writeLine('  "schemaVersion": 1,');
writeLine('  "description": "Secret-Vault Public als interaktives Browser-Artefakt: verschlüsselter Secret-Container vollständig client-seitig (WebCrypto, AES-256-GCM + PBKDF2). Öffnen/Anlegen, Anbieter/Felder ergänzen und ersetzen (Rotation), verschlüsseln und als .svpb herunterladen oder Klartext-JSON exportieren. DE/EN nach Browsersprache. Eigenes Format (nicht kompatibel mit dem scrypt-Python-Tool). Keine Secrets eingebettet.",');
writeLine('  "mcpTools": [],');
writeLine('  "mcpServerNames": []');
writeLine('}');
writeLine('</script>');

// Write HTML start and head section
writeLine('<html lang="de">');
writeLine('<head>');
writeLine('<meta charset="utf-8">');
writeLine('<meta name="viewport" content="width=device-width, initial-scale=1">');
writeLine('<title>Secret-Vault Public</title>');
writeLine('<style>');
writeLine(':root{ color-scheme:light; --ink:#1b1c1f; --muted:#6c6e75; --faint:#9a9ca3; --card:#fff; --line:#e9eaee; --accent:#5b5bd6; --accent2:#7c5cff; --ok:#22a06b; --err:#e0533d; --radius:16px; --shadow:0 1px 2px rgba(20,20,40,.04),0 6px 20px rgba(20,20,40,.06);}');
writeLine('*{box-sizing:border-box;}');
writeLine('body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;color:var(--ink);min-height:100vh;background:radial-gradient(1100px 560px at 100% -10%,#e8ecff 0%,rgba(232,236,255,0) 55%),linear-gradient(180deg,#eef1f6,#f7f7f8 42%);background-attachment:fixed;}');
writeLine('.wrap{max-width:820px;margin:0 auto;padding:24px 18px 70px;}');
writeLine('.brand{display:flex;align-items:center;gap:12px;margin-bottom:4px;}');
writeLine('.mark{width:32px;height:32px;border-radius:9px;background:linear-gradient(135deg,var(--accent),var(--accent2));box-shadow:0 4px 12px rgba(91,91,214,.35);position:relative;flex:0 0 auto;}');
writeLine('.mark:after{content:"";position:absolute;inset:8px;border-radius:4px;border:2px solid rgba(255,255,255,.92);}');
writeLine('h1{font-size:21px;margin:0;font-weight:700;}');
writeLine('.sub{color:var(--muted);font-size:13px;margin:2px 0 16px;}');
writeLine('.card{background:var(--card);border:1px solid var(--line);border-radius:var(--radius);box-shadow:var(--shadow);padding:16px;margin-bottom:14px;}');
writeLine('.card h2{font-size:14px;margin:0 0 10px;}');
writeLine('label.lab{display:block;font-size:12px;font-weight:600;color:var(--muted);margin:8px 0 3px;}');
writeLine('input,textarea{width:100%;font-size:13px;padding:8px 10px;border:1px solid var(--line);border-radius:9px;font-family:ui-monospace,Menlo,Consolas,monospace;background:#fff;}');
writeLine('textarea{min-height:90px;white-space:pre;overflow:auto;}');
writeLine('.row{display:flex;gap:8px;flex-wrap:wrap;align-items:center;}');
writeLine('.btn{font-size:13px;font-weight:600;padding:8px 14px;border:1px solid var(--line);border-radius:10px;background:#fff;cursor:pointer;box-shadow:var(--shadow);transition:transform .1s;}');
writeLine('.btn:hover{transform:translateY(-1px);}');
writeLine('.btn.primary{background:linear-gradient(135deg,var(--accent),var(--accent2));color:#fff;border-color:transparent;}');
writeLine('.btn.sm{padding:5px 9px;font-size:12px;}');
writeLine('.msg{font-size:12px;margin-left:6px;}');
writeLine('.msg.ok{color:var(--ok);} .msg.err{color:var(--err);}');
writeLine('.prov{border:1px solid var(--line);border-radius:12px;padding:10px 12px;margin-bottom:10px;}');
writeLine('.prov h3{margin:0 0 6px;font-size:13.5px;display:flex;align-items:center;gap:8px;}');
writeLine('.kv{display:grid;grid-template-columns:180px 1fr auto;gap:6px;margin:4px 0;align-items:center;}');
writeLine('.kv input{font-size:12px;padding:5px 7px;}');
writeLine('.kv .k{color:var(--muted);font-weight:600;}');
writeLine('.muted{color:var(--faint);font-size:13px;}');
writeLine('.hide{display:none;}');
writeLine('.foot{color:var(--faint);font-size:11.5px;text-align:center;margin-top:18px;line-height:1.5;}');
writeLine('a{color:var(--accent);}');
writeLine('</style>');
writeLine('</head>');

// Write body content
writeLine('<body>');
writeLine('<div class="wrap">');
writeLine('  <div class="brand"><div class="mark"></div><h1 id="title">Secret-Vault Public</h1></div>');
writeLine('  <div class="sub" id="sub">Verschlüsselte Secret-Vault (AES-256-GCM, PBKDF2) — alles im Browser, kein Server.</div>');

// Card: Open or new
writeLine('  <div class="card">');
writeLine('    <h2 id="h-open">Öffnen oder neu</h2>');
writeLine('    <label class="lab" id="l-pass">Passphrase</label>');
writeLine('    <input id="pass" type="password" placeholder="Passphrase…">');
writeLine('    <label class="lab" id="l-file">Vault laden (Datei oder Base64 einfügen)</label>');
writeLine('    <input id="file" type="file" accept=".svpb,.txt,.vault,.b64">');
writeLine('    <textarea id="blob" placeholder="…oder Base64 hier einfügen"></textarea>');
writeLine('    <div class="row" style="margin-top:10px">');
writeLine('      <button class="btn primary" id="openBtn">Öffnen / Entschlüsseln</button>');
writeLine('      <button class="btn" id="newBtn">Neuer leerer Vault</button>');
writeLine('      <span class="msg" id="openMsg"></span>');
writeLine('    </div>');
writeLine('  </div>');

// Card: Editor (hidden by default)
writeLine('  <div class="card hide" id="editor">');
writeLine('    <h2 id="h-edit">Inhalt</h2>');
writeLine('    <div id="provs"></div>');
writeLine('    <div class="row" style="margin-top:8px">');
writeLine('      <input id="newProv" placeholder="Neuer Anbieter (Name)" style="max-width:280px">');
writeLine('      <button class="btn sm" id="addProvBtn">+ Anbieter</button>');
writeLine('    </div>');
writeLine('  </div>');

// Card: Save/Export (hidden by default)
writeLine('  <div class="card hide" id="out">');
writeLine('    <h2 id="h-save">Speichern / Export</h2>');
writeLine('    <div class="row">');
writeLine('      <button class="btn primary" id="encBtn">Verschlüsseln</button>');
writeLine('      <button class="btn" id="dlBtn">Als .svpb herunterladen</button>');
writeLine('      <button class="btn" id="expBtn">Klartext-JSON exportieren</button>');
writeLine('      <span class="msg" id="saveMsg"></span>');
writeLine('    </div>');
writeLine('    <label class="lab" id="l-result">Ergebnis (zum Kopieren/Speichern)</label>');
writeLine('    <textarea id="result" readonly></textarea>');
writeLine('  </div>');

// Footer
writeLine('  <div class="foot" id="foot"></div>');
writeLine('</div>');

// JavaScript section
writeLine('<script>');
writeLine('const L = ((navigator.language||"en").toLowerCase().startsWith("de"))?"de":"en";');
writeLine('const T = {');
writeLine(' title:{de:"Secret-Vault Public",en:"Secret-Vault Public"},');
writeLine(' sub:{de:"Verschlüsselte Secret-Vault (AES-256-GCM, PBKDF2) — alles im Browser, kein Server.",en:"Encrypted secret vault (AES-256-GCM, PBKDF2) — fully in the browser, no server."},');
writeLine(' hOpen:{de:"Öffnen oder neu",en:"Open or new"},');
writeLine(' pass:{de:"Passphrase",en:"Passphrase"},');
writeLine(' file:{de:"Vault laden (Datei oder Base64 einfügen)",en:"Load vault (file or paste Base64)"},');
writeLine(' blob:{de:"…oder Base64 hier einfügen",en:"…or paste Base64 here"},');
writeLine(' open:{de:"Öffnen / Entschlüsseln",en:"Open / Decrypt"},');
writeLine(' neu:{de:"Neuer leerer Vault",en:"New empty vault"},');
writeLine(' hEdit:{de:"Inhalt",en:"Content"},');
writeLine(' newProv:{de:"Neuer Anbieter (Name)",en:"New provider (name)"},');
writeLine(' addProv:{de:"+ Anbieter",en:"+ Provider"},');
writeLine(' hSave:{de:"Speichern / Export",en:"Save / Export"},');
writeLine(' enc:{de:"Verschlüsseln",en:"Encrypt"},');
writeLine(' dl:{de:"Als .svpb herunterladen",en:"Download as .svpb"},');
writeLine(' exp:{de:"Klartext-JSON exportieren",en:"Export plaintext JSON"},');
writeLine(' result:{de:"Ergebnis (zum Kopieren/Speichern)",en:"Result (to copy/save)"},');
writeLine(' foot:{de:"Eigenes Format (PBKDF2). Nicht kompatibel mit dem scrypt-Python-Tool. Sicherheit liegt in der Passphrase; Inhalt ohne sie nicht wiederherstellbar.",en:"Own format (PBKDF2). Not compatible with the scrypt Python tool. Security rests on the passphrase; content is unrecoverable without it."},');
writeLine(' needPass:{de:"Passphrase eingeben.",en:"Enter a passphrase."},');
writeLine(' noInput:{de:"Datei laden oder Base64 einfügen.",en:"Load a file or paste Base64."},');
writeLine(' bad:{de:"Falsche Passphrase oder ungültiger Vault.",en:"Wrong passphrase or invalid vault."},');
writeLine(' opened:{de:"Geöffnet.",en:"Opened."},');
writeLine(' created:{de:"Neuer Vault angelegt.",en:"New vault created."},');
writeLine(' encrypted:{de:"Verschlüsselt — unten kopieren oder herunterladen.",en:"Encrypted — copy below or download."},');
writeLine(' needOpen:{de:"Erst öffnen/anlegen.",en:"Open/create first."},');
writeLine(' field:{de:"Feld",en:"field"}, value:{de:"Wert",en:"value"},');
writeLine(' addField:{de:"+ Feld",en:"+ field"}, del:{de:"✕",en:"✕"},');
writeLine(' newField:{de:"neues Feld",en:"new field"}, newValue:{de:"Wert",en:"value"}');
writeLine('};');
writeLine('const tr=k=>T[k][L];');
writeLine('// apply static i18n');
writeLine('title.textContent=tr("title"); sub.textContent=tr("sub"); document.title=tr("title");');
writeLine('document.getElementById("h-open").textContent=tr("hOpen");');
writeLine('document.getElementById("l-pass").textContent=tr("pass");');
writeLine('document.getElementById("l-file").textContent=tr("file");');
writeLine('blob.placeholder=tr("blob");');
writeLine('openBtn.textContent=tr("open"); newBtn.textContent=tr("neu");');
writeLine('document.getElementById("h-edit").textContent=tr("hEdit");');
writeLine('newProv.placeholder=tr("newProv"); addProvBtn.textContent=tr("addProv");');
writeLine('document.getElementById("h-save").textContent=tr("hSave");');
writeLine('encBtn.textContent=tr("enc"); dlBtn.textContent=tr("dl"); expBtn.textContent=tr("exp");');
writeLine('document.getElementById("l-result").textContent=tr("result");');
writeLine('foot.textContent=tr("foot");');

writeLine('let VAULT=null; // {meta, providers:{}}');

writeLine('const enc=new TextEncoder(), dec=new TextDecoder();');
writeLine('function u8b64(u8){ let s=""; for(let i=0;i<u8.length;i+=0x8000) s+=String.fromCharCode.apply(null,u8.subarray(i,i+0x8000)); return btoa(s); }');
writeLine('function b64u8(b64){ const s=atob(b64.trim()); const u=new Uint8Array(s.length); for(let i=0;i<s.length;i++) u[i]=s.charCodeAt(i); return u; }');
writeLine('async function deriveKey(pw,salt){');
writeLine('  const km=await crypto.subtle.importKey("raw",enc.encode(pw),"PBKDF2",false,["deriveKey"]);');
writeLine('  return crypto.subtle.deriveKey({name:"PBKDF2",salt,iterations:210000,hash:"SHA-256"},km,{name:"AES-GCM",length:256},false,["encrypt","decrypt"]);');
writeLine('}');
writeLine('async function encryptObj(obj,pw){');
writeLine('  const salt=crypto.getRandomValues(new Uint8Array(16)), iv=crypto.getRandomValues(new Uint8Array(12));');
writeLine('  const key=await deriveKey(pw,salt);');
writeLine('  const ct=new Uint8Array(await crypto.subtle.encrypt({name:"AES-GCM",iv},key,enc.encode(JSON.stringify(obj,null,2))));');
writeLine('  const magic=enc.encode("SVPB1"); const out=new Uint8Array(5+16+12+ct.length);');
writeLine('  out.set(magic,0); out.set(salt,5); out.set(iv,21); out.set(ct,33); return u8b64(out);');
writeLine('}');
writeLine('async function decryptB64(b64,pw){');
writeLine('  const raw=b64u8(b64); if(dec.decode(raw.slice(0,5))!=="SVPB1") throw new Error("magic");');
writeLine('  const key=await deriveKey(pw,raw.slice(5,21));');
writeLine('  const pt=await crypto.subtle.decrypt({name:"AES-GCM",iv:raw.slice(21,33)},key,raw.slice(33));');
writeLine('  return JSON.parse(dec.decode(pt));');
writeLine('}');
writeLine('function esc(s){return (s==null?"":String(s)).replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;","\\"":"&quot;"}[c]));}');

writeLine('function renderEditor(){');
writeLine('  document.getElementById("editor").classList.remove("hide");');
writeLine('  document.getElementById("out").classList.remove("hide");');
writeLine('  const P=VAULT.providers||{}; const root=document.getElementById("provs"); root.innerHTML="";');
writeLine('  Object.keys(P).forEach(name=>{');
writeLine('    const d=document.createElement("div"); d.className="prov";');
writeLine('    let rows="";');
writeLine('    Object.keys(P[name]).forEach(k=>{ rows+=`<div class="kv"><span class="k">${esc(k)}</span><input data-p="${esc(name)}" data-k="${esc(k)}" value="${esc(P[name][k])}"><button class="btn sm" data-del="${esc(name)}|${esc(k)}">${tr("del")}</button></div>`; });');
writeLine('    d.innerHTML=`<h3>${esc(name)} <button class="btn sm" data-delp="${esc(name)}">${tr("del")}</button></h3>${rows}');
writeLine('      <div class="row" style="margin-top:6px"><input class="nf" data-np="${esc(name)}" placeholder="${tr("newField")}" style="max-width:180px"><input class="nv" data-np="${esc(name)}" placeholder="${tr("newValue")}" style="max-width:260px"><button class="btn sm" data-addf="${esc(name)}">${tr("addField")}</button></div>`;');
writeLine('    root.appendChild(d);');
writeLine('  });');
writeLine('  root.querySelectorAll("input[data-k]").forEach(i=>i.onchange=()=>{ VAULT.providers[i.dataset.p][i.dataset.k]=i.value; });');
writeLine('  root.querySelectorAll("button[data-del]").forEach(b=>b.onclick=()=>{ const [p,k]=b.dataset.del.split("|"); delete VAULT.providers[p][k]; renderEditor(); });');
writeLine('  root.querySelectorAll("button[data-delp]").forEach(b=>b.onclick=()=>{ delete VAULT.providers[b.dataset.delp]; renderEditor(); });');
writeLine('  root.querySelectorAll("button[data-addf]").forEach(b=>b.onclick=()=>{ const p=b.dataset.addf; const nf=root.querySelector(`.nf[data-np="${CSS.escape(p)}"]`).value.trim(); const nv=root.querySelector(`.nv[data-np="${CSS.escape(p)}"]`).value; if(nf){ VAULT.providers[p][nf]=nv; renderEditor(); } });');
writeLine('}');

writeLine('document.getElementById("file").onchange=e=>{ const f=e.target.files[0]; if(!f)return; const r=new FileReader(); r.onload=()=>{ blob.value=r.result.trim(); }; r.readAsText(f); };');
writeLine('openBtn.onclick=async()=>{');
writeLine('  const m=document.getElementById("openMsg"); m.className="msg"; m.textContent="";');
writeLine('  if(!pass.value){ m.className="msg err"; m.textContent=tr("needPass"); return; }');
writeLine('  if(!blob.value.trim()){ m.className="msg err"; m.textContent=tr("noInput"); return; }');
writeLine('  try{ VAULT=await decryptB64(blob.value,pass.value); if(!VAULT.providers)VAULT.providers={}; renderEditor(); m.className="msg ok"; m.textContent=tr("opened"); }');
writeLine('  catch(err){ m.className="msg err"; m.textContent=tr("bad"); }');
writeLine('};');
writeLine('newBtn.onclick=()=>{');
writeLine('  const m=document.getElementById("openMsg");');
writeLine('  if(!pass.value){ m.className="msg err"; m.textContent=tr("needPass"); return; }');
writeLine('  VAULT={meta:{created:new Date().toISOString().slice(0,10),format:"SVPB1"},providers:{}}; renderEditor();');
writeLine('  m.className="msg ok"; m.textContent=tr("created");');
writeLine('};');
writeLine('addProvBtn.onclick=()=>{ if(!VAULT){ return; } const n=newProv.value.trim(); if(n){ VAULT.providers[n]=VAULT.providers[n]||{}; newProv.value=""; renderEditor(); } };');
writeLine('encBtn.onclick=async()=>{');
writeLine('  const m=document.getElementById("saveMsg"); m.className="msg";');
writeLine('  if(!VAULT){ m.className="msg err"; m.textContent=tr("needOpen"); return; }');
writeLine('  if(!pass.value){ m.className="msg err"; m.textContent=tr("needPass"); return; }');
writeLine('  result.value=await encryptObj(VAULT,pass.value); m.className="msg ok"; m.textContent=tr("encrypted");');
writeLine('};');
writeLine('dlBtn.onclick=()=>{ if(!result.value)return; try{ const b=new Blob([result.value],{type:"text/plain"}); const u=URL.createObjectURL(b); const a=document.createElement("a"); a.href=u; a.download="vault.svpb"; document.body.appendChild(a); a.click(); a.remove(); setTimeout(()=>URL.revokeObjectURL(u),1500);}catch(e){} };');
writeLine('expBtn.onclick=()=>{ if(!VAULT)return; result.value=JSON.stringify(VAULT,null,2); };');
writeLine('</script>');
writeLine('</body>');
writeLine('</html>');

fs.closeSync(fd);

console.log("HTML file generated: " + outputFile);
