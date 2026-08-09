#!/usr/bin/env node
// index.html — portiert nach javascript
// Quelle: html, Projects@secret-vault-public:secret-vault-public/index.html
// Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');

function createHTMLDocument() {
  // Create the basic HTML structure
  const doc = {
    doctype: '<!DOCTYPE html>',
    html: {
      attrs: { lang: 'de' },
      head: {
        meta: [
          { charset: 'utf-8' },
          { name: 'viewport', content: 'width=device-width, initial-scale=1' }
        ],
        title: 'Vault Cache',
        style: `
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
`
      },
      body: {
        content: []
      }
    }
  };

  // Add meta script
  const metaScript = {
    tag: 'script',
    attrs: { 
      type: 'application/json', 
      id: 'cowork-artifact-meta' 
    },
    content: JSON.stringify({
      "name": "Secret Vault Public",
      "schemaVersion": 1,
      "description": "Secret-Vault Public als interaktives Browser-Artefakt: verschlüsselter Secret-Container vollständig client-seitig (WebCrypto, AES-256-GCM + PBKDF2). Öffnen/Anlegen, Anbieter/Felder ergänzen und ersetzen (Rotation), verschlüsseln und als .svpb herunterladen oder Klartext-JSON exportieren. DE/EN nach Browsersprache. Eigenes Format (nicht kompatibel mit dem scrypt-Python-Tool). Keine Secrets eingebettet.",
      "mcpTools": [],
      "mcpServerNames": []
    }, null, 2)
  };

  // Add body content
  const bodyContent = [
    {
      tag: 'div',
      attrs: { class: 'wrap' },
      content: [
        {
          tag: 'div',
          attrs: { class: 'brand' },
          content: [
            { tag: 'div', attrs: { class: 'mark' } },
            { tag: 'h1', attrs: { id: 'title' }, content: 'Vault Cache' }
          ]
        },
        { tag: 'div', attrs: { class: 'sub', id: 'sub' }, content: 'Verschlüsselte Secret-Vault (AES-256-GCM, PBKDF2) — alles im Browser, kein Server.' },
        
        // Open/New card
        {
          tag: 'div',
          attrs: { class: 'card' },
          content: [
            { tag: 'h2', attrs: { id: 'h-open' }, content: 'Öffnen oder neu' },
            { tag: 'label', attrs: { class: 'lab', id: 'l-pass' }, content: 'Passphrase' },
            { tag: 'input', attrs: { id: 'pass', type: 'password', placeholder: 'Passphrase…' } },
            { tag: 'label', attrs: { class: 'lab', id: 'l-file' }, content: 'Vault laden (Datei oder Base64 einfügen)' },
            { tag: 'input', attrs: { id: 'file', type: 'file', accept: '.svpb,.txt,.vault,.b64' } },
            { tag: 'textarea', attrs: { id: 'blob', placeholder: '…oder Base64 hier einfügen' } },
            {
              tag: 'div',
              attrs: { class: 'row', style: 'margin-top:10px' },
              content: [
                { tag: 'button', attrs: { class: 'btn primary', id: 'openBtn' }, content: 'Öffnen / Entschlüsseln' },
                { tag: 'button', attrs: { class: 'btn', id: 'newBtn' }, content: 'Neuer leerer Vault' },
                { tag: 'span', attrs: { class: 'msg', id: 'openMsg' } }
              ]
            }
          ]
        },
        
        // Editor card
        {
          tag: 'div',
          attrs: { class: 'card hide', id: 'editor' },
          content: [
            { tag: 'h2', attrs: { id: 'h-edit' }, content: 'Inhalt' },
            { tag: 'div', attrs: { id: 'provs' } },
            {
              tag: 'div',
              attrs: { class: 'row', style: 'margin-top:8px' },
              content: [
                { tag: 'input', attrs: { id: 'newProv', placeholder: 'Neuer Anbieter (Name)', style: 'max-width:280px' } },
                { tag: 'button', attrs: { class: 'btn sm', id: 'addProvBtn' }, content: '+ Anbieter' }
              ]
            }
          ]
        },
        
        // Save/Export card
        {
          tag: 'div',
          attrs: { class: 'card hide', id: 'out' },
          content: [
            { tag: 'h2', attrs: { id: 'h-save' }, content: 'Speichern / Export' },
            {
              tag: 'div',
              attrs: { class: 'row' },
              content: [
                { tag: 'button', attrs: { class: 'btn primary', id: 'encBtn' }, content: 'Verschlüsseln' },
                { tag: 'button', attrs: { class: 'btn', id: 'dlBtn' }, content: 'Als .svpb herunterladen' },
                { tag: 'button', attrs: { class: 'btn', id: 'expBtn' }, content: 'Klartext-JSON exportieren' },
                { tag: 'span', attrs: { class: 'msg', id: 'saveMsg' } }
              ]
            },
            { tag: 'label', attrs: { class: 'lab', id: 'l-result' }, content: 'Ergebnis (zum Kopieren/Speichern)' },
            { tag: 'textarea', attrs: { id: 'result', readonly: true } }
          ]
        },
        
        { tag: 'div', attrs: { class: 'foot', id: 'foot' } }
      ]
    }
  ];

  doc.html.body.content = bodyContent;

  // Add script
  const script = {
    tag: 'script',
    content: `
const L = ((navigator.language||"en").toLowerCase().startsWith("de"))?"de":"en";
const T = {
 title:{de:"Vault Cache",en:"Vault Cache"},
 sub:{de:"Verschlüsselte Secret-Vault (AES-256-GCM, PBKDF2) — alles im Browser, kein Server.",en:"Encrypted secret vault (AES-256-GCM, PBKDF2) — fully in the browser, no server."},
 hOpen:{de:"Öffnen oder neu",en:"Open or new"},
 pass:{de:"Passphrase",en:"Passphrase"},
 file:{de:"Vault laden (Datei oder Base64 einfügen)",en:"Load vault (file or paste Base64)"},
 blob:{de:"…oder Base64 hier einfügen",en:"…or paste Base64 here"},
 open:{de:"Öffnen / Entschlüsseln",en:"Open / Decrypt"},
 neu:{de:"Neuer leerer Vault",en:"New empty vault"},
 hEdit:{de:"Inhalt",en:"Content"},
 newProv:{de:"Neuer Anbieter (Name)",en:"New provider (name)"},
 addProv:{de:"+ Anbieter",en:"+ Provider"},
 hSave:{de:"Speichern / Export",en:"Save / Export"},
 enc:{de:"Verschlüsseln",en:"Encrypt"},
 dl:{de:"Als .svpb herunterladen",en:"Download as .svpb"},
 exp:{de:"Klartext-JSON exportieren",en:"Export plaintext JSON"},
 result:{de:"Ergebnis (zum Kopieren/Speichern)",en:"Result (to copy/save)"},
 foot:{de:"Eigenes Format (PBKDF2). Nicht kompatibel mit dem scrypt-Python-Tool. Sicherheit liegt in der Passphrase; Inhalt ohne sie nicht wiederherstellbar.",en:"Own format (PBKDF2). Not compatible with the scrypt Python tool. Security rests on the passphrase; content is unrecoverable without it."},
 needPass:{de:"Passphrase eingeben.",en:"Enter a passphrase."},
 noInput:{de:"Datei laden oder Base64 einfügen.",en:"Load a file or paste Base64."},
 bad:{de:"Falsche Passphrase oder ungültiger Vault.",en:"Wrong passphrase or invalid vault."},
 opened:{de:"Geöffnet.",en:"Opened."},
 created:{de:"Neuer Vault angelegt.",en:"New vault created."},
 encrypted:{de:"Verschlüsselt — unten kopieren oder herunterladen.",en:"Encrypted — copy below or download."},
 needOpen:{de:"Erst öffnen/anlegen.",en:"Open/create first."},
 field:{de:"Feld",en:"field"}, value:{de:"Wert",en:"value"},
 addField:{de:"+ Feld",en:"+ field"}, del:{de:"✕",en:"✕"},
 newField:{de:"neues Feld",en:"new field"}, newValue:{de:"Wert",en:"value"}
};
const tr=k=>T[k][L];
// apply static i18n
title.textContent=tr("title"); sub.textContent=tr("sub"); document.title=tr("title");
document.getElementById("h-open").textContent=tr("hOpen");
document.getElementById("l-pass").textContent=tr("pass");
document.getElementById("l-file").textContent=tr("file");
blob.placeholder=tr("blob");
openBtn.textContent=tr("open"); newBtn.textContent=tr("neu");
document.getElementById("h-edit").textContent=tr("hEdit");
newProv.placeholder=tr("newProv"); addProvBtn.textContent=tr("addProv");
document.getElementById("h-save").textContent=tr("hSave");
encBtn.textContent=tr("enc"); dlBtn.textContent=tr("dl"); expBtn.textContent=tr("exp");
document.getElementById("l-result").textContent=tr("result");
foot.textContent=tr("foot");

let VAULT=null; // {meta, providers:{}}

const enc=new TextEncoder(), dec=new TextDecoder();
function u8b64(u8){ let s=""; for(let i=0;i<u8.length;i+=0x8000) s+=String.fromCharCode.apply(null,u8.subarray(i,i+0x8000)); return btoa(s); }
function b64u8(b64){ const s=atob(b64.trim()); const u=new Uint8Array(s.length); for(let i=0;i<s.length;i++) u[i]=s.charCodeAt(i); return u; }
async function deriveKey(pw,salt){
  const km=await crypto.subtle.importKey("raw",enc.encode(pw),"PBKDF2",false,["deriveKey"]);
  return crypto.subtle.deriveKey({name:"PBKDF2",salt,iterations:210000,hash:"SHA-256"},km,{name:"AES-GCM",length:256},false,["encrypt","decrypt"]);
}
async function encryptObj(obj,pw){
  const salt=crypto.getRandomValues(new Uint8Array(16)), iv=crypto.getRandomValues(new Uint8Array(12));
  const key=await deriveKey(pw,salt);
  const ct=new Uint8Array(await crypto.subtle.encrypt({name:"AES-GCM",iv},key,enc.encode(JSON.stringify(obj,null,2))));
  const magic=enc.encode("SVPB1"); const out=new Uint8Array(5+16+12+ct.length);
  out.set(magic,0); out.set(salt,5); out.set(iv,21); out.set(ct,33); return u8b64(out);
}
async function decryptB64(b64,pw){
  const raw=b64u8(b64); if(dec.decode(raw.slice(0,5))!=="SVPB1") throw new Error("magic");
  const key=await deriveKey(pw,raw.slice(5,21));
  const pt=await crypto.subtle.decrypt({name:"AES-GCM",iv:raw.slice(21,33)},key,raw.slice(33));
  return JSON.parse(dec.decode(pt));
}
function esc(s){return (s==null?"":String(s)).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));}

function renderEditor(){
  document.getElementById("editor").classList.remove("hide");
  document.getElementById("out").classList.remove("hide");
  const P=VAULT.providers||{}; const root=document.getElementById("provs"); root.innerHTML="";
  Object.keys(P).forEach(name=>{
    const d=document.createElement("div"); d.className="prov";
    let rows="";
    Object.keys(P[name]).forEach(k=>{ rows+=\`<div class="kv"><span class="k">\${esc(k)}</span><input data-p="\${esc(name)}" data-k="\${esc(k)}" value="\${esc(P[name][k])}"><button class="btn sm" data-del="\${esc(name)}|\${esc(k)}">\${tr("del")}</button></div>\`; });
    d.innerHTML=\`<h3>\${esc(name)} <button class="btn sm" data-delp="\${esc(name)}">\${tr("del")}</button></h3>\${rows}
      <div class="row" style="margin-top:6px"><input class="nf" data-np="\${esc(name)}" placeholder="\${tr("newField")}" style="max-width:180px"><input class="nv" data-np="\${esc(name)}" placeholder="\${tr("newValue")}" style="max-width:260px"><button class="btn sm" data-addf="\${esc(name)}">\${tr("addField")}</button></div>\`;
    root.appendChild(d);
  });
  root.querySelectorAll("input[data-k]").forEach(i=>i.onchange=()=>{ VAULT.providers[i.dataset.p][i.dataset.k]=i.value; });
  root.querySelectorAll("button[data-del]").forEach(b=>b.onclick=()=>{ const [p,k]=b.dataset.del.split("|"); delete VAULT.providers[p][k]; renderEditor(); });
  root.querySelectorAll("button[data-delp]").forEach(b=>b.onclick=()=>{ delete VAULT.providers[b.dataset.delp]; renderEditor(); });
  root.querySelectorAll("button[data-addf]").forEach(b=>b.onclick=()=>{ const p=b.dataset.addf; const nf=root.querySelector(\`.nf[data-np="\${CSS.escape(p)}"]\`).value.trim(); const nv=root.querySelector(\`.nv[data-np="\${CSS.escape(p)}"]\`).value; if(nf){ VAULT.providers[p][nf]=nv; renderEditor(); } });
}

document.getElementById("file").onchange=e=>{ const f=e.target.files[0]; if(!f)return; const r=new FileReader(); r.onload=()=>{ blob.value=r.result.trim(); }; r.readAsText(f); };
openBtn.onclick=async()=>{
  const m=document.getElementById("openMsg"); m.className="msg"; m.textContent="";
  if(!pass.value){ m.className="msg err"; m.textContent=tr("needPass"); return; }
  if(!blob.value.trim()){ m.className="msg err"; m.textContent=tr("noInput"); return; }
  try{ VAULT=await decryptB64(blob.value,pass.value); if(!VAULT.providers)VAULT.providers={}; renderEditor(); m.className="msg ok"; m.textContent=tr("opened"); }
  catch(err){ m.className="msg err"; m.textContent=tr("bad"); }
};
newBtn.onclick=()=>{
  const m=document.getElementById("openMsg");
  if(!pass.value){ m.className="msg err"; m.textContent=tr("needPass"); return; }
  VAULT={meta:{created:new Date().toISOString().slice(0,10),format:"SVPB1"},providers:{}}; renderEditor();
  m.className="msg ok"; m.textContent=tr("created");
};
addProvBtn.onclick=()=>{ if(!VAULT){ return; } const n=newProv.value.trim(); if(n){ VAULT.providers[n]=VAULT.providers[n]||{}; newProv.value=""; renderEditor(); } };
encBtn.onclick=async()=>{
  const m=document.getElementById("saveMsg"); m.className="msg";
  if(!VAULT){ m.className="msg err"; m.textContent=tr("needOpen"); return; }
  if(!pass.value){ m.className="msg err"; m.textContent=tr("needPass"); return; }
  result.value=await encryptObj(VAULT,pass.value); m.className="msg ok"; m.textContent=tr("encrypted");
};
dlBtn.onclick=()=>{ if(!result.value)return; try{ const b=new Blob([result.value],{type:"text/plain"}); const u=URL.createObjectURL(b); const a=document.createElement("a"); a.href=u; a.download="vault.svpb"; document.body.appendChild(a); a.click(); a.remove(); setTimeout(()=>URL.revokeObjectURL(u),1500);}catch(e){} };
expBtn.onclick=()=>{ if(!VAULT)return; result.value=JSON.stringify(VAULT,null,2); };
`
  };

  return { doc, metaScript, script };
}

function renderHTML({ doc, metaScript, script }) {
  let html = doc.doctype + '\n';
  
  // Render html tag with attributes
  html += '<html';
  for (const [key, value] of Object.entries(doc.html.attrs)) {
    html += ` ${key}="${value}"`;
  }
  html += '>\n';
  
  // Render head
  html += '<head>\n';
  doc.html.head.meta.forEach(meta => {
    html += '  <meta';
    for (const [key, value] of Object.entries(meta)) {
      html += ` ${key}="${value}"`;
    }
    html += '>\n';
  });
  html += `  <title>${doc.html.head.title}</title>\n`;
  html += '  <style>\n';
  html += doc.html.head.style;
  html += '  </style>\n';
  html += '</head>\n';
  
  // Render body
  html += '<body>\n';
  
  // Add meta script
  html += `  <script type="${metaScript.attrs.type}" id="${metaScript.attrs.id}">\n`;
  html += metaScript.content;
  html += '\n  </script>\n';
  
  // Add body content
  function renderElement(element, indent = '  ') {
    if (typeof element === 'string') {
      return indent + element + '\n';
    }
    
    if (!element.tag) {
      return '';
    }
    
    let result = indent + '<' + element.tag;
    
    if (element.attrs) {
      for (const [key, value] of Object.entries(element.attrs)) {
        result += ` ${key}="${value}"`;
      }
    }
    
    if (element.content === undefined || element.content === null || element.content.length === 0) {
      result += '></' + element.tag + '>\n';
    } else if (typeof element.content === 'string') {
      result += '>' + element.content + '</' + element.tag + '>\n';
    } else if (Array.isArray(element.content)) {
      result += '>\n';
      element.content.forEach(child => {
        result += renderElement(child, indent + '  ');
      });
      result += indent + '</' + element.tag + '>\n';
    } else {
      result += '>' + element.content + '</' + element.tag + '>\n';
    }
    
    return result;
  }
  
  doc.html.body.content.forEach(element => {
    html += renderElement(element);
  });
  
  // Add main script
  html += '  <script>\n';
  html += script.content;
  html += '\n  </script>\n';
  
  html += '</body>\n';
  html += '</html>\n';
  
  return html;
}

function main() {
  const outputPath = process.argv[2];
  
  if (!outputPath) {
    console.error('Usage: node script.js <output-file>');
    process.exit(1);
  }
  
  const htmlDocument = createHTMLDocument();
  const htmlContent = renderHTML(htmlDocument);
  
  try {
    fs.writeFileSync(outputPath, htmlContent, 'utf8');
    console.log(`HTML file generated successfully: ${outputPath}`);
  } catch (error) {
    console.error('Error writing file:', error);
    process.exit(1);
  }
}

main();
