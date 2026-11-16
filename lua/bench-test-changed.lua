#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "5bdd54492d76225d057b6b1ecc1dd37fff2364c6a5cfb7d203710ab7523565ef", "source_sha256": "671775b966561d4c6120ff043a4bb70e355d548215a9adf110f38e78918fc1e2", "target_language": "lua"}
-- bench-test-changed.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bench-test-changed.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local uv = require("uv")
local path = require("path")

-- Helper functions to mimic JavaScript behavior
local function resolve_cwd(cwd)
  return path.resolve(cwd)
end

local function format_ms(ms)
  if ms < 1000 then
    return string.format("%.2fms", ms)
  elseif ms < 60000 then
    return string.format("%.2fs", ms / 1000)
  else
    return string.format("%.2fm", ms / 60000)
  end
end

local function format_rss(value_kb)
  if value_kb == nil then
    return "n/a"
  end
  return string.format("%.1fMB", value_kb / 1024)
end

local function parse_max_rss_kb(output)
  local match = string.match(output, "(%d+)%s+maximum resident set size")
  if match then
    return tonumber(match)
  end
  return nil
end

local function quote_arg(arg)
  if string.match(arg, "[^A-Za-z0-9_./:-]") then
    return string.format("%q", arg)
  end
  return arg
end

local function spawn_sync(command, args, options)
  local stdout_data = ""
  local stderr_data = ""
  local exit_code = 0

  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  local handle, pid_or_err = uv.spawn(command, {
    args = args,
    stdio = {stdin, stdout, stderr},
    cwd = options.cwd,
    env = options.env or uv.os_environ()
  }, function(code, signal)
    exit_code = code or signal
  end)

  if not handle then
    return {
      status = 1,
      stdout = "",
      stderr = tostring(pid_or_err),
      output = tostring(pid_or_err)
    }
  end

  stdout:read_start(function(err, data)
    if err then
      print("stdout read error:", err)
    elseif data then
      stdout_data = stdout_data .. data
    end
  end)

  stderr:read_start(function(err, data)
    if err then
      print("stderr read error:", err)
    elseif data then
      stderr_data = stderr_data .. data
    end
  end)

  stdin:close()
  uv.run()

  return {
    status = exit_code,
    stdout = stdout_data,
    stderr = stderr_data,
    output = stdout_data .. stderr_data
  }
end

local function run_git_list(args, cwd)
  local result = spawn_sync("git", args, {cwd = cwd})
  if result.status ~= 0 then
    error(result.stderr ~= "" and result.stderr or result.stdout ~= "" and result.stdout or "git " .. table.concat(args, " ") .. " failed")
  end
  
  local lines = {}
  for line in string.gmatch(result.stdout, "[^\n]+") do
    local trimmed = string.match(line, "^%s*(.-)%s*$")
    if #trimmed > 0 then
      table.insert(lines, trimmed)
    end
  end
  
  table.sort(lines)
  return lines
end

local function list_changed_paths(opts)
  if opts.mode == "worktree" then
    local diff_files = run_git_list({"diff", "--name-only", "--relative", "HEAD", "--"}, opts.cwd)
    local untracked_files = run_git_list({"ls-files", "--others", "--exclude-standard"}, opts.cwd)
    
    local all_files = {}
    local file_set = {}
    
    for _, file in ipairs(diff_files) do
      if not file_set[file] then
        file_set[file] = true
        table.insert(all_files, file)
      end
    end
    
    for _, file in ipairs(untracked_files) do
      if not file_set[file] then
        file_set[file] = true
        table.insert(all_files, file)
      end
    end
    
    table.sort(all_files)
    return all_files
  end
  
  return run_git_list({"diff", "--name-only", opts.ref .. "...HEAD"}, opts.cwd)
end

local function run_bench_command(params)
  local env = {}
  for k, v in pairs(uv.os_environ()) do
    env[k] = v
  end
  
  if type(params.max_workers) == "number" then
    env.OPENCLAW_VITEST_MAX_WORKERS = tostring(params.max_workers)
  end
  
  local start_time = uv.hrtime()
  local command_args
  
  if params.rss then
    command_args = {"/usr/bin/time", "-l"}
    for _, arg in ipairs(params.command) do
      table.insert(command_args, arg)
    end
  else
    command_args = {}
    for i = 2, #params.command do
      table.insert(command_args, params.command[i])
    end
  end
  
  local command = params.rss and "/usr/bin/time" or params.command[1]
  
  local result = spawn_sync(command, command_args, {
    cwd = params.cwd,
    env = env
  })
  
  local elapsed_ms = (uv.hrtime() - start_time) / 1000000
  
  return {
    elapsed_ms = elapsed_ms,
    max_rss_kb = params.rss and parse_max_rss_kb(result.output) or nil,
    status = result.status,
    output = result.output
  }
end

local function print_run_summary(label, result)
  local wall_time = format_ms(result.elapsed_ms)
  local rss = format_rss(result.max_rss_kb)
  print(string.format("%-8s wall=%9s rss=%9s", label, wall_time, rss))
end

-- Parse arguments
local function parse_args(argv)
  local args = {
    cwd = uv.cwd(),
    ref = "origin/main",
    rss = uv.os_uname().sysname == "Darwin",
    mode = "ref",
    max_workers = nil
  }
  
  local i = 1
  while i <= #argv do
    local arg = argv[i]
    if arg == "--cwd" and i + 1 <= #argv then
      args.cwd = argv[i + 1]
      i = i + 2
    elseif arg == "--ref" and i + 1 <= #argv then
      args.ref = argv[i + 1]
      i = i + 2
    elseif arg == "--max-workers" and i + 1 <= #argv then
      args.max_workers = math.floor(tonumber(argv[i + 1]))
      i = i + 2
    elseif arg == "--no-rss" then
      args.rss = false
      i = i + 1
    elseif arg == "--worktree" then
      args.mode = "worktree"
      i = i + 1
    else
      i = i + 1
    end
  end
  
  args.cwd = resolve_cwd(args.cwd)
  return args
end

-- Main execution
local opts = parse_args(arg)

local changed_paths = list_changed_paths(opts)
if #changed_paths == 0 then
  if opts.mode == "worktree" then
    print("[bench-test-changed] no changed paths in worktree")
  else
    print("[bench-test-changed] no changed paths for " .. opts.ref .. "...HEAD")
  end
  os.exit(0)
end

if opts.mode == "worktree" then
  print("[bench-test-changed] mode=worktree")
else
  print("[bench-test-changed] ref=" .. opts.ref)
end

print("[bench-test-changed] changed paths:")
for _, changed_path in ipairs(changed_paths) do
  print("- " .. changed_path)
end

local routed_command
if opts.mode == "worktree" then
  routed_command = {"lua", "scripts/test-projects.mjs"}
  for _, path in ipairs(changed_paths) do
    table.insert(routed_command, path)
  end
else
  routed_command = {"lua", "scripts/test-projects.mjs", "--changed", opts.ref}
end

local root_command = {"lua", "scripts/run-vitest.mjs", "run", "--config", "vitest.config.ts"}
for _, path in ipairs(changed_paths) do
  table.insert(root_command, path)
end

-- Print commands
local routed_cmd_str = ""
for _, cmd_part in ipairs(routed_command) do
  routed_cmd_str = routed_cmd_str .. " " .. quote_arg(cmd_part)
end
print("[bench-test-changed] routed:" .. routed_cmd_str)

local root_cmd_str = ""
for _, cmd_part in ipairs(root_command) do
  root_cmd_str = root_cmd_str .. " " .. quote_arg(cmd_part)
end
print("[bench-test-changed] root:  " .. root_cmd_str)

-- Run routed command
local routed_params = {
  command = routed_command,
  cwd = opts.cwd,
  rss = opts.rss
}
if type(opts.max_workers) == "number" then
  routed_params.max_workers = opts.max_workers
end

local routed = run_bench_command(routed_params)

if routed.status ~= 0 then
  io.stderr:write(routed.output)
  os.exit(routed.status)
end

-- Run root command
local root_params = {
  command = root_command,
  cwd = opts.cwd,
  rss = opts.rss
}
if type(opts.max_workers) == "number" then
  root_params.max_workers = opts.max_workers
end

local root = run_bench_command(root_params)

if root.status ~= 0 then
  io.stderr:write(root.output)
  os.exit(root.status)
end

print_run_summary("routed", routed)
print_run_summary("root", root)

-- Calculate delta
local delta_wall = root.elapsed_ms - routed.elapsed_ms
local delta_rss = "n/a"
if routed.max_rss_kb ~= nil and root.max_rss_kb ~= nil then
  delta_rss = format_rss(root.max_rss_kb - routed.max_rss_kb)
end

print("[bench-test-changed] delta wall=" .. format_ms(delta_wall) .. " rss=" .. delta_rss)
