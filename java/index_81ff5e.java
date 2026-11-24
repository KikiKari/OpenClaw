// abstraction-provenance: {"artifact_sha256": "dd88eac87652c1716edb24012ec7154c61adb22f6331e943fb5dea8e647a0273", "source_sha256": "81ff5e370288082827f95b7b3dc2b94ce16d7710bcedcfd099f0ea81805a7d12", "target_language": "java"}
// index.html — portiert nach java
// Quelle: html, Projects@secret-vault-public:secret-vault-public/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.util.*;

public class IndexGenerator {

    public static void main(String[] args) {
        if (args.length != 1) {
            System.err.println("Usage: java IndexGenerator <output-file>");
            System.exit(1);
        }

        String outputFile = args[0];
        
        try {
            String htmlContent = generateHTML();
            Files.write(Paths.get(outputFile), htmlContent.getBytes("UTF-8"));
            System.out.println("Generated " + outputFile);
        } catch (IOException e) {
            System.err.println("Error writing file: " + e.getMessage());
            System.exit(1);
        }
    }

    private static String generateHTML() {
        StringBuilder html = new StringBuilder();
        
        // DOCTYPE
        html.append("<!DOCTYPE html>\n");
        
        // Meta script tag
        html.append("<script type=\"application/json\" id=\"cowork-artifact-meta\">\n");
        html.append("{\n");
        html.append("  \"name\": \"Secret Vault Public\",\n");
        html.append("  \"schemaVersion\": 1,\n");
        html.append("  \"description\": \"Secret-Vault Public als interaktives Browser-Artefakt: verschlüsselter Secret-Container vollständig client-seitig (WebCrypto, AES-256-GCM + PBKDF2). Öffnen/Anlegen, Anbieter/Felder ergänzen und ersetzen (Rotation), verschlüsseln und als .svpb herunterladen oder Klartext-JSON exportieren. DE/EN nach Browsersprache. Eigenes Format (nicht kompatibel mit dem scrypt-Python-Tool). Keine Secrets eingebettet.\",\n");
        html.append("  \"mcpTools\": [],\n");
        html.append("  \"mcpServerNames\": []\n");
        html.append("}\n");
        html.append("</script>\n");
        
        // HTML start
        html.append("<html lang=\"de\">\n<head>\n");
        html.append("<meta charset=\"utf-8\">\n");
        html.append("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n");
        html.append("<title>Vault Cache</title>\n");
        
        // Styles
        html.append("<style>\n");
        html.append(":root{ color-scheme:light; --ink:#1b1c1f; --muted:#6c6e75; --faint:#9a9ca3; --card:#fff; --line:#e9eaee; --accent:#5b5bd6; --accent2:#7c5cff; --ok:#22a06b; --err:#e0533d; --radius:16px; --shadow:0 1px 2px rgba(20,20,40,.04),0 6px 20px rgba(20,20,40,.06);}\n");
        html.append("*{box-sizing:border-box;}\n");
        html.append("body{margin:0;font-family:-apple-system,BlinkMacSystemFont,\"Segoe UI\",Roboto,Helvetica,Arial,sans-serif;color:var(--ink);min-height:100vh;background:radial-gradient(1100px 560px at 100% -10%,#e8ecff 0%,rgba(232,236,255,0) 55%),linear-gradient(180deg,#eef1f6,#f7f7f8 42%);background-attachment:fixed;}\n");
        html.append(".wrap{max-width:820px;margin:0 auto;padding:24px 18px 70px;}\n");
        html.append(".brand{display:flex;align-items:center;gap:12px;margin-bottom:4px;}\n");
        html.append(".mark{width:32px;height:32px;border-radius:9px;background:linear-gradient(135deg,var(--accent),var(--accent2));box-shadow:0 4px 12px rgba(91,91,214,.35);position:relative;flex:0 0 auto;}\n");
        html.append(".mark:after{content:\"\";position:absolute;inset:8px;border-radius:4px;border:2px solid rgba(255,255,255,.92);}\n");
        html.append("h1{font-size:21px;margin:0;font-weight:700;}\n");
        html.append(".sub{color:var(--muted);font-size:13px;margin:2px 0 16px;}\n");
        html.append(".card{background:var(--card);border:1px solid var(--line);border-radius:var(--radius);box-shadow:var(--shadow);padding:16px;margin-bottom:14px;}\n");
        html.append(".card h2{font-size:14px;margin:0 0 10px;}\n");
        html.append("label.lab{display:block;font-size:12px;font-weight:600;color:var(--muted);margin:8px 0 3px;}\n");
        html.append("input,textarea{width:100%;font-size:13px;padding:8px 10px;border:1px solid var(--line);border-radius:9px;font-family:ui-monospace,Menlo,Consolas,monospace;background:#fff;}\n");
        html.append("textarea{min-height:90px;white-space:pre;overflow:auto;}\n");
        html.append(".row{display:flex;gap:8px;flex-wrap:wrap;align-items:center;}\n");
        html.append(".btn{font-size:13px;font-weight:600;padding:8px 14px;border:1px solid var(--line);border-radius:10px;background:#fff;cursor:pointer;box-shadow:var(--shadow);transition:transform .1s;}\n");
        html.append(".btn:hover{transform:translateY(-1px);}\n");
        html.append(".btn.primary{background:linear-gradient(135deg,var(--accent),var(--accent2));color:#fff;border-color:transparent;}\n");
        html.append(".btn.sm{padding:5px 9px;font-size:12px;}\n");
        html.append(".msg{font-size:12px;margin-left:6px;}\n");
        html.append(".msg.ok{color:var(--ok);} .msg.err{color:var(--err);}\n");
        html.append(".prov{border:1px solid var(--line);border-radius:12px;padding:10px 12px;margin-bottom:10px;}\n");
        html.append(".prov h3{margin:0 0 6px;font-size:13.5px;display:flex;align-items:center;gap:8px;}\n");
        html.append(".kv{display:grid;grid-template-columns:180px 1fr auto;gap:6px;margin:4px 0;align-items:center;}\n");
        html.append(".kv input{font-size:12px;padding:5px 7px;}\n");
        html.append(".kv .k{color:var(--muted);font-weight:600;}\n");
        html.append(".muted{color:var(--faint);font-size:13px;}\n");
        html.append(".hide{display:none;}\n");
        html.append(".foot{color:var(--faint);font-size:11.5px;text-align:center;margin-top:18px;line-height:1.5;}\n");
        html.append("a{color:var(--accent);}\n");
        html.append("</style>\n");
        html.append("</head>\n<body>\n");
        
        // Body content
        html.append("<div class=\"wrap\">\n");
        html.append("  <div class=\"brand\"><div class=\"mark\"></div><h1 id=\"title\">Vault Cache</h1></div>\n");
        html.append("  <div class=\"sub\" id=\"sub\">Verschlüsselte Secret-Vault (AES-256-GCM, PBKDF2) — alles im Browser, kein Server.</div>\n\n");
        
        // Open/New card
        html.append("  <div class=\"card\">\n");
        html.append("    <h2 id=\"h-open\">Öffnen oder neu</h2>\n");
        html.append("    <label class=\"lab\" id=\"l-pass\">Passphrase</label>\n");
        html.append("    <input id=\"pass\" type=\"password\" placeholder=\"Passphrase…\">\n");
        html.append("    <label class=\"lab\" id=\"l-file\">Vault laden (Datei oder Base64 einfügen)</label>\n");
        html.append("    <input id=\"file\" type=\"file\" accept=\".svpb,.txt,.vault,.b64\">\n");
        html.append("    <textarea id=\"blob\" placeholder=\"…oder Base64 hier einfügen\"></textarea>\n");
        html.append("    <div class=\"row\" style=\"margin-top:10px\">\n");
        html.append("      <button class=\"btn primary\" id=\"openBtn\">Öffnen / Entschlüsseln</button>\n");
        html.append("      <button class=\"btn\" id=\"newBtn\">Neuer leerer Vault</button>\n");
        html.append("      <span class=\"msg\" id=\"openMsg\"></span>\n");
        html.append("    </div>\n");
        html.append("  </div>\n\n");
        
        // Editor card
        html.append("  <div class=\"card hide\" id=\"editor\">\n");
        html.append("    <h2 id=\"h-edit\">Inhalt</h2>\n");
        html.append("    <div id=\"provs\"></div>\n");
        html.append("    <div class=\"row\" style=\"margin-top:8px\">\n");
        html.append("      <input id=\"newProv\" placeholder=\"Neuer Anbieter (Name)\" style=\"max-width:280px\">\n");
        html.append("      <button class=\"btn sm\" id=\"addProvBtn\">+ Anbieter</button>\n");
        html.append("    </div>\n");
        html.append("  </div>\n\n");
        
        // Save/Export card
        html.append("  <div class=\"card hide\" id=\"out\">\n");
        html.append("    <h2 id=\"h-save\">Speichern / Export</h2>\n");
        html.append("    <div class=\"row\">\n");
        html.append("      <button class=\"btn primary\" id=\"encBtn\">Verschlüsseln</button>\n");
        html.append("      <button class=\"btn\" id=\"dlBtn\">Als .svpb herunterladen</button>\n");
        html.append("      <button class=\"btn\" id=\"expBtn\">Klartext-JSON exportieren</button>\n");
        html.append("      <span class=\"msg\" id=\"saveMsg\"></span>\n");
        html.append("    </div>\n");
        html.append("    <label class=\"lab\" id=\"l-result\">Ergebnis (zum Kopieren/Speichern)</label>\n");
        html.append("    <textarea id=\"result\" readonly></textarea>\n");
        html.append("  </div>\n\n");
        
        // Footer
        html.append("  <div class=\"foot\" id=\"foot\"></div>\n");
        html.append("</div>\n\n");
        
        // Script
        html.append("<script>\n");
        html.append("const L = ((navigator.language||\"en\").toLowerCase().startsWith(\"de\"))?\"de\":\"en\";\n");
        html.append("const T = {\n");
        html.append(" title:{de:\"Vault Cache\",en:\"Vault Cache\"},\n");
        html.append(" sub:{de:\"Verschlüsselte Secret-Vault (AES-256-GCM, PBKDF2) — alles im Browser, kein Server.\",en:\"Encrypted secret vault (AES-256-GCM, PBKDF2) — fully in the browser, no server.\"},\n");
        html.append(" hOpen:{de:\"Öffnen oder neu\",en:\"Open or new\"},\n");
        html.append(" pass:{de:\"Passphrase\",en:\"Passphrase\"},\n");
        html.append(" file:{de:\"Vault laden (Datei oder Base64 einfügen)\",en:\"Load vault (file or paste Base64)\"},\n");
        html.append(" blob:{de:\"…oder Base64 hier einfügen\",en:\"…or paste Base64 here\"},\n");
        html.append(" open:{de:\"Öffnen / Entschlüsseln\",en:\"Open / Decrypt\"},\n");
        html.append(" neu:{de:\"Neuer leerer Vault\",en:\"New empty vault\"},\n");
        html.append(" hEdit:{de:\"Inhalt\",en:\"Content\"},\n");
        html.append(" newProv:{de:\"Neuer Anbieter (Name)\",en:\"New provider (name)\"},\n");
        html.append(" addProv:{de:\"+ Anbieter\",en:\"+ Provider\"},\n");
        html.append(" hSave:{de:\"Speichern / Export\",en:\"Save / Export\"},\n");
        html.append(" enc:{de:\"Verschlüsseln\",en:\"Encrypt\"},\n");
        html.append(" dl:{de:\"Als .svpb herunterladen\",en:\"Download as .svpb\"},\n");
        html.append(" exp:{de:\"Klartext-JSON exportieren\",en:\"Export plaintext JSON\"},\n");
        html.append(" result:{de:\"Ergebnis (zum Kopieren/Speichern)\",en:\"Result (to copy/save)\"},\n");
        html.append(" foot:{de:\"Eigenes Format (PBKDF2). Nicht kompatibel mit dem scrypt-Python-Tool. Sicherheit liegt in der Passphrase; Inhalt ohne sie nicht wiederherstellbar.\",en:\"Own format (PBKDF2). Not compatible with the scrypt Python tool. Security rests on the passphrase; content is unrecoverable without it.\"},\n");
        html.append(" needPass:{de:\"Passphrase eingeben.\",en:\"Enter a passphrase.\"},\n");
        html.append(" noInput:{de:\"Datei laden oder Base64 einfügen.\",en:\"Load a file or paste Base64.\"},\n");
        html.append(" bad:{de:\"Falsche Passphrase oder ungültiger Vault.\",en:\"Wrong passphrase or invalid vault.\"},\n");
        html.append(" opened:{de:\"Geöffnet.\",en:\"Opened.\"},\n");
        html.append(" created:{de:\"Neuer Vault angelegt.\",en:\"New vault created.\"},\n");
        html.append(" encrypted:{de:\"Verschlüsselt — unten kopieren oder herunterladen.\",en:\"Encrypted — copy below or download.\"},\n");
        html.append(" needOpen:{de:\"Erst öffnen/anlegen.\",en:\"Open/create first.\"},\n");
        html.append(" field:{de:\"Feld\",en:\"field\"}, value:{de:\"Wert\",en:\"value\"},\n");
        html.append(" addField:{de:\"+ Feld\",en:\"+ field\"}, del:{de:\"✕\",en:\"✕\"},\n");
        html.append(" newField:{de:\"neues Feld\",en:\"new field\"}, newValue:{de:\"Wert\",en:\"value\"}\n");
        html.append("};\n");
        html.append("const tr=k=>T[k][L];\n");
        html.append("// apply static i18n\n");
        html.append("title.textContent=tr(\"title\"); sub.textContent=tr(\"sub\"); document.title=tr(\"title\");\n");
        html.append("document.getElementById(\"h-open\").textContent=tr(\"hOpen\");\n");
        html.append("document.getElementById(\"l-pass\").textContent=tr(\"pass\");\n");
        html.append("document.getElementById(\"l-file\").textContent=tr(\"file\");\n");
        html.append("blob.placeholder=tr(\"blob\"); openBtn.textContent=tr(\"open\"); newBtn.textContent=tr(\"neu\");\n");
        html.append("document.getElementById(\"h-edit\").textContent=tr(\"hEdit\");\n");
        html.append("newProv.placeholder=tr(\"newProv\"); addProvBtn.textContent=tr(\"addProv\");\n");
        html.append("document.getElementById(\"h-save\").textContent=tr(\"hSave\");\n");
        html.append("encBtn.textContent=tr(\"enc\"); dlBtn.textContent=tr(\"dl\"); expBtn.textContent=tr(\"exp\");\n");
        html.append("document.getElementById(\"l-result\").textContent=tr(\"result\");\n");
        html.append("foot.textContent=tr(\"foot\");\n\n");
        
        html.append("let VAULT=null; // {meta, providers:{}}\n\n");
        
        html.append("const enc=new TextEncoder(), dec=new TextDecoder();\n");
        html.append("function u8b64(u8){ let s=\"\"; for(let i=0;i<u8.length;i+=0x8000) s+=String.fromCharCode.apply(null,u8.subarray(i,i+0x8000)); return btoa(s); }\n");
        html.append("function b64u8(b64){ const s=atob(b64.trim()); const u=new Uint8Array(s.length); for(let i=0;i<s.length;i++) u[i]=s.charCodeAt(i); return u; }\n");
        html.append("async function deriveKey(pw,salt){\n");
        html.append("  const km=await crypto.subtle.importKey(\"raw\",enc.encode(pw),\"PBKDF2\",false,[\"deriveKey\"]);\n");
        html.append("  return crypto.subtle.deriveKey({name:\"PBKDF2\",salt,iterations:210000,hash:\"SHA-256\"},km,{name:\"AES-GCM\",length:256},false,[\"encrypt\",\"decrypt\"]);\n");
        html.append("}\n");
        html.append("async function encryptObj(obj,pw){\n");
        html.append("  const salt=crypto.getRandomValues(new Uint8Array(16)), iv=crypto.getRandomValues(new Uint8Array(12));\n");
        html.append("  const key=await deriveKey(pw,salt);\n");
        html.append("  const ct=new Uint8Array(await crypto.subtle.encrypt({name:\"AES-GCM\",iv},key,enc.encode(JSON.stringify(obj,null,2))));\n");
        html.append("  const magic=enc.encode(\"SVPB1\"); const out=new Uint8Array(5+16+12+ct.length);\n");
        html.append("  out.set(magic,0); out.set(salt,5); out.set(iv,21); out.set(ct,33); return u8b64(out);\n");
        html.append("}\n");
        html.append("async function decryptB64(b64,pw){\n");
        html.append("  const raw=b64u8(b64); if(dec.decode(raw.slice(0,5))!==\"SVPB1\") throw new Error(\"magic\");\n");
        html.append("  const key=await deriveKey(pw,raw.slice(5,21));\n");
        html.append("  const pt=await crypto.subtle.decrypt({name:\"AES-GCM\",iv:raw.slice(21,33)},key,raw.slice(33));\n");
        html.append("  return JSON.parse(dec.decode(pt));\n");
        html.append("}\n");
        html.append("function esc(s){return (s==null?\"\":String(s)).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));}\n\n");
        
        html.append("function renderEditor(){\n");
        html.append("  document.getElementById(\"editor\").classList.remove(\"hide\");\n");
        html.append("  document.getElementById(\"out\").classList.remove(\"hide\");\n");
        html.append("  const P=VAULT.providers||{}; const root=document.getElementById(\"provs\"); root.innerHTML=\"\";\n");
        html.append("  Object.keys(P).forEach(name=>{\n");
        html.append("    const d=document.createElement(\"div\"); d.className=\"prov\";\n");
        html.append("    let rows=\"\";\n");
        html.append("    Object.keys(P[name]).forEach(k=>{ rows+=`<div class=\"kv\"><span class=\"k\">${esc(k)}</span><input data-p=\"${esc(name)}\" data-k=\"${esc(k)}\" value=\"${esc(P[name][k])}\"><button class=\"btn sm\" data-del=\"${esc(name)}|${esc(k)}\">${tr(\"del\")}</button></div>`; });\n");
        html.append("    d.innerHTML=`<h3>${esc(name)} <button class=\"btn sm\" data-delp=\"${esc(name)}\">${tr(\"del\")}</button></h3>${rows}\n");
        html.append("      <div class=\"row\" style=\"margin-top:6px\"><input class=\"nf\" data-np=\"${esc(name)}\" placeholder=\"${tr(\"newField\")}\" style=\"max-width:180px\"><input class=\"nv\" data-np=\"${esc(name)}\" placeholder=\"${tr(\"newValue\")}\" style=\"max-width:260px\"><button class=\"btn sm\" data-addf=\"${esc(name)}\">${tr(\"addField\")}</button></div>`;\n");
        html.append("    root.appendChild(d);\n");
        html.append("  });\n");
        html.append("  root.querySelectorAll(\"input[data-k]\").forEach(i=>i.onchange=()=>{ VAULT.providers[i.dataset.p][i.dataset.k]=i.value; });\n");
        html.append("  root.querySelectorAll(\"button[data-del]\").forEach(b=>b.onclick=()=>{ const [p,k]=b.dataset.del.split(\"|\"); delete VAULT.providers[p][k]; renderEditor(); });\n");
        html.append("  root.querySelectorAll(\"button[data-delp]\").forEach(b=>b.onclick=()=>{ delete VAULT.providers[b.dataset.delp]; renderEditor(); });\n");
        html.append("  root.querySelectorAll(\"button[data-addf]\").forEach(b=>b.onclick=()=>{ const p=b.dataset.addf; const nf=root.querySelector(`.nf[data-np=\"${CSS.escape(p)}\"]`).value.trim(); const nv=root.querySelector(`.nv[data-np=\"${CSS.escape(p)}\"]`).value; if(nf){ VAULT.providers[p][nf]=nv; renderEditor(); } });\n");
        html.append("}\n\n");
        
        html.append("document.getElementById(\"file\").onchange=e=>{ const f=e.target.files[0]; if(!f)return; const r=new FileReader(); r.onload=()=>{ blob.value=r.result.trim(); }; r.readAsText(f); };\n");
        html.append("openBtn.onclick=async()=>{\n");
        html.append("  const m=document.getElementById(\"openMsg\"); m.className=\"msg\"; m.textContent=\"\";\n");
        html.append("  if(!pass.value){ m.className=\"msg err\"; m.textContent=tr(\"needPass\"); return; }\n");
        html.append("  if(!blob.value.trim()){ m.className=\"msg err\"; m.textContent=tr(\"noInput\"); return; }\n");
        html.append("  try{ VAULT=await decryptB64(blob.value,pass.value); if(!VAULT.providers)VAULT.providers={}; renderEditor(); m.className=\"msg ok\"; m.textContent=tr(\"opened\"); }\n");
        html.append("  catch(err){ m.className=\"msg err\"; m.textContent=tr(\"bad\"); }\n");
        html.append("};\n");
        html.append("newBtn.onclick=()=>{\n");
        html.append("  const m=document.getElementById(\"openMsg\");\n");
        html.append("  if(!pass.value){ m.className=\"msg err\"; m.textContent=tr(\"needPass\"); return; }\n");
        html.append("  VAULT={meta:{created:new Date().toISOString().slice(0,10),format:\"SVPB1\"},providers:{}}; renderEditor();\n");
        html.append("  m.className=\"msg ok\"; m.textContent=tr(\"created\");\n");
        html.append("};\n");
        html.append("addProvBtn.onclick=()=>{ if(!VAULT){ return; } const n=newProv.value.trim(); if(n){ VAULT.providers[n]=VAULT.providers[n]||{}; newProv.value=\"\"; renderEditor(); } };\n");
        html.append("encBtn.onclick=async()=>{\n");
        html.append("  const m=document.getElementById(\"saveMsg\"); m.className=\"msg\";\n");
        html.append("  if(!VAULT){ m.className=\"msg err\"; m.textContent=tr(\"needOpen\"); return; }\n");
        html.append("  if(!pass.value){ m.className=\"msg err\"; m.textContent=tr(\"needPass\"); return; }\n");
        html.append("  result.value=await encryptObj(VAULT,pass.value); m.className=\"msg ok\"; m.textContent=tr(\"encrypted\");\n");
        html.append("};\n");
        html.append("dlBtn.onclick=()=>{ if(!result.value)return; try{ const b=new Blob([result.value],{type:\"text/plain\"}); const u=URL.createObjectURL(b); const a=document.createElement(\"a\"); a.href=u; a.download=\"vault.svpb\"; document.body.appendChild(a); a.click(); a.remove(); setTimeout(()=>URL.revokeObjectURL(u),1500);}catch(e){} };\n");
        html.append("expBtn.onclick=()=>{ if(!VAULT)return; result.value=JSON.stringify(VAULT,null,2); };\n");
        html.append("</script>\n");
        html.append("</body>\n</html>");
        
        return html.toString();
    }
}
