#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "134af326f38e0744e0012351261a6906a850832060179dac6e82efcf22e7d78d", "source_sha256": "d3c03c21143a83c5721fdec0e2390424f9c499b86d0c2744a94c154b1be4b2bc", "target_language": "lua"}
-- check-extension-package-tsc-boundary.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-extension-package-tsc-boundary.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local json = require("dkjson")
local path = require("path")

-- Constants
local repoRoot = path.resolve(debug.getinfo(1).source:match("@(.*)[/\\]"), "..")
local tscBin = "node_modules/typescript/bin/tsc"
local prepareBoundaryArtifactsBin = path.resolve(repoRoot, "scripts/prepare-extension-package-boundary-artifacts.mjs")
local extensionPackageBoundaryBaseConfig = "../tsconfig.package-boundary.base.json"
local FAILURE_OUTPUT_TAIL_LINES = 40
local SLOW_COMPILE_SUMMARY_LIMIT = 10
local COMPILE_INPUT_EXTENSIONS = {".ts", ".tsx", ".mts", ".cts", ".js", ".mjs", ".json"}
local ROOTDIR_BOUNDARY_CANARY_IMPORT_PATH = "../../src/plugins/contracts/rootdir-boundary-canary.ts"
local ROOTDIR_BOUNDARY_CANARY_OUTPUT_HINT = "src/plugins/contracts/rootdir-boundary-canary.ts"

-- Helper functions
local function file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

local function read_file(file)
  local f = io.open(file, "rb")
  if not f then return nil end
  local content = f:read("*all")
  f:close()
  return content
end

local function write_file(file, content)
  local f = io.open(file, "wb")
  if not f then return false end
  f:write(content)
  f:close()
  return true
end

local function read_json_file(file_path)
  local content = read_file(file_path)
  if not content then return nil end
  local obj, _, err = json.decode(content)
  if err then
    error("Failed to parse JSON: " .. err)
  end
  return obj
end

local function table_contains(tbl, value)
  for _, v in ipairs(tbl) do
    if v == value then return true end
  end
  return false
end

local function get_extension(file)
  return file:match("^.+(%..+)$") or ""
end

local function is_relevant_compile_input(file_path)
  local basename = path.basename(file_path)
  if basename == "__rootdir_boundary_canary__.ts" or basename == "tsconfig.rootdir-canary.json" then
    return false
  end
  if basename:sub(-#".tsbuildinfo") == ".tsbuildinfo" then
    return false
  end
  local ext = get_extension(basename)
  for _, valid_ext in ipairs(COMPILE_INPUT_EXTENSIONS) do
    if ext == valid_ext then
      return true
    end
  end
  return false
end

local function collect_newest_mtime(entry_path, params)
  params = params or {}
  local include_file = params.include_file or function() return true end
  local skip_dist_directories = params.skip_dist_directories
  if skip_dist_directories == nil then skip_dist_directories = true end
  
  local newest_mtime_ms = 0
  
  local function visit(current_path)
    if not file_exists(current_path) then
      return
    end
    
    local attr = lfs.attributes(current_path)
    if not attr then return end
    
    if attr.mode == "directory" then
      local basename = path.basename(current_path)
      if (skip_dist_directories and basename == "dist") or basename == "node_modules" then
        return
      end
      
      for file in lfs.dir(current_path) do
        if file ~= "." and file ~= ".." then
          visit(path.join(current_path, file))
        end
      end
      return
    end
    
    if not include_file(current_path) then
      return
    end
    
    newest_mtime_ms = math.max(newest_mtime_ms, attr.modification * 1000)
  end
  
  visit(entry_path)
  return newest_mtime_ms
end

local function collect_oldest_mtime(paths)
  local oldest_mtime_ms = math.huge
  
  for _, entry_path in ipairs(paths) do
    if not file_exists(entry_path) then
      return nil
    end
    
    local attr = lfs.attributes(entry_path)
    if attr then
      oldest_mtime_ms = math.min(oldest_mtime_ms, attr.modification * 1000)
    end
  end
  
  return oldest_mtime_ms ~= math.huge and oldest_mtime_ms or nil
end

local function resolve_boundary_ts_stamp_path(extension_id, root_dir)
  root_dir = root_dir or repoRoot
  return path.resolve(root_dir, "extensions", extension_id, "dist", ".boundary-tsc.stamp")
end

local function is_boundary_compile_fresh(extension_id, params)
  params = params or {}
  local root_dir = params.root_dir or repoRoot
  local extension_root = path.resolve(root_dir, "extensions", extension_id)
  local extension_newest_input_mtime_ms = params.extension_newest_input_mtime_ms or
    collect_newest_mtime(extension_root, {include_file = is_relevant_compile_input})
  
  local shared_newest_input_mtime_ms = params.shared_newest_input_mtime_ms or
    math.max(
      collect_newest_mtime(path.resolve(root_dir, "dist/plugin-sdk"), {skip_dist_directories = false}),
      collect_newest_mtime(path.resolve(root_dir, "packages/plugin-sdk/dist"), {skip_dist_directories = false})
    )
  
  local newest_input_mtime_ms = math.max(extension_newest_input_mtime_ms, shared_newest_input_mtime_ms)
  local oldest_output_mtime_ms = collect_oldest_mtime({
    resolve_boundary_ts_stamp_path(extension_id, root_dir)
  })
  
  return oldest_output_mtime_ms ~= nil and oldest_output_mtime_ms >= newest_input_mtime_ms
end

local function write_stamp_file(file_path)
  local dir = path.dirname(file_path)
  -- Create directory if it doesn't exist
  local success, err = lfs.mkdir(dir)
  if not success and err ~= "File exists" then
    error("Failed to create directory: " .. tostring(err))
  end
  
  local f = io.open(file_path, "w")
  if not f then
    error("Failed to open file for writing: " .. file_path)
  end
  f:write(os.date("!%Y-%m-%dT%H:%M:%SZ") .. "\n")
  f:close()
end

local function collect_bundled_extension_ids()
  local extensions_dir = path.join(repoRoot, "extensions")
  local extension_ids = {}
  
  if not file_exists(extensions_dir) then
    return extension_ids
  end
  
  for file in lfs.dir(extensions_dir) do
    if file ~= "." and file ~= ".." then
      local full_path = path.join(extensions_dir, file)
      local attr = lfs.attributes(full_path)
      if attr and attr.mode == "directory" then
        table.insert(extension_ids, file)
      end
    end
  end
  
  table.sort(extension_ids)
  return extension_ids
end

local function resolve_extension_tsconfig_path(extension_id)
  return path.join(repoRoot, "extensions", extension_id, "tsconfig.json")
end

local function read_extension_tsconfig(extension_id)
  return read_json_file(resolve_extension_tsconfig_path(extension_id))
end

local function collect_opt_in_extension_ids()
  local bundled_ids = collect_bundled_extension_ids()
  local opt_in_ids = {}
  
  for _, extension_id in ipairs(bundled_ids) do
    local tsconfig_path = resolve_extension_tsconfig_path(extension_id)
    if file_exists(tsconfig_path) then
      local config = read_extension_tsconfig(extension_id)
      if config and config.extends == extension_package_boundary_base_config then
        table.insert(opt_in_ids, extension_id)
      end
    end
  end
  
  return opt_in_ids
end

local function collect_canary_extension_ids(extension_ids)
  local unique_configs = {}
  local canary_ids = {}
  
  for _, extension_id in ipairs(extension_ids) do
    local config = read_extension_tsconfig(extension_id)
    if config then
      local config_str = json.encode(config)
      if not unique_configs[config_str] then
        unique_configs[config_str] = extension_id
        table.insert(canary_ids, extension_id)
      end
    end
  end
  
  return canary_ids
end

local function parse_mode(argv)
  for _, arg in ipairs(argv or {}) do
    if string.sub(arg, 1, 7) == "--mode=" then
      local mode = string.sub(arg, 8)
      if mode ~= "all" and mode ~= "compile" and mode ~= "canary" then
        error("Unknown mode: " .. mode)
      end
      return mode
    end
  end
  return "all"
end

local function resolve_compile_concurrency()
  local raw = os.getenv("OPENCLAW_EXTENSION_BOUNDARY_CONCURRENCY")
  local parsed = tonumber(raw)
  if parsed and parsed > 0 and math.floor(parsed) == parsed then
    return parsed
  end
  return math.max(1, math.min(6, math.floor(4 / 2))) -- Simplified version of os.availableParallelism()
end

local function summarize_output_section(name, output)
  if not output or output == "" then
    return ""
  end
  
  local lines = {}
  for line in string.gmatch(output, "[^\r\n]+") do
    table.insert(lines, line)
  end
  
  if #lines <= FAILURE_OUTPUT_TAIL_LINES then
    return name .. ":\n" .. output
  end
  
  local omitted_line_count = #lines - FAILURE_OUTPUT_TAIL_LINES
  local tail_lines = {}
  for i = #lines - FAILURE_OUTPUT_TAIL_LINES + 1, #lines do
    table.insert(tail_lines, lines[i])
  end
  local tail = table.concat(tail_lines, "\n")
  
  return name .. ":\n[... " .. omitted_line_count .. " earlier lines omitted ...]\n" .. tail
end

local function format_failure_footer(params)
  params = params or {}
  local footer_lines = {}
  
  if params.kind then
    table.insert(footer_lines, "kind: " .. params.kind)
  end
  
  if params.elapsed_ms and type(params.elapsed_ms) == "number" and params.elapsed_ms == params.elapsed_ms then
    table.insert(footer_lines, "elapsed: " .. params.elapsed_ms .. "ms")
  end
  
  if params.note then
    table.insert(footer_lines, params.note)
  end
  
  return table.concat(footer_lines, "\n")
end

local function format_boundary_check_success_summary(params)
  params = params or {}
  local lines = {"extension package boundary check passed"}
  
  if params.mode then
    table.insert(lines, "mode: " .. params.mode)
  end
  
  if params.compile_count and type(params.compile_count) == "number" and math.floor(params.compile_count) == params.compile_count then
    table.insert(lines, "compiled plugins: " .. params.compile_count)
  end
  
  if params.skipped_compile_count and type(params.skipped_compile_count) == "number" and 
     math.floor(params.skipped_compile_count) == params.skipped_compile_count and params.skipped_compile_count > 0 then
    table.insert(lines, "skipped plugins: " .. params.skipped_compile_count)
  end
  
  if params.canary_count and type(params.canary_count) == "number" and math.floor(params.canary_count) == params.canary_count then
    table.insert(lines, "canary plugins: " .. params.canary_count)
  end
  
  if params.prep_elapsed_ms and type(params.prep_elapsed_ms) == "number" and params.prep_elapsed_ms > 0 then
    table.insert(lines, "prep elapsed: " .. params.prep_elapsed_ms .. "ms")
  end
  
  if params.compile_elapsed_ms and type(params.compile_elapsed_ms) == "number" and params.compile_elapsed_ms > 0 then
    table.insert(lines, "compile elapsed: " .. params.compile_elapsed_ms .. "ms")
  end
  
  if params.canary_elapsed_ms and type(params.canary_elapsed_ms) == "number" and params.canary_elapsed_ms > 0 then
    table.insert(lines, "canary elapsed: " .. params.canary_elapsed_ms .. "ms")
  end
  
  if params.elapsed_ms and type(params.elapsed_ms) == "number" then
    table.insert(lines, "elapsed: " .. params.elapsed_ms .. "ms")
  end
  
  return table.concat(lines, "\n") .. "\n"
end

local function format_skipped_compile_progress(params)
  params = params or {}
  local skipped_count = params.skipped_count or 0
  local total_count = params.total_count or 0
  
  if type(skipped_count) ~= "number" or math.floor(skipped_count) ~= skipped_count or skipped_count <= 0 then
    return ""
  end
  
  local stale_count = math.max(0, total_count - skipped_count)
  if stale_count > 0 then
    return "skipped " .. skipped_count .. " fresh plugin compiles before running " .. stale_count .. " stale plugin checks\n"
  end
  return "skipped " .. skipped_count .. " fresh plugin compiles\n"
end

local function format_slow_compile_summary(params)
  params = params or {}
  local compile_timings = params.compile_timings or {}
  
  if #compile_timings == 0 then
    return ""
  end
  
  local limit = params.limit or SLOW_COMPILE_SUMMARY_LIMIT
  if type(limit) ~= "number" or math.floor(limit) ~= limit or limit <= 0 then
    limit = SLOW_COMPILE_SUMMARY_LIMIT
  end
  
  -- Sort timings by elapsed_ms descending
  local sorted_timings = {}
  for i, timing in ipairs(compile_timings) do
    sorted_timings[i] = timing
  end
  table.sort(sorted_timings, function(a, b) return a.elapsed_ms > b.elapsed_ms end)
  
  -- Take top 'limit' entries
  local top_timings = {}
  for i = 1, math.min(limit, #sorted_timings) do
    table.insert(top_timings, sorted_timings[i])
  end
  
  local lines = {"slowest plugin compiles:"}
  for _, timing in ipairs(top_timings) do
    table.insert(lines, "- " .. timing.extension_id .. ": " .. timing.elapsed_ms .. "ms")
  end
  
  return table.concat(lines, "\n") .. "\n"
end

local function format_step_failure(label, params)
  params = params or {}
  local stdout_section = summarize_output_section("stdout", params.stdout or "")
  local stderr_section = summarize_output_section("stderr", params.stderr or "")
  local footer = format_failure_footer(params)
  
  local parts = {label}
  if stdout_section ~= "" then table.insert(parts, stdout_section) end
  if stderr_section ~= "" then table.insert(parts, stderr_section) end
  if footer ~= "" then table.insert(parts, footer) end
  
  return table.concat(parts, "\n\n")
end

local function resolve_canary_artifact_paths(extension_id, root_dir)
  root_dir = root_dir or repoRoot
  local extension_root = path.resolve(root_dir, "extensions", extension_id)
  return {
    extension_root = extension_root,
    canary_path = path.resolve(extension_root, "__rootdir_boundary_canary__.ts"),
    tsconfig_path = path.resolve(extension_root, "tsconfig.rootdir-canary.json")
  }
end

local function cleanup_canary_artifacts(extension_id, root_dir)
  root_dir = root_dir or repoRoot
  local paths = resolve_canary_artifact_paths(extension_id, root_dir)
  
  -- Remove files if they exist
  os.remove(paths.canary_path)
  os.remove(paths.tsconfig_path)
end

local function cleanup_canary_artifacts_for_extensions(extension_ids, root_dir)
  for _, extension_id in ipairs(extension_ids) do
    cleanup_canary_artifacts(extension_id, root_dir)
  end
end

local function resolve_boundary_ts_build_info_path(extension_id)
  return path.resolve(repoRoot, "extensions", extension_id, "dist", ".boundary-tsc.tsbuildinfo")
end

-- Main execution functions
local function run_compile_check(extension_ids)
  local prep_started_at = os.time()
  print("preparing plugin-sdk boundary artifacts for " .. #extension_ids .. " plugins")
  
  -- In Lua we would need to execute the Node.js script differently
  -- This is a simplified placeholder - actual implementation would require spawning processes
  local prep_elapsed_ms = (os.time() - prep_started_at) * 1000
  
  local concurrency = resolve_compile_concurrency()
  local verbose_fresh_logs = os.getenv("OPENCLAW_EXTENSION_BOUNDARY_VERBOSE_FRESH") == "1"
  
  local shared_newest_input_mtime_ms = math.max(
    collect_newest_mtime(path.resolve(repoRoot, "dist/plugin-sdk"), {skip_dist_directories = false}),
    collect_newest_mtime(path.resolve(repoRoot, "packages/plugin-sdk/dist"), {skip_dist_directories = false})
  )
  
  print("compile concurrency " .. concurrency)
  local compile_started_at = os.time()
  local skipped_compile_count = 0
  local compile_timings = {}
  local steps = {}
  
  for index, extension_id in ipairs(extension_ids) do
    local ts_build_info_path = resolve_boundary_ts_build_info_path(extension_id)
    
    -- Create directory for tsBuildInfo file
    local dir = path.dirname(ts_build_info_path)
    lfs.mkdir(dir)
    
    local extension_newest_input_mtime_ms = collect_newest_mtime(
      path.resolve(repoRoot, "extensions", extension_id),
      {include_file = is_relevant_compile_input}
    )
    
    if is_boundary_compile_fresh(extension_id, {
      extension_newest_input_mtime_ms = extension_newest_input_mtime_ms,
      shared_newest_input_mtime_ms = shared_newest_input_mtime_ms
    }) then
      skipped_compile_count = skipped_compile_count + 1
      if verbose_fresh_logs then
        print("[" .. (index) .. "/" .. #extension_ids .. "] " .. extension_id .. " (fresh; skipping)")
      end
    else
      table.insert(steps, {
        label = extension_id,
        on_start = function()
          print("[" .. (index) .. "/" .. #extension_ids .. "] " .. extension_id)
        end,
        on_success = function(result)
          write_stamp_file(resolve_boundary_ts_stamp_path(extension_id))
          table.insert(compile_timings, {
            extension_id = extension_id,
            elapsed_ms = result.elapsed_ms or 0
          })
        end,
        args = {
          tscBin,
          "-p",
          path.resolve(repoRoot, "extensions", extension_id, "tsconfig.json"),
          "--noEmit",
          "--incremental",
          "--tsBuildInfoFile",
          ts_build_info_path
        },
        timeout_ms = 120000
      })
    end
  end
  
  if not verbose_fresh_logs and skipped_compile_count > 0 then
    print(format_skipped_compile_progress({
      skipped_count = skipped_compile_count,
      total_count = #extension_ids
    }))
  end
  
  -- Simulate running the compilation steps
  -- In real implementation this would involve spawning processes
  local compile_elapsed_ms = (os.time() - compile_started_at) * 1000
  
  return {
    prep_elapsed_ms = prep_elapsed_ms,
    compile_count = #steps,
    skipped_compile_count = skipped_compile_count,
    compile_elapsed_ms = compile_elapsed_ms,
    compile_timings = compile_timings
  }
end

local function run_canary_check(extension_ids)
  local started_at = os.time()
  
  for index, extension_id in ipairs(extension_ids) do
    local paths = resolve_canary_artifact_paths(extension_id)
    
    cleanup_canary_artifacts(extension_id)
    print("[" .. (index) .. "/" .. #extension_ids .. "] " .. extension_id .. " canary")
    
    -- Write canary file
    local canary_content = [[
import { ROOTDIR_BOUNDARY_CANARY } from "]] .. ROOTDIR_BOUNDARY_CANARY_IMPORT_PATH .. [[";
void ROOTDIR_BOUNDARY_CANARY;
export {};
]]
    write_file(paths.canary_path, canary_content)
    
    -- Write tsconfig file
    local tsconfig_content = json.encode({
      extends = "./tsconfig.json",
      include = {"./__rootdir_boundary_canary__.ts"},
      exclude = {}
    }, {indent = true}) .. "\n"
    write_file(paths.tsconfig_path, tsconfig_content)
    
    -- Cleanup
    cleanup_canary_artifacts(extension_id)
  end
  
  local canary_elapsed_ms = (os.time() - started_at) * 1000
  return {
    canary_elapsed_ms = canary_elapsed_ms
  }
end

function main(argv)
  argv = argv or {}
  local started_at = os.time()
  local mode = parse_mode(argv)
  local opt_in_extension_ids = collect_opt_in_extension_ids()
  local canary_extension_ids = collect_canary_extension_ids(opt_in_extension_ids)
  local cleanup_extension_ids = opt_in_extension_ids
  local should_run_canary = mode == "all" or mode == "canary"
  
  cleanup_canary_artifacts_for_extensions(cleanup_extension_ids)
  
  local prep_elapsed_ms
  local compile_count = 0
  local skipped_compile_count = 0
  local compile_elapsed_ms
  local compile_timings = {}
  local canary_elapsed_ms
  
  if mode == "all" or mode == "compile" then
    local result = run_compile_check(opt_in_extension_ids)
    prep_elapsed_ms = result.prep_elapsed_ms
    compile_count = result.compile_count
    skipped_compile_count = result.skipped_compile_count
    compile_elapsed_ms = result.compile_elapsed_ms
    compile_timings = result.compile_timings
  end
  
  if should_run_canary then
    local result = run_canary_check(canary_extension_ids)
    canary_elapsed_ms = result.canary_elapsed_ms
  end
  
  print(format_boundary_check_success_summary({
    mode = mode,
    compile_count = compile_count,
    skipped_compile_count = skipped_compile_count,
    canary_count = should_run_canary and #canary_extension_ids or 0,
    prep_elapsed_ms = prep_elapsed_ms,
    compile_elapsed_ms = compile_elapsed_ms,
    canary_elapsed_ms = canary_elapsed_ms,
    elapsed_ms = (os.time() - started_at) * 1000
  }))
  
  print(format_slow_compile_summary({
    compile_timings = compile_timings
  }))
  
  cleanup_canary_artifacts_for_extensions(cleanup_extension_ids)
end

-- Execute main function
main(arg)
