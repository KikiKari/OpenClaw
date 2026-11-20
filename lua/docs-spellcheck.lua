#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "fe9556671aae97fa1f121dc466e4ac9011fb7e032f459b58aa435687a7fc2475", "source_sha256": "d563770ee41496760efbfdbb5c3e2c054ecf84de1c5e8eb2fc7cd2ad260b16ce", "target_language": "lua"}
-- docs-spellcheck.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docs-spellcheck.sh
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local mode = arg[1] or ""
local write_flag = {}
if mode == "--write" then
  write_flag = {"-w"}
end

local args = {
  "README.md",
  "docs",
  "--skip=*.png,*.jpg,*.jpeg,*.gif,*.svg",
  "-D",
  "-",
  "-D",
  "scripts/codespell-dictionary.txt",
  "-I",
  "scripts/codespell-ignore.txt"
}

-- Add write flag if needed
for _, v in ipairs(write_flag) do
  table.insert(args, v)
end

-- Function to check if a command exists
local function command_exists(cmd)
  local handle = io.popen("command -v " .. cmd .. " 2>/dev/null", "r")
  local result = handle:read("*a")
  handle:close()
  return result ~= ""
end

-- Function to execute command and capture output
local function execute_command(cmd)
  local handle = io.popen(cmd, "r")
  local result = handle:read("*a")
  local success, _, code = handle:close()
  return success, code or 0
end

-- Try to run codespell directly
if command_exists("codespell") then
  local cmd = "codespell"
  for _, v in ipairs(args) do
    cmd = cmd .. " " .. (v:gsub(" ", "\\ "))
  end
  local success, exit_code = execute_command(cmd)
  os.exit(success and 0 or exit_code)
end

-- Try to use python3 to install and run codespell
if command_exists("python3") then
  -- Try to install codespell with --break-system-packages first
  local install_cmd1 = "python3 -m pip install --user --disable-pip-version-check --break-system-packages codespell >/dev/null 2>&1"
  local install_cmd2 = "python3 -m pip install --user --disable-pip-version-check codespell >/dev/null 2>&1"
  
  local success1 = os.execute(install_cmd1)
  if not success1 then
    os.execute(install_cmd2)
  end
  
  -- Get user bin path using Python
  local python_script = [[
import site
print(f"{site.USER_BASE}/bin")
]]
  
  local tmpfile = os.tmpname()
  local f = io.open(tmpfile, "w")
  f:write(python_script)
  f:close()
  
  local handle = io.popen("python3 " .. tmpfile, "r")
  local user_bin = handle:read("*l")
  handle:close()
  os.remove(tmpfile)
  
  if user_bin and #user_bin > 0 then
    local codespell_path = user_bin .. "/codespell"
    local file = io.open(codespell_path, "r")
    if file then
      file:close()
      local cmd = codespell_path
      for _, v in ipairs(args) do
        cmd = cmd .. " " .. (v:gsub(" ", "\\ "))
      end
      local success, exit_code = execute_command(cmd)
      os.exit(success and 0 or exit_code)
    end
  end
end

io.stderr:write("codespell unavailable: install codespell or python3\n")
os.exit(1)
