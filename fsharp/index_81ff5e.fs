// abstraction-provenance: {"artifact_sha256": "f16fe188a40bc834340ef8f171cf3ac4fb5169a171bbdf67ab03a56ae094daff", "source_sha256": "81ff5e370288082827f95b7b3dc2b94ce16d7710bcedcfd099f0ea81805a7d12", "target_language": "fsharp"}
// index.html — portiert nach fsharp
// Quelle: html, Projects@secret-vault-public:secret-vault-public/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Text
open System.Text.Json

type Meta = {
    name: string
    schemaVersion: int
    description: string
    mcpTools: string array
    mcpServerNames: string array
}

type ArtifactMeta = {
    meta: Meta
}

let createArtifactMeta() =
    {
        meta = {
            name = "Secret Vault Public"
            schemaVersion = 1
            description = "Secret-Vault Public als interaktives Browser-Artefakt: verschlüsselter Secret-Container vollständig client-seitig (WebCrypto, AES-256-GCM + PBKDF2). Öffnen/Anlegen, Anbieter/Felder ergänzen und ersetzen (Rotation), verschlüsseln und als .svpb herunterladen oder Klartext-JSON exportieren. DE/EN nach Browsersprache. Eigenes Format (nicht kompatibel mit dem scrypt-Python-Tool). Keine Secrets eingebettet."
            mcpTools = [||]
            mcpServerNames = [||]
        }
    }

let cssContent = """
:root{ color-scheme:light; --ink:#1b1c1f; --muted:#6c6e75; --faint:#9a9ca3; --card:#fff; --line:#e9eaee; --accent:#5b5bd6; --accent2:#7c5cff; --ok:#22a06b; --err:#e0533d; --radius:16px; --shadow:0 1px 2px rgba(20,20,40,.04),0 6px 20px rgba(20,20,40,.06);}
*{box-sizing:border-box;}
body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;color:var(--ink);min-height:100vh;background:radial-gradient(1100px 560px at 100% -10%,#e8ecff 0%,rgba(232,236,255,0) 55%),linear-gradient(180deg,#eef1f6,#f7f7f8 42%);background-attachment:fixed;}
.wrap{max-width:820px;margin:0 auto;padding:24px 18px 70px;}
.brand{display:flex;align-items:center;gap:12px;margin-bottom:4px;}
.mark{width:32px;height:32px;border-radius:9px;background:linear-gradient(135deg,var(--accent),var(--accent2));box-shadow:0 4px 12px rgba(91,91,214,.35);position:relative;flex:0 0 auto;}
.mark:after{content:"";position:absolute;inset:8px;border-radius:4px;border:2px solid rgba(255,255,255,.92);}
h1{font-size:21px;margin:0;font-weight:700;}
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
"""

let generateHtmlContent() =
    let sb = StringBuilder()
    
    // DOCTYPE
    sb.AppendLine "<!DOCTYPE html>" |> ignore
    
    // Script tag for artifact meta
    let artifactMeta = createArtifactMeta()
    let metaJson = JsonSerializer.Serialize(artifactMeta.meta, JsonSerializerOptions(WriteIndented = true))
    sb.AppendLine $"<script type=\"application/json\" id=\"cowork-artifact-meta\">"
    sb.AppendLine metaJson
    sb.AppendLine "</script>" |> ignore
    
    // HTML start
    sb.AppendLine "<html lang=\"de\">" |> ignore
    sb.AppendLine "<head>" |> ignore
    sb.AppendLine "<meta charset=\"utf-8\">" |> ignore
    sb.AppendLine "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">" |> ignore
    sb.AppendLine "<title>Vault Cache</title>" |> ignore
    sb.AppendLine "<style>" |> ignore
    sb.AppendLine cssContent.Trim() |> ignore
    sb.AppendLine "</style>" |> ignore
    sb.AppendLine "</head>" |> ignore
    sb.AppendLine "<body>" |> ignore
    
    // Main content
    sb.AppendLine "<div class=\"wrap\">" |> ignore
    sb.AppendLine "  <div class=\"brand\"><div class=\"mark\"></div><h1 id=\"title\">Vault Cache</h1></div>" |> ignore
    sb.AppendLine "  <div class=\"sub\" id=\"sub\">Verschlüsselte Secret-Vault (AES-256-GCM, PBKDF2) — alles im Browser, kein Server.</div>" |> ignore
    
    sb.AppendLine "" |> ignore
    sb.AppendLine "  <div class=\"card\">" |> ignore
    sb.AppendLine "    <h2 id=\"h-open\">Öffnen oder neu</h2>" |> ignore
    sb.AppendLine "    <label class=\"lab\" id=\"l-pass\">Passphrase</label>" |> ignore
    sb.AppendLine "    <input id=\"pass\" type=\"password\" placeholder=\"Passphrase…\">" |> ignore
    sb.AppendLine "    <label class=\"lab\" id=\"l-file\">Vault laden (Datei oder Base64 einfügen)</label>" |> ignore
    sb.AppendLine "    <input id=\"file\" type=\"file\" accept=\".svpb,.txt,.vault,.b64\">" |> ignore
    sb.AppendLine "    <textarea id=\"blob\" placeholder=\"…oder Base64 hier einfügen\"></textarea>" |> ignore
    sb.AppendLine "    <div class=\"row\" style=\"margin-top:10px\">" |> ignore
    sb.AppendLine "      <button class=\"btn primary\" id=\"openBtn\">Öffnen / Entschlüsseln</button>" |> ignore
    sb.AppendLine "      <button class=\"btn\" id=\"newBtn\">Neuer leerer Vault</button>" |> ignore
    sb.AppendLine "      <span class=\"msg\" id=\"openMsg\"></span>" |> ignore
    sb.AppendLine "    </div>" |> ignore
    sb.AppendLine "  </div>" |> ignore
    
    sb.AppendLine "" |> ignore
    sb.AppendLine "  <div class=\"card hide\" id=\"editor\">" |> ignore
    sb.AppendLine "    <h2 id=\"h-edit\">Inhalt</h2>" |> ignore
    sb.AppendLine "    <div id=\"provs\"></div>" |> ignore
    sb.AppendLine "    <div class=\"row\" style=\"margin-top:8px\">" |> ignore
    sb.AppendLine "      <input id=\"newProv\" placeholder=\"Neuer Anbieter (Name)\" style=\"max-width:280px\">" |> ignore
    sb.AppendLine "      <button class=\"btn sm\" id=\"addProvBtn\">+ Anbieter</button>" |> ignore
    sb.AppendLine "    </div>" |> ignore
    sb.AppendLine "  </div>" |> ignore
    
    sb.AppendLine "" |> ignore
    sb.AppendLine "  <div class=\"card hide\" id=\"out\">" |> ignore
    sb.AppendLine "    <h2 id=\"h-save\">Speichern / Export</h2>" |> ignore
    sb.AppendLine "    <div class=\"row\">" |> ignore
    sb.AppendLine "      <button class=\"btn primary\" id=\"encBtn\">Verschlüsseln</button>" |> ignore
    sb.AppendLine "      <button class=\"btn\" id=\"dlBtn\">Als .svpb herunterladen</button>" |> ignore
    sb.AppendLine "      <button class=\"btn\" id=\"expBtn\">Klartext-JSON exportieren</button>" |> ignore
    sb.AppendLine "      <span class=\"msg\" id=\"saveMsg\"></span>" |> ignore
    sb.AppendLine "    </div>" |> ignore
    sb.AppendLine "    <label class=\"lab\" id=\"l-result\">Ergebnis (zum Kopieren/Speichern)</label>" |> ignore
    sb.AppendLine "    <textarea id=\"result\" readonly></textarea>" |> ignore
    sb.AppendLine "  </div>" |> ignore
    
    sb.AppendLine "" |> ignore
    sb.AppendLine "  <div class=\"foot\" id=\"foot\"></div>" |> ignore
    sb.AppendLine "</div>" |> ignore
    
    // JavaScript section
    sb.AppendLine "" |> ignore
    sb.AppendLine "<script>" |> ignore
    sb.AppendLine "const L = ((navigator.language||\"en\").toLowerCase().startsWith(\"de\"))?\"de\":\"en\";" |> ignore
    sb.AppendLine "const T = {" |> ignore
    sb.AppendLine " title:{de:\"Vault Cache\",en:\"Vault Cache\"}," |> ignore
    sb.AppendLine " sub:{de:\"Verschlüsselte Secret-Vault (AES-256-GCM, PBKDF2) — alles im Browser, kein Server.\",en:\"Encrypted secret vault (AES-256-GCM, PBKDF2) — fully in the browser, no server.\"}," |> ignore
    sb.AppendLine " hOpen:{de:\"Öffnen oder neu\",en:\"Open or new\"}," |> ignore
    sb.AppendLine " pass:{de:\"Passphrase\",en:\"Passphrase\"}," |> ignore
    sb.AppendLine " file:{de:\"Vault laden (Datei oder Base64 einfügen)\",en:\"Load vault (file or paste Base64)\"}," |> ignore
    sb.AppendLine " blob:{de:\"…oder Base64 hier einfügen\",en:\"…or paste Base64 here\"}," |> ignore
    sb.AppendLine " open:{de:\"Öffnen / Entschlüsseln\",en:\"Open / Decrypt\"}," |> ignore
    sb.AppendLine " neu:{de:\"Neuer leerer Vault\",en:\"New empty vault\"}," |> ignore
    sb.AppendLine " hEdit:{de:\"Inhalt\",en:\"Content\"}," |> ignore
    sb.AppendLine " newProv:{de:\"Neuer Anbieter (Name)\",en:\"New provider (name)\"}," |> ignore
    sb.AppendLine " addProv:{de:\"+ Anbieter\",en:\"+ Provider\"}," |> ignore
    sb.AppendLine " hSave:{de:\"Speichern / Export\",en:\"Save / Export\"}," |> ignore
    sb.AppendLine " enc:{de:\"Verschlüsseln\",en:\"Encrypt\"}," |> ignore
    sb.AppendLine " dl:{de:\"Als .svpb herunterladen\",en:\"Download as .svpb\"}," |> ignore
    sb.AppendLine " exp:{de:\"Klartext-JSON exportieren\",en:\"Export plaintext JSON\"}," |> ignore
    sb.AppendLine " result:{de:\"Ergebnis (zum Kopieren/Speichern)\",en:\"Result (to copy/save)\"}," |> ignore
    sb.AppendLine " foot:{de:\"Eigenes Format (PBKDF2). Nicht kompatibel mit dem scrypt-Python-Tool. Sicherheit liegt in der Passphrase; Inhalt ohne sie nicht wiederherstellbar.\",en:\"Own format (PBKDF2). Not compatible with the scrypt Python tool. Security rests on the passphrase; content is unrecoverable without it.\"}," |> ignore
    sb.AppendLine " needPass:{de:\"Passphrase eingeben.\",en:\"Enter a passphrase.\"}," |> ignore
    sb.AppendLine " noInput:{de:\"Datei laden oder Base64 einfügen.\",en:\"Load a file or paste Base64.\"}," |> ignore
    sb.AppendLine " bad:{de:\"Falsche Passphrase oder ungültiger Vault.\",en:\"Wrong passphrase or invalid vault.\"}," |> ignore
    sb.AppendLine " opened:{de:\"Geöffnet.\",en:\"Opened.\"}," |> ignore
    sb.AppendLine " created:{de:\"Neuer Vault angelegt.\",en:\"New vault created.\"}," |> ignore
    sb.AppendLine " encrypted:{de:\"Verschlüsselt — unten kopieren oder herunterladen.\",en:\"Encrypted — copy below or download.\"}," |> ignore
    sb.AppendLine " needOpen:{de:\"Erst öffnen/anlegen.\",en:\"Open/create first.\"}," |> ignore
    sb.AppendLine " field:{de:\"Feld\",en:\"field\"}, value:{de:\"Wert\",en:\"value\"}," |> ignore
    sb.AppendLine " addField:{de:\"+ Feld\",en:\"+ field\"}, del:{de:\"✕\",en:\"✕\"}," |> ignore
    sb.AppendLine " newField:{de:\"neues Feld\",en:\"new field\"}, newValue:{de:\"Wert\",en:\"value\"}" |> ignore
    sb.AppendLine "};" |> ignore
    sb.AppendLine "const tr=k=>T[k][L];" |> ignore
    
    // Static i18n
    sb.AppendLine "// apply static i18n" |> ignore
    sb.AppendLine "title.textContent=tr(\"title\"); sub.textContent=tr(\"sub\"); document.title=tr(\"title\");" |> ignore
    sb.AppendLine "document.getElementById(\"h-open\").textContent=tr(\"hOpen\");" |> ignore
    sb.AppendLine "document.getElementById(\"l-pass\").textContent=tr(\"pass\");" |> ignore
    sb.AppendLine "document.getElementById(\"l-file\").textContent=tr(\"file\");" |> ignore
    sb.AppendLine "blob.placeholder=tr(\"blob\");" |> ignore
    sb.AppendLine "openBtn.textContent=tr(\"open\"); newBtn.textContent=tr(\"neu\");" |> ignore
    sb.AppendLine "document.getElementById(\"h-edit\").textContent=tr(\"hEdit\");" |> ignore
    sb.AppendLine "newProv.placeholder=tr(\"newProv\"); addProvBtn.textContent=tr(\"addProv\");" |> ignore
    sb.AppendLine "document.getElementById(\"h-save\").textContent=tr(\"hSave\");" |> ignore
    sb.AppendLine "encBtn.textContent=tr(\"enc\"); dlBtn.textContent=tr(\"dl\"); expBtn.textContent=tr(\"exp\");" |> ignore
    sb.AppendLine "document.getElementById(\"l-result\").textContent=tr(\"result\");" |> ignore
    sb.AppendLine "foot.textContent=tr(\"foot\");" |> ignore
    
    sb.AppendLine "" |> ignore
    sb.AppendLine "let VAULT=null; // {meta, providers:{}}" |> ignore
    sb.AppendLine "" |> ignore
    sb.AppendLine "const enc=new TextEncoder(), dec=new TextDecoder();" |> ignore
    sb.AppendLine "function u8b64(u8){ let s=\"\"; for(let i=0;i<u8.length;i+=0x8000) s+=String.fromCharCode.apply(null,u8.subarray(i,i+0x8000)); return btoa(s); }" |> ignore
    sb.AppendLine "function b64u8(b64){ const s=atob(b64.trim()); const u=new Uint8Array(s.length); for(let i=0;i<s.length;i++) u[i]=s.charCodeAt(i); return u; }" |> ignore
    sb.AppendLine "async function deriveKey(pw,salt){" |> ignore
    sb.AppendLine "  const km=await crypto.subtle.importKey(\"raw\",enc.encode(pw),\"PBKDF2\",false,[\"deriveKey\"]);" |> ignore
    sb.AppendLine "  return crypto.subtle.deriveKey({name:\"PBKDF2\",salt,iterations:210000,hash:\"SHA-256\"},km,{name:\"AES-GCM\",length:256},false,[\"encrypt\",\"decrypt\"]);" |> ignore
    sb.AppendLine "}" |> ignore
    sb.AppendLine "async function encryptObj(obj,pw){" |> ignore
    sb.AppendLine "  const salt=crypto.getRandomValues(new Uint8Array(16)), iv=crypto.getRandomValues(new Uint8Array(12));" |> ignore
    sb.AppendLine "  const key=await deriveKey(pw,salt);" |> ignore
    sb.AppendLine "  const ct=new Uint8Array(await crypto.subtle.encrypt({name:\"AES-GCM\",iv},key,enc.encode(JSON.stringify(obj,null,2))));" |> ignore
    sb.AppendLine "  const magic=enc.encode(\"SVPB1\"); const out=new Uint8Array(5+16+12+ct.length);" |> ignore
    sb.AppendLine "  out.set(magic,0); out.set(salt,5); out.set(iv,21); out.set(ct,33); return u8b64(out);" |> ignore
    sb.AppendLine "}" |> ignore
    sb.AppendLine "async function decryptB64(b64,pw){" |> ignore
    sb.AppendLine "  const raw=b64u8(b64); if(dec.decode(raw.slice(0,5))!==\"SVPB1\") throw new Error(\"magic\");" |> ignore
    sb.AppendLine "  const key=await deriveKey(pw,raw.slice(5,21));" |> ignore
    sb.AppendLine "  const pt=await crypto.subtle.decrypt({name:\"AES-GCM\",iv:raw.slice(21,33)},key,raw.slice(33));" |> ignore
    sb.AppendLine "  return JSON.parse(dec.decode(pt));" |> ignore
    sb.AppendLine "}" |> ignore
    sb.AppendLine "function esc(s){return (s==null?\"\":String(s)).replace(/[&<>\\\"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\\\"':'&quot;'}[c]));}" |> ignore
    sb.AppendLine "" |> ignore
    sb.AppendLine "function renderEditor(){" |> ignore
    sb.AppendLine "  document.getElementById(\"editor\").classList.remove(\"hide\");" |> ignore
    sb.AppendLine "  document.getElementById(\"out\").classList.remove(\"hide\");" |> ignore
    sb.AppendLine "  const P=VAULT.providers||{}; const root=document.getElementById(\"provs\"); root.innerHTML=\"\";" |> ignore
    sb.AppendLine "  Object.keys(P).forEach(name=>{" |> ignore
    sb.AppendLine "    const d=document.createElement(\"div\"); d.className=\"prov\";" |> ignore
    sb.AppendLine "    let rows=\"\";" |> ignore
    sb.AppendLine "    Object.keys(P[name]).forEach(k=>{ rows+=`<div class=\"kv\"><span class=\"k\">${esc(k)}</span><input data-p=\"${esc(name)}\" data-k=\"${esc(k)}\" value=\"${esc(P[name][k])}\"><button class=\"btn sm\" data-del=\"${esc(name)}|${esc(k)}\">${tr(\"del\")}</button></div>`; });" |> ignore
    sb.AppendLine "    d.innerHTML=`<h3>${esc(name)} <button class=\"btn sm\" data-delp=\"${esc(name)}\">${tr(\"del\")}</button></h3>${rows}" |> ignore
    sb.AppendLine "      <div class=\"row\" style=\"margin-top:6px\"><input class=\"nf\" data-np=\"${esc(name)}\" placeholder=\"${tr(\"newField\")}\" style=\"max-width:180px\"><input class=\"nv\" data-np=\"${esc(name)}\" placeholder=\"${tr(\"newValue\")}\" style=\"max-width:260px\"><button class=\"btn sm\" data-addf=\"${esc(name)}\">${tr(\"addField\")}</button></div>`;" |> ignore
    sb.AppendLine "    root.appendChild(d);" |> ignore
    sb.AppendLine "  });" |> ignore
    sb.AppendLine "  root.querySelectorAll(\"input[data-k]\").forEach(i=>i.onchange=()=>{ VAULT.providers[i.dataset.p][i.dataset.k]=i.value; });" |> ignore
    sb.AppendLine "  root.querySelectorAll(\"button[data-del]\").forEach(b=>b.onclick=()=>{ const [p,k]=b.dataset.del.split(\"|\"); delete VAULT.providers[p][k]; renderEditor(); });" |> ignore
    sb.AppendLine "  root.querySelectorAll(\"button[data-delp]\").forEach(b=>b.onclick=()=>{ delete VAULT.providers[b.dataset.delp]; renderEditor(); });" |> ignore
    sb.AppendLine "  root.querySelectorAll(\"button[data-addf]\").forEach(b=>b.onclick=()=>{ const p=b.dataset.addf; const nf=root.querySelector(`.nf[data-np=\"${CSS.escape(p)}\"]`).value.trim(); const nv=root.querySelector(`.nv[data-np=\"${CSS.escape(p)}\"]`).value; if(nf){ VAULT.providers[p][nf]=nv; renderEditor(); } });" |> ignore
    sb.AppendLine "}" |> ignore
    sb.AppendLine "" |> ignore
    sb.AppendLine "document.getElementById(\"file\").onchange=e=>{ const f=e.target.files[0]; if(!f)return; const r=new FileReader(); r.onload=()=>{ blob.value=r.result.trim(); }; r.readAsText(f); };" |> ignore
    sb.AppendLine "openBtn.onclick=async()=>{" |> ignore
    sb.AppendLine "  const m=document.getElementById(\"openMsg\"); m.className=\"msg\"; m.textContent=\"\";" |> ignore
    sb.AppendLine "  if(!pass.value){ m.className=\"msg err\"; m.textContent=tr(\"needPass\"); return; }" |> ignore
    sb.AppendLine "  if(!blob.value.trim()){ m.className=\"msg err\"; m.textContent=tr(\"noInput\"); return; }" |> ignore
    sb.AppendLine "  try{ VAULT=await decryptB64(blob.value,pass.value); if(!VAULT.providers)VAULT.providers={}; renderEditor(); m.className=\"msg ok\"; m.textContent=tr(\"opened\"); }" |> ignore
    sb.AppendLine "  catch(err){ m.className=\"msg err\"; m.textContent=tr(\"bad\"); }" |> ignore
    sb.AppendLine "};" |> ignore
    sb.AppendLine "newBtn.onclick=()=>{" |> ignore
    sb.AppendLine "  const m=document.getElementById(\"openMsg\");" |> ignore
    sb.AppendLine "  if(!pass.value){ m.className=\"msg err\"; m.textContent=tr(\"needPass\"); return; }" |> ignore
    sb.AppendLine "  VAULT={meta:{created:new Date().toISOString().slice(0,10),format:\"SVPB1\"},providers:{}}; renderEditor();" |> ignore
    sb.AppendLine "  m.className=\"msg ok\"; m.textContent=tr(\"created\");" |> ignore
    sb.AppendLine "};" |> ignore
    sb.AppendLine "addProvBtn.onclick=()=>{ if(!VAULT){ return; } const n=newProv.value.trim(); if(n){ VAULT.providers[n]=VAULT.providers[n]||{}; newProv.value=\"\"; renderEditor(); } };" |> ignore
    sb.AppendLine "encBtn.onclick=async()=>{" |> ignore
    sb.AppendLine "  const m=document.getElementById(\"saveMsg\"); m.className=\"msg\";" |> ignore
    sb.AppendLine "  if(!VAULT){ m.className=\"msg err\"; m.textContent=tr(\"needOpen\"); return; }" |> ignore
    sb.AppendLine "  if(!pass.value){ m.className=\"msg err\"; m.textContent=tr(\"needPass\"); return; }" |> ignore
    sb.AppendLine "  result.value=await encryptObj(VAULT,pass.value); m.className=\"msg ok\"; m.textContent=tr(\"encrypted\");" |> ignore
    sb.AppendLine "};" |> ignore
    sb.AppendLine "dlBtn.onclick=()=>{ if(!result.value)return; try{ const b=new Blob([result.value],{type:\"text/plain\"}); const u=URL.createObjectURL(b); const a=document.createElement(\"a\"); a.href=u; a.download=\"vault.svpb\"; document.body.appendChild(a); a.click(); a.remove(); setTimeout(()=>URL.revokeObjectURL(u),1500);}catch(e){} };" |> ignore
    sb.AppendLine "expBtn.onclick=()=>{ if(!VAULT)return; result.value=JSON.stringify(VAULT,null,2); };" |> ignore
    sb.AppendLine "</script>" |> ignore
    
    // Close body and html
    sb.AppendLine "</body>" |> ignore
    sb.AppendLine "</html>" |> ignore
    
    sb.ToString()

[<EntryPoint>]
let main argv =
    let outputPath = 
        if argv.Length > 0 then argv.[0]
        else "index.html"
    
    try
        let htmlContent = generateHtmlContent()
        File.WriteAllText(outputPath, htmlContent, Encoding.UTF8)
        printfn "HTML file generated successfully at: %s" outputPath
        0
    with
    | ex ->
        eprintfn "Error generating HTML file: %s" ex.Message
        1
