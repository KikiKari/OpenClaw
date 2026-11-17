#!/data/data/com.termux/files/usr/bin/lua
-- abstraction-provenance: {"artifact_sha256": "25710efbfdb26e6109de6e0a0ebba817a165f14e9e230012154d28c83b362d5d", "source_sha256": "dd115a5287b5db772bd4af098a6620a66b294c0e327633048101753a48a3976b", "target_language": "lua"}
-- openclaw-node-autostart-termux.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:scripts/openclaw-node-autostart-termux.sh
-- auch in: OpenClaw@gateway2:scripts/openclaw-node-autostart-termux.sh
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

-- OpenClaw Node Mode Autostart für Termux (Node 5 - Redmi Note 11)
-- Installiert nach: ~/.termux/boot/openclaw-node.lua
-- Getestet mit: Termux + Android + OpenClaw

local SESSION = "openclaw-node"
local LOGFILE = os.getenv("HOME") .. "/.openclaw/node.log"
local GATEWAY = "10.10.0.1"
local PORT = "18789"

-- Log-Verzeichnis erstellen
os.execute("mkdir -p " .. os.getenv("HOME") .. "/.openclaw")

-- Prüfen ob tmux Session bereits läuft
local function session_exists()
    local handle = io.popen("tmux has-session -t " .. SESSION .. " 2>/dev/null", "r")
    local result = handle:close()
    return result == true
end

if session_exists() then
    local log = io.open(LOGFILE, "a")
    log:write("[" .. os.date() .. "] OpenClaw Node läuft bereits in tmux Session '" .. SESSION .. "'\n")
    log:close()
    os.exit(0)
end

-- Neue tmux Session erstellen und OpenClaw starten
local cmd = [[
while true; do
    echo '[$(date)] Starting OpenClaw Node Mode...' | tee -a ]] .. LOGFILE .. [[
    
    # Prüfe WireGuard Verbindung
    if ! ping -c 1 -W 3 ]] .. GATEWAY .. [[ >/dev/null 2>&1; then
        echo '[$(date)] FEHLER: WireGuard Gateway ]] .. GATEWAY .. [[ nicht erreichbar!' | tee -a ]] .. LOGFILE .. [[
        echo '[$(date)] Warte 10 Sekunden...' | tee -a ]] .. LOGFILE .. [[
        sleep 10
        continue
    fi
    
    # OpenClaw Node Mode starten
    openclaw node run --host ]] .. GATEWAY .. [[ --port ]] .. PORT .. [[ 2>&1 | tee -a ]] .. LOGFILE .. [[
    
    # Wenn der Prozess endet, warte und neustarten
    echo '[$(date)] OpenClaw beendet. Neustart in 5 Sekunden...' | tee -a ]] .. LOGFILE .. [[
    sleep 5
done
]]

os.execute("tmux new-session -d -s " .. SESSION .. " -n \"node\" \"" .. cmd .. "\"")

local log = io.open(LOGFILE, "a")
log:write("[" .. os.date() .. "] OpenClaw Node Autostart aktiviert (tmux Session: " .. SESSION .. ")\n")
log:close()

-- Optional: tmux attach Hinweis falls interaktiv gestartet
if io.type(io.stdout) == "file" then
    print("OpenClaw Node Mode gestartet in tmux Session '" .. SESSION .. "'")
    print("Zum Anschauen: tmux attach -t " .. SESSION)
    print("Log-Datei: " .. LOGFILE)
end
