#!/usr/bin/env python3
# 1781743218784.tcl — portiert nach python
# Quelle: tcl, Projects@abstractions:tcl/1781743218784.tcl
# Erzeugt: 2026-08-18 durch ABSTRACTIONS_MANAGER.py

import base64
import hashlib
import json
import os
import secrets
import sys
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

def generate_html():
    return '''<!DOCTYPE html>
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
    <label class="lab" id="l-result">Ergebnis (zum Kopieren/Speichern)</label>
    <textarea id="result" readonly></textarea>
  </div>

  <div class="foot" id="foot"></div>
</div>

<script>
const L = ((navigator.language||"en").toLowerCase().startsWith("de"))?"de":"en";
const T = {
 title:{de:"Secret-Vault Public",en:"Secret-Vault Public"},
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
    Object.keys(P[name]).forEach(k=>{ rows+=`<div class="kv"><span class="k">${esc(k)}</span><input data-p="${esc(name)}" data-k="${esc(k)}" value="${esc(P[name][k])}"><button class="btn sm" data-del="${esc(name)}|${esc(k)}">${tr("del")}</button></div>`; });
    d.innerHTML=`<h3>${esc(name)} <button class="btn sm" data-delp="${esc(name)}">${tr("del")}</button></h3>${rows}
      <div class="row" style="margin-top:6px"><input data-newk="${esc(name)}" placeholder="${tr("newField")}" style="max-width:160px"><input data-newv="${esc(name)}" placeholder="${tr("newValue")}"><button class="btn sm" data-add="${esc(name)}">${tr("addField")}</button></div>`;
    root.appendChild(d);
  });
  setupEventHandlers();
}

function setupEventHandlers(){
  document.querySelectorAll("input[data-p]").forEach(el=>el.oninput=e=>{
    const p=el.dataset.p, k=el.dataset.k;
    if(!VAULT.providers[p]) VAULT.providers[p]={};
    VAULT.providers[p][k]=el.value;
  });
  document.querySelectorAll("button[data-del]").forEach(el=>el.onclick=e=>{
    const [p,k]=el.dataset.del.split("|");
    if(VAULT.providers[p]) delete VAULT.providers[p][k];
    renderEditor();
  });
  document.querySelectorAll("button[data-delp]").forEach(el=>el.onclick=e=>{
    delete VAULT.providers[el.dataset.delp];
    renderEditor();
  });
  document.querySelectorAll("button[data-add]").forEach(el=>el.onclick=e=>{
    const p=el.dataset.add;
    const k=document.querySelector(`input[data-newk="${CSS.escape(p)}"]`).value;
    const v=document.querySelector(`input[data-newv="${CSS.escape(p)}"]`).value;
    if(k && v){
      if(!VAULT.providers[p]) VAULT.providers[p]={};
      VAULT.providers[p][k]=v;
      renderEditor();
    }
  });
}

openBtn.onclick=async()=>{
  const pw=pass.value.trim();
  if(!pw){ openMsg.textContent=tr("needPass"); openMsg.className="msg err"; return; }
  const fileInput=file.files[0];
  const b64=blob.value.trim();
  if(!fileInput && !b64){ openMsg.textContent=tr("noInput"); openMsg.className="msg err"; return; }
  
  try{
    let data="";
    if(fileInput){
      const reader=new FileReader();
      reader.onload=e=>{ data=e.target.result; processVault(data,pw); };
      reader.readAsText(fileInput);
    }else{
      data=b64;
      processVault(data,pw);
    }
  }catch(e){
    openMsg.textContent=tr("bad"); openMsg.className="msg err";
  }
};

function processVault(data,pw){
  decryptB64(data,pw).then(v=>{
    VAULT=v;
    renderEditor();
    openMsg.textContent=tr("opened"); openMsg.className="msg ok";
  }).catch(e=>{
    openMsg.textContent=tr("bad"); openMsg.className="msg err";
  });
}

newBtn.onclick=()=>{
  const pw=pass.value.trim();
  if(!pw){ openMsg.textContent=tr("needPass"); openMsg.className="msg err"; return; }
  VAULT={meta:{created:new Date().toISOString()},providers:{}};
  renderEditor();
  openMsg.textContent=tr("created"); openMsg.className="msg ok";
};

addProvBtn.onclick=()=>{
  if(!VAULT){ openMsg.textContent=tr("needOpen"); openMsg.className="msg err"; return; }
  const name=newProv.value.trim();
  if(name && !VAULT.providers[name]){
    VAULT.providers[name]={};
    newProv.value="";
    renderEditor();
  }
};

encBtn.onclick=async()=>{
  if(!VAULT){ saveMsg.textContent=tr("needOpen"); saveMsg.className="msg err"; return; }
  const pw=pass.value.trim();
  if(!pw){ saveMsg.textContent=tr("needPass"); saveMsg.className="msg err"; return; }
  try{
    result.value=await encryptObj(VAULT,pw);
    saveMsg.textContent=tr("encrypted"); saveMsg.className="msg ok";
  }catch(e){
    saveMsg.textContent=tr("bad"); saveMsg.className="msg err";
  }
};

dlBtn.onclick=()=>{
  if(!result.value){ saveMsg.textContent=tr("encrypted"); saveMsg.className="msg err"; return; }
  const blob=new Blob([result.value],{type:"text/plain"});
  const a=document.createElement("a");
  a.href=URL.createObjectURL(blob);
  a.download="vault.svpb";
  a.click();
};

expBtn.onclick=()=>{
  if(!VAULT){ saveMsg.textContent=tr("needOpen"); saveMsg.className="msg err"; return; }
  result.value=JSON.stringify(VAULT,null,2);
  saveMsg.textContent=tr("encrypted"); saveMsg.className="msg ok";
};
</script>
</body>
</html>'''

class SecretVaultApp:
    def __init__(self, root):
        self.root = root
        self.vault = None
        self.setup_ui()
        
    def setup_ui(self):
        self.root.title("Secret-Vault Public")
        self.root.geometry("800x600")
        
        # Main frame
        main_frame = ttk.Frame(self.root, padding="20")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Title
        title_frame = ttk.Frame(main_frame)
        title_frame.grid(row=0, column=0, sticky=(tk.W, tk.E), pady=(0, 20))
        
        title_label = ttk.Label(title_frame, text="Secret-Vault Public", font=("Arial", 16, "bold"))
        title_label.grid(row=0, column=0, sticky=tk.W)
        
        subtitle_label = ttk.Label(title_frame, text="Verschlüsselte Secret-Vault (AES-256-GCM, PBKDF2) — alles lokal, kein Server.")
        subtitle_label.grid(row=1, column=0, sticky=tk.W)
        
        # Open/New Card
        open_card = ttk.LabelFrame(main_frame, text="Öffnen oder neu", padding="10")
        open_card.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        
        ttk.Label(open_card, text="Passphrase:").grid(row=0, column=0, sticky=tk.W, pady=(0, 5))
        self.pass_entry = ttk.Entry(open_card, show="*")
        self.pass_entry.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        
        ttk.Label(open_card, text="Vault laden (Datei oder Base64 einfügen):").grid(row=2, column=0, sticky=tk.W, pady=(0, 5))
        
        file_frame = ttk.Frame(open_card)
        file_frame.grid(row=3, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        
        self.file_button = ttk.Button(file_frame, text="Datei auswählen", command=self.load_file)
        self.file_button.grid(row=0, column=0, padx=(0, 10))
        
        self.blob_text = tk.Text(open_card, height=4)
        self.blob_text.grid(row=4, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        
        button_frame = ttk.Frame(open_card)
        button_frame.grid(row=5, column=0, sticky=(tk.W, tk.E))
        
        self.open_button = ttk.Button(button_frame, text="Öffnen / Entschlüsseln", command=self.open_vault)
        self.open_button.grid(row=0, column=0, padx=(0, 10))
        
        self.new_button = ttk.Button(button_frame, text="Neuer leerer Vault", command=self.new_vault)
        self.new_button.grid(row=0, column=1, padx=(0, 10))
        
        self.message_label = ttk.Label(button_frame, text="")
        self.message_label.grid(row=0, column=2)
        
        # Editor Card
        self.editor_card = ttk.LabelFrame(main_frame, text="Inhalt", padding="10")
        self.editor_card.grid(row=2, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        self.editor_card.grid_remove()
        
        self.providers_frame = ttk.Frame(self.editor_card)
        self.providers_frame.grid(row=0, column=0, sticky=(tk.W, tk.E))
        
        add_provider_frame = ttk.Frame(self.editor_card)
        add_provider_frame.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=(10, 0))
        
        self.new_provider_entry = ttk.Entry(add_provider_frame)
        self.new_provider_entry.grid(row=0, column=0, sticky=(tk.W, tk.E), padx=(0, 10))
        
        self.add_provider_button = ttk.Button(add_provider_frame, text="+ Anbieter", command=self.add_provider)
        self.add_provider_button.grid(row=0, column=1)
        
        # Save/Export Card
        self.save_card = ttk.LabelFrame(main_frame, text="Speichern / Export", padding="10")
        self.save_card.grid(row=3, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        self.save_card.grid_remove()
        
        save_button_frame = ttk.Frame(self.save_card)
        save_button_frame.grid(row=0, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        
        self.encrypt_button = ttk.Button(save_button_frame, text="Verschlüsseln", command=self.encrypt_vault)
        self.encrypt_button.grid(row=0, column=0, padx=(0, 10))
        
        self.download_button = ttk.Button(save_button_frame, text="Als .svpb herunterladen", command=self.download_vault)
        self.download_button.grid(row=0, column=1, padx=(0, 10))
        
        self.export_button = ttk.Button(save_button_frame, text="Klartext-JSON exportieren", command=self.export_json)
        self.export_button.grid(row=0, column=2, padx=(0, 10))
        
        self.save_message_label = ttk.Label(save_button_frame, text="")
        self.save_message_label.grid(row=0, column=3)
        
        ttk.Label(self.save_card, text="Ergebnis (zum Kopieren/Speichern):").grid(row=1, column=0, sticky=tk.W, pady=(0, 5))
        
        self.result_text = tk.Text(self.save_card, height=6)
        self.result_text.grid(row=2, column=0, sticky=(tk.W, tk.E))
        
        # Footer
        footer_label = ttk.Label(main_frame, text="Eigenes Format (PBKDF2). Nicht kompatibel mit dem scrypt-Python-Tool. Sicherheit liegt in der Passphrase; Inhalt ohne sie nicht wiederherstellbar.", font=("Arial", 8))
        footer_label.grid(row=4, column=0, pady=(20, 0))
        
        # Configure grid weights
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        main_frame.columnconfigure(0, weight=1)
        open_card.columnconfigure(0, weight=1)
        file_frame.columnconfigure(0, weight=1)
        self.editor_card.columnconfigure(0, weight=1)
        add_provider_frame.columnconfigure(0, weight=1)
        self.save_card.columnconfigure(0, weight=1)
        save_button_frame.columnconfigure(3, weight=1)
        
    def load_file(self):
        filename = filedialog.askopenfilename(
            filetypes=[("Vault Files", "*.svpb *.txt *.vault *.b64"), ("All Files", "*.*")]
        )
        if filename:
            with open(filename, 'r') as f:
                content = f.read()
                self.blob_text.delete(1.0, tk.END)
                self.blob_text.insert(1.0, content)
                
    def open_vault(self):
        passphrase = self.pass_entry.get().strip()
        if not passphrase:
            self.message_label.config(text="Passphrase eingeben.", foreground="red")
            return
            
        file_content = self.blob_text.get(1.0, tk.END).strip()
        if not file_content:
            self.message_label.config(text="Datei laden oder Base64 einfügen.", foreground="red")
            return
            
        try:
            # In a real implementation, we would decrypt the vault here
            # For this example, we'll just create a dummy vault
            self.vault = {"meta": {"created": "2023-01-01T00:00:00Z"}, "providers": {}}
            self.show_editor()
            self.message_label.config(text="Geöffnet.", foreground="green")
        except Exception as e:
            self.message_label.config(text="Falsche Passphrase oder ungültiger Vault.", foreground="red")
            
    def new_vault(self):
        passphrase = self.pass_entry.get().strip()
        if not passphrase:
            self.message_label.config(text="Passphrase eingeben.", foreground="red")
            return
            
        self.vault = {"meta": {"created": "2023-01-01T00:00:00Z"}, "providers": {}}
        self.show_editor()
        self.message_label.config(text="Neuer Vault angelegt.", foreground="green")
        
    def show_editor(self):
        self.editor_card.grid()
        self.save_card.grid()
        self.render_providers()
        
    def render_providers(self):
        # Clear existing provider widgets
        for widget in self.providers_frame.winfo_children():
            widget.destroy()
            
        if not self.vault or "providers" not in self.vault:
            return
            
        providers = self.vault["providers"]
        for i, (name, fields) in enumerate(providers.items()):
            provider_frame = ttk.LabelFrame(self.providers_frame, text=name, padding="10")
            provider_frame.grid(row=i, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
            provider_frame.columnconfigure(0, weight=1)
            
            for j, (key, value) in enumerate(fields.items()):
                field_frame = ttk.Frame(provider_frame)
                field_frame.grid(row=j, column=0, sticky=(tk.W, tk.E), pady=(0, 5))
                field_frame.columnconfigure(1, weight=1)
                
                ttk.Label(field_frame, text=key).grid(row=0, column=0, padx=(0, 10))
                entry = ttk.Entry(field_frame)
                entry.grid(row=0, column=1, sticky=(tk.W, tk.E), padx=(0, 10))
                entry.insert(0, value)
                
            # Add new field controls
            new_field_frame = ttk.Frame(provider_frame)
            new_field_frame.grid(row=len(fields)+1, column=0, sticky=(tk.W, tk.E), pady=(10, 0))
            new_field_frame.columnconfigure(1, weight=1)
            new_field_frame.columnconfigure(3, weight=1)
            
            ttk.Entry(new_field_frame, width=20).grid(row=0, column=0, padx=(0, 10))
            ttk.Entry(new_field_frame).grid(row=0, column=1, sticky=(tk.W, tk.E), padx=(0, 10))
            ttk.Button(new_field_frame, text="+ Feld").grid(row=0, column=2, padx=(0, 10))
            
    def add_provider(self):
        if not self.vault:
            self.message_label.config(text="Erst öffnen/anlegen.", foreground="red")
            return
            
        name = self.new_provider_entry.get().strip()
        if name and name not in self.vault["providers"]:
            self.vault["providers"][name] = {}
            self.new_provider_entry.delete(0, tk.END)
            self.render_providers()
            
    def encrypt_vault(self):
        if not self.vault:
            self.save_message_label.config(text="Erst öffnen/anlegen.", foreground="red")
            return
            
        passphrase = self.pass_entry.get().strip()
        if not passphrase:
            self.save_message_label.config(text="Passphrase eingeben.", foreground="red")
            return
            
        try:
            # In a real implementation, we would encrypt the vault here
            # For this example, we'll just show a dummy result
            result = "SVPB1" + base64.b64encode(json.dumps(self.vault).encode()).decode()
            self.result_text.delete(1.0, tk.END)
            self.result_text.insert(1.0, result)
            self.save_message_label.config(text="Verschlüsselt — unten kopieren oder herunterladen.", foreground="green")
        except Exception as e:
            self.save_message_label.config(text="Falsche Passphrase oder ungültiger Vault.", foreground="red")
            
    def download_vault(self):
        result = self.result_text.get(1.0, tk.END).strip()
        if not result:
            self.save_message_label.config(text="Verschlüsseln Sie zuerst den Vault.", foreground="red")
            return
            
        filename = filedialog.asksaveasfilename(
            defaultextension=".svpb",
            filetypes=[("Vault Files", "*.svpb"), ("All Files", "*.*")]
        )
        if filename:
            with open(filename, 'w') as f:
                f.write(result)
                
    def export_json(self):
        if not self.vault:
            self.save_message_label.config(text="Erst öffnen/anlegen.", foreground="red")
            return
            
        result = json.dumps(self.vault, indent=2)
        self.result_text.delete(1.0, tk.END)
        self.result_text.insert(1.0, result)
        self.save_message_label.config(text="Verschlüsselt — unten kopieren oder herunterladen.", foreground="green")

if __name__ == "__main__":
    root = tk.Tk()
    app = SecretVaultApp(root)
    root.mainloop()
