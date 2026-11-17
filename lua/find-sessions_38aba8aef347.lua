#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "a0e468052c22aa8e59483ea9416460bfeb4e4abfb629665d07b8feed3c521271", "source_sha256": "a137d03b3b37332439a1592831d60479ff86315c7e6d6ed7da0fb799db0f13f7", "target_language": "lua"}
-- find-sessions.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:skills/tmux/scripts/find-sessions.sh
-- auch in: OpenClaw@gateway2:skills/tmux/scripts/find-sessions.sh
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

local function usage()
  io.stderr:write([[
Usage: find-sessions.sh [-L socket-name|-S socket-path|-A] [-q pattern]

List tmux sessions on a socket (default tmux socket if none provided).

Options:
  -L, --socket       tmux socket name (passed to tmux -L)
  -S, --socket-path  tmux socket path (passed to tmux -S)
  -A, --all          scan all sockets under CLAWDBOT_TMUX_SOCKET_DIR
  -q, --query        case-insensitive substring to filter session names
  -h, --help         show this help
]])
end

local socket_name = ""
local socket_path = ""
local query = ""
local scan_all = false
local socket_dir = os.getenv("CLAWDBOT_TMUX_SOCKET_DIR") or (os.getenv("TMPDIR") or "/tmp") .. "/clawdbot-tmux-sockets"

local args = {...}
local i = 1
while i <= #args do
  local arg = args[i]
  if arg == "-L" or arg == "--socket" then
    socket_name = args[i + 1] or ""
    i = i + 2
  elseif arg == "-S" or arg == "--socket-path" then
    socket_path = args[i + 1] or ""
    i = i + 2
  elseif arg == "-A" or arg == "--all" then
    scan_all = true
    i = i + 1
  elseif arg == "-q" or arg == "--query" then
    query = args[i + 1] or ""
    i = i + 2
  elseif arg == "-h" or arg == "--help" then
    usage()
    os.exit(0)
  else
    io.stderr:write("Unknown option: " .. arg .. "\n")
    usage()
    os.exit(1)
  end
end

if scan_all and (socket_name ~= "" or socket_path ~= "") then
  io.stderr:write("Cannot combine --all with -L or -S\n")
  os.exit(1)
end

if socket_name ~= "" and socket_path ~= "" then
  io.stderr:write("Use either -L or -S, not both\n")
  os.exit(1)
end

local function has_tmux()
  local handle = io.popen("command -v tmux >/dev/null 2>&1", "r")
  handle:close()
  return handle:close() == nil
end

if not has_tmux() then
  io.stderr:write("tmux not found in PATH\n")
  os.exit(1)
end

local function list_sessions(label, tmux_args)
  local cmd = "tmux " .. table.concat(tmux_args, " ") .. " list-sessions -F '#{session_name}\t#{session_attached}\t#{session_created_string}' 2>/dev/null"
  
  local handle = io.popen(cmd, "r")
  local sessions = handle:read("*a")
  handle:close()
  
  if sessions == "" then
    io.stderr:write("No tmux server found on " .. label .. "\n")
    return false
  end
  
  if query ~= "" then
    local filtered = {}
    for line in sessions:gmatch("[^\r\n]+") do
      if line:lower():find(query:lower(), 1, true) then
        table.insert(filtered, line)
      end
    end
    sessions = table.concat(filtered, "\n")
  end
  
  if sessions == "" then
    print("No sessions found on " .. label)
    return true
  end
  
  print("Sessions on " .. label .. ":")
  for line in sessions:gmatch("[^\r\n]+") do
    local name, attached, created = line:match("([^\t]*)\t([^\t]*)\t(.*)")
    local attached_label = (attached == "1") and "attached" or "detached"
    print(string.format("  - %s (%s, started %s)", name, attached_label, created))
  end
  return true
end

if scan_all then
  local stat = require("posix.sys.stat")
  local dirent = require("posix.dirent")
  
  if not stat.stat(socket_dir) or not stat.stat(socket_dir, "type") == "directory" then
    io.stderr:write("Socket directory not found: " .. socket_dir .. "\n")
    os.exit(1)
  end
  
  local sockets = {}
  for entry in dirent.files(socket_dir) do
    if entry ~= "." and entry ~= ".." then
      table.insert(sockets, socket_dir .. "/" .. entry)
    end
  end
  
  if #sockets == 0 then
    io.stderr:write("No sockets found under " .. socket_dir .. "\n")
    os.exit(1)
  end
  
  local exit_code = 0
  for _, sock in ipairs(sockets) do
    local stat_info = stat.stat(sock)
    if stat_info and stat.S_ISSOCK(stat_info.st_mode) then
      if not list_sessions("socket path '" .. sock .. "'", {"-S", sock}) then
        exit_code = 1
      end
    end
  end
  os.exit(exit_code)
end

local tmux_args = {}
local socket_label = "default socket"

if socket_name ~= "" then
  table.insert(tmux_args, "-L")
  table.insert(tmux_args, socket_name)
  socket_label = "socket name '" .. socket_name .. "'"
elseif socket_path ~= "" then
  table.insert(tmux_args, "-S")
  table.insert(tmux_args, socket_path)
  socket_label = "socket path '" .. socket_path .. "'"
end

list_sessions(socket_label, tmux_args)
