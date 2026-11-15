#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "1d9b1d5f0473998a7db0e7bde6c9e8e1b9179d68b049fac60d1b107cef1dcc1f", "source_sha256": "5aa602a80e57cbc63f54485d4cd66e205c54bd9f32bc03434218ff9bd388b3ab", "target_language": "lua"}
-- collect_compare_bundle.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:scripts/collect_compare_bundle.sh
-- auch in: OpenClaw@gateway2:scripts/collect_compare_bundle.sh
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

local ROOT = "/home/openclaw/.openclaw"
local OUT_DIR = ROOT .. "/workspace/vscode/compare"
local TRANSFER_DIR = OUT_DIR .. "/transfer"
local MD_FILE = OUT_DIR .. "/local-gateway-config.md"
local TREE_FILE = OUT_DIR .. "/tree.txt"
local BACKUP_FILE = "/home/openclaw/openclaw-backup.tar.gz"

-- Get current time in local and UTC formats
local NOW_LOCAL = os.date("%Y-%m-%d %H:%M:%S %Z")
local NOW_UTC = os.date("!%Y-%m-%dT%H:%M:%SZ")

-- Get hostname
local function get_hostname()
  local f = io.popen("hostname -f 2>/dev/null || hostname", "r")
  local hostname = f:read("*l")
  f:close()
  return hostname or "unknown"
end
local HOST = get_hostname()

local OPENCLAW_JSON = ROOT .. "/openclaw.json"
local EXEC_APPROVALS_JSON = ROOT .. "/exec-approvals.json"
local GATEWAY_SYSTEMD_ENV = ROOT .. "/gateway.systemd.env"
local DOT_ENV = ROOT .. "/.env"
local CONFIG_DIR = ROOT .. "/.config"
local AGENTS_DIR = ROOT .. "/agents"

-- Create directories
local function mkdir_p(path)
  os.execute("mkdir -p " .. path)
end

mkdir_p(OUT_DIR)
mkdir_p(TRANSFER_DIR)

-- Check if 'tree' command exists
local function check_tree()
  local result = os.execute("command -v tree >/dev/null 2>&1")
  if not result then
    print("Fehler: 'tree' ist nicht installiert.")
    os.exit(1)
  end
end

check_tree()

-- Append file content verbatim to markdown
local function append_file_verbatim(label, path, lang)
  lang = lang or "text"
  local md = io.open(MD_FILE, "a")
  
  md:write("\n")
  md:write("## " .. label .. "\n")
  md:write("\n")
  md:write("Pfad: `" .. path .. "`\n")
  md:write("\n")
  md:write("```" .. lang .. "\n")
  
  local file = io.open(path, "r")
  if file then
    md:write(file:read("*a"))
    file:close()
  else
    md:write("[FEHLT] " .. path .. "\n")
  end
  
  md:write("\n```\n")
  md:close()
end

-- Append environment variables to markdown
local function append_env_verbatim()
  local md = io.open(MD_FILE, "a")
  md:write("\n")
  md:write("## Umgebungsvariablen (env)\n")
  md:write("\n")
  md:write("```text\n")
  
  local env_vars = {}
  for k, v in pairs(os.getenv()) do
    table.insert(env_vars, k .. "=" .. v)
  end
  table.sort(env_vars)
  
  for _, line in ipairs(env_vars) do
    md:write(line .. "\n")
  end
  
  md:write("```\n")
  md:close()
end

-- Append directory files recursively to markdown
local function append_dir_files_verbatim(section, dir)
  local md = io.open(MD_FILE, "a")
  md:write("\n")
  md:write("## " .. section .. "\n")
  md:write("\n")
  
  local attr = lfs.attributes(dir)
  if not attr or attr.mode ~= "directory" then
    md:write("[FEHLT] " .. dir .. "\n")
    md:close()
    return
  end
  
  md:write("Basisverzeichnis: `" .. dir .. "`\n")
  md:close()
  
  -- Recursively find all files
  local function scan_directory(directory)
    for file in lfs.dir(directory) do
      if file ~= "." and file ~= ".." then
        local filepath = directory .. "/" .. file
        local attr = lfs.attributes(filepath)
        if attr.mode == "directory" then
          scan_directory(filepath)
        elseif attr.mode == "file" then
          local md = io.open(MD_FILE, "a")
          md:write("\n")
          md:write("### Datei: `" .. filepath .. "`\n")
          md:write("\n")
          md:write("```text\n")
          
          local f = io.open(filepath, "r")
          if f then
            md:write(f:read("*a"))
            f:close()
          end
          
          md:write("\n```\n")
          md:close()
        end
      end
    end
  end
  
  scan_directory(dir)
end

-- Write initial header to markdown file
local function write_md_header()
  local md = io.open(MD_FILE, "w")
  md:write("# Lokaler Gateway-Konfigurationsstand\n\n")
  md:write("Generiert: " .. NOW_LOCAL .. "\n")
  md:write("UTC: " .. NOW_UTC .. "\n")
  md:write("Host: " .. HOST .. "\n\n")
  md:write("Diese Datei enthaelt den lokalen Stand mit unveraenderten Inhalten.\n")
  md:close()
end

write_md_header()

append_file_verbatim("openclaw.json", OPENCLAW_JSON, "json")
append_file_verbatim("exec-approvals.json", EXEC_APPROVALS_JSON, "json")
append_file_verbatim("gateway.systemd.env", GATEWAY_SYSTEMD_ENV, "dotenv")
append_file_verbatim(".env", DOT_ENV, "dotenv")
append_env_verbatim()
append_dir_files_verbatim(".config (alle Dateien rekursiv)", CONFIG_DIR)
append_dir_files_verbatim("agents (alle Dateien rekursiv)", AGENTS_DIR)

-- Generate tree output
os.execute("tree -a -L 6 " .. ROOT .. " > " .. TREE_FILE)

-- Create backup
os.execute("openclaw backup create --output " .. BACKUP_FILE .. " --verify")
os.execute("cp " .. BACKUP_FILE .. " " .. OUT_DIR)

print("OK")
print("Erzeugt:")
print("- " .. MD_FILE)
print("- " .. TREE_FILE)
print("- " .. BACKUP_FILE)
print("- " .. TRANSFER_DIR .. " (leer)")
