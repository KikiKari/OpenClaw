#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "0c6523b9d1fd9e0a8c627a4e05983938a6c985b59610bd474a8aebe52b61915c", "source_sha256": "4c4552ce0adb2754080969f00b761c1c118766771e0595b8c9b416ee0842fbae", "target_language": "lua"}
-- find-sessions.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/tmux/scripts/find-sessions.sh
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local function usage()
  print([[
Usage: find-sessions.sh [-L socket-name|-S socket-path|-A] [-q pattern]

List tmux sessions on a socket (default tmux socket if none provided).

Options:
  -L, --socket       tmux socket name (passed to tmux -L)
  -S, --socket-path  tmux socket path (passed to tmux -S)
  -A, --all          scan all sockets under OPENCLAW_TMUX_SOCKET_DIR
  -q, --query        case-insensitive substring to filter session names
  -h, --help         show this help
]])
end

local socket_name = ""
local socket_path = ""
local query = ""
local scan_all = false
local socket_dir = os.getenv("OPENCLAW_TMUX_SOCKET_DIR") or (os.getenv("TMPDIR") or "/tmp") .. "/openclaw-tmux-sockets"

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
  local handle = io.popen("command -v tmux >/dev/null 2>&1; echo $?", "r")
  local result = handle:read("*a")
  handle:close()
  return tonumber(result) == 0
end

if not has_tmux() then
  io.stderr:write("tmux not found in PATH\n")
  os.exit(1)
end

local function list_sessions(label, tmux_args)
  local cmd = "tmux " .. table.concat(tmux_args, " ") .. " list-sessions -F '#{session_name}\\t#{session_attached}\\t#{session_created_string}' 2>/dev/null"
  local handle = io.popen(cmd, "r")
  local sessions = handle:read("*a")
  local success, _, _ = handle:close()
  
  if not success then
    io.stderr:write("No tmux server found on " .. label .. "\n")
    return false
  end
  
  if query ~= "" then
    local filtered_lines = {}
    for line in sessions:gmatch("[^\r\n]+") do
      if string.find(line:lower(), query:lower()) then
        table.insert(filtered_lines, line)
      end
    end
    sessions = table.concat(filtered_lines, "\n")
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
  local stat = require("lfs").attributes(socket_dir, "mode")
  if not stat or stat ~= "directory" then
    io.stderr:write("Socket directory not found: " .. socket_dir .. "\n")
    os.exit(1)
  end
  
  local sockets = {}
  for file in require("lfs").dir(socket_dir) do
    if file ~= "." and file ~= ".." then
      table.insert(sockets, socket_dir .. "/" .. file)
    end
  end
  
  if #sockets == 0 then
    io.stderr:write("No sockets found under " .. socket_dir .. "\n")
    os.exit(1)
  end
  
  local exit_code = 0
  for _, sock in ipairs(sockets) do
    local attr = require("lfs").attributes(sock, "mode")
    if attr and attr == "socket" then
      local success = list_sessions("socket path '" .. sock .. "'", {"-S", sock})
      if not success then
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
