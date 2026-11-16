#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "142d6acbb9df79830e01c717776bae6554f88032334f96cd149b2919cbbae22e", "source_sha256": "ea352b99923506af9c3ce8c6a36ed51f94a6d895a48b5e6aeebdb0322ed9e62d", "target_language": "lua"}
-- bundled-plugin-root-runtime-mirrors.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-root-runtime-mirrors.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local json = require("cjson")
local path = require("path")

-- Utility functions to mimic Node.js path behavior
local function path_join(...)
    local parts = {...}
    local result = ""
    for i, part in ipairs(parts) do
        if i == 1 then
            result = part
        else
            result = result .. "/" .. part
        end
    end
    return result
end

local function path_basename(p)
    local parts = {}
    for part in string.gmatch(p, "[^/]+") do
        table.insert(parts, part)
    end
    return parts[#parts]
end

local function path_dirname(p)
    local parts = {}
    for part in string.gmatch(p, "[^/]+") do
        table.insert(parts, part)
    end
    table.remove(parts)
    return table.concat(parts, "/")
end

local function path_relative(from, to)
    -- Simplified implementation assuming both paths are absolute and share a common prefix
    local from_parts = {}
    for part in string.gmatch(from, "[^/]+") do
        table.insert(from_parts, part)
    end
    
    local to_parts = {}
    for part in string.gmatch(to, "[^/]+") do
        table.insert(to_parts, part)
    end
    
    local common_length = 0
    for i = 1, math.min(#from_parts, #to_parts) do
        if from_parts[i] == to_parts[i] then
            common_length = i
        else
            break
        end
    end
    
    local up_dirs = #from_parts - common_length
    local down_parts = {}
    for i = common_length + 1, #to_parts do
        table.insert(down_parts, to_parts[i])
    end
    
    local result_parts = {}
    for i = 1, up_dirs do
        table.insert(result_parts, "..")
    end
    for _, part in ipairs(down_parts) do
        table.insert(result_parts, part)
    end
    
    return table.concat(result_parts, "/")
end

-- Constants
local JS_EXTENSIONS = {".cjs", ".js", ".mjs"}

-- Helper functions
local function read_json(file_path)
    local file = io.open(file_path, "r")
    if not file then
        error("Could not open file: " .. file_path)
    end
    local content = file:read("*a")
    file:close()
    return json.decode(content)
end

local function exists_sync(dir)
    local mode = lfs.attributes(dir, "mode")
    return mode == "directory"
end

local function is_file(file_path)
    local mode = lfs.attributes(file_path, "mode")
    return mode == "file"
end

local function collect_package_json_paths(root_dir)
    local paths = {}
    if not exists_sync(root_dir) then
        return paths
    end
    
    for entry in lfs.dir(root_dir) do
        if entry ~= "." and entry ~= ".." then
            local full_path = path_join(root_dir, entry)
            local mode = lfs.attributes(full_path, "mode")
            if mode == "directory" then
                local package_json_path = path_join(full_path, "package.json")
                if is_file(package_json_path) then
                    table.insert(paths, package_json_path)
                end
            end
        end
    end
    
    table.sort(paths)
    return paths
end

local function collect_runtime_dependency_specs(package_json)
    local deps = {}
    
    -- Merge dependencies and optionalDependencies
    local all_deps = {}
    if package_json.dependencies then
        for k, v in pairs(package_json.dependencies) do
            all_deps[k] = v
        end
    end
    if package_json.optionalDependencies then
        for k, v in pairs(package_json.optionalDependencies) do
            all_deps[k] = v
        end
    end
    
    -- Filter valid entries
    for name, spec in pairs(all_deps) do
        if type(spec) == "string" and #spec > 0 then
            deps[name] = spec
        end
    end
    
    return deps
end

local function package_name_from_specifier(specifier)
    if type(specifier) ~= "string" or 
       string.sub(specifier, 1, 1) == "." or 
       string.sub(specifier, 1, 1) == "/" or 
       string.sub(specifier, 1, 5) == "node:" or 
       string.sub(specifier, 1, 1) == "#" then
        return nil
    end
    
    local parts = {}
    for part in string.gmatch(specifier, "[^/]+") do
        table.insert(parts, part)
    end
    
    if #parts == 0 then
        return nil
    end
    
    if string.sub(parts[1], 1, 1) == "@" and #parts >= 2 then
        return parts[1] .. "/" .. parts[2]
    else
        return parts[1]
    end
end

local function walk_javascript_files(root_dir)
    local files = {}
    if not exists_sync(root_dir) then
        return files
    end
    
    local queue = {root_dir}
    while #queue > 0 do
        local current = table.remove(queue, 1)
        
        for entry in lfs.dir(current) do
            if entry ~= "." and entry ~= ".." then
                local full_path = path_join(current, entry)
                local mode = lfs.attributes(full_path, "mode")
                
                if mode == "directory" then
                    if not string.find(full_path, "/extensions/") then
                        table.insert(queue, full_path)
                    end
                elseif mode == "file" then
                    local ext = ""
                    local dot_pos = string.find(string.reverse(entry), "%.")
                    if dot_pos then
                        ext = string.sub(entry, -dot_pos)
                    end
                    
                    local found = false
                    for _, js_ext in ipairs(JS_EXTENSIONS) do
                        if ext == js_ext then
                            found = true
                            break
                        end
                    end
                    
                    if found then
                        table.insert(files, full_path)
                    end
                end
            end
        end
    end
    
    table.sort(files)
    return files
end

local function extract_module_specifiers(source)
    local specifiers = {}
    
    local patterns = {
        "from%s*[\"']([^\"']+)[\"']",
        "import%s*[\"']([^\"']+)[\"']",
        "import%s*%(%s*[\"']([^\"']+)[\"']%s*%)",
        "require%s*%(%s*[\"']([^\"']+)[\"']%s*%)"
    }
    
    for _, pattern in ipairs(patterns) do
        for match in string.gmatch(source, pattern) do
            specifiers[match] = true
        end
    end
    
    return specifiers
end

-- Exported functions
function collect_bundled_plugin_runtime_dependency_specs(bundled_plugins_dir)
    local specs = {}
    
    local package_json_paths = collect_package_json_paths(bundled_plugins_dir)
    for _, package_json_path in ipairs(package_json_paths) do
        local package_json = read_json(package_json_path)
        local plugin_id = path_basename(path_dirname(package_json_path))
        
        local deps = collect_runtime_dependency_specs(package_json)
        for name, spec in pairs(deps) do
            local existing = specs[name]
            if existing then
                if existing.spec ~= spec then
                    table.insert(existing.conflicts, {pluginId = plugin_id, spec = spec})
                elseif not (function(t, val)
                    for _, v in ipairs(t) do
                        if v == val then return true end
                    end
                    return false
                end)(existing.pluginIds, plugin_id) then
                    table.insert(existing.pluginIds, plugin_id)
                end
            else
                specs[name] = {
                    conflicts = {},
                    pluginIds = {plugin_id},
                    spec = spec
                }
            end
        end
    end
    
    return specs
end

function collect_root_dist_bundled_runtime_mirrors(params)
    local dist_dir = params.distDir
    local bundled_specs = params.bundledRuntimeDependencySpecs
    local mirrors = {}
    
    local files = walk_javascript_files(dist_dir)
    for _, file_path in ipairs(files) do
        local file = io.open(file_path, "r")
        if file then
            local source = file:read("*a")
            file:close()
            
            local relative_path = path_relative(dist_dir, file_path):gsub("\\", "/")
            local specifiers = extract_module_specifiers(source)
            
            for specifier, _ in pairs(specifiers) do
                local dependency_name = package_name_from_specifier(specifier)
                if dependency_name and bundled_specs[dependency_name] then
                    local bundled_spec = bundled_specs[dependency_name]
                    local existing = mirrors[dependency_name]
                    
                    if existing then
                        existing.importers[relative_path] = true
                    else
                        local importers_set = {[relative_path] = true}
                        mirrors[dependency_name] = {
                            importers = importers_set,
                            pluginIds = bundled_spec.pluginIds,
                            spec = bundled_spec.spec
                        }
                    end
                end
            end
        end
    end
    
    return mirrors
end

function collect_bundled_plugin_root_runtime_mirror_errors(params)
    local root_runtime_deps = collect_runtime_dependency_specs(params.rootPackageJson)
    local errors = {}
    
    -- Check for conflicts in bundled specs
    for dependency_name, record in pairs(params.bundledRuntimeDependencySpecs) do
        for _, conflict in ipairs(record.conflicts) do
            table.insert(errors, string.format(
                "bundled runtime dependency '%s' has conflicting plugin specs: %s use '%s', %s uses '%s'.",
                dependency_name,
                table.concat(record.pluginIds, ", "),
                record.spec,
                conflict.pluginId,
                conflict.spec
            ))
        end
    end
    
    -- Check required root mirrors
    for dependency_name, mirror in pairs(params.requiredRootMirrors) do
        local root_spec = root_runtime_deps[dependency_name]
        
        local importers_list = {}
        for importer, _ in pairs(mirror.importers) do
            table.insert(importers_list, importer)
        end
        table.sort(importers_list)
        local importer_label = table.concat(importers_list, ", ")
        
        local plugin_ids_sorted = {}
        for _, id in ipairs(mirror.pluginIds) do
            table.insert(plugin_ids_sorted, id)
        end
        table.sort(plugin_ids_sorted)
        local plugin_label = table.concat(plugin_ids_sorted, ", ")
        
        if type(root_spec) ~= "string" or #root_spec == 0 then
            table.insert(errors, string.format(
                "root dist imports bundled plugin runtime dependency '%s' from %s; mirror '%s: %s' in root package.json (declared by %s).",
                dependency_name,
                importer_label,
                dependency_name,
                mirror.spec,
                plugin_label
            ))
        elseif root_spec ~= mirror.spec then
            table.insert(errors, string.format(
                "root dist imports bundled plugin runtime dependency '%s' from %s; root package.json has '%s' but plugin manifest declares '%s' (%s).",
                dependency_name,
                importer_label,
                root_spec,
                mirror.spec,
                plugin_label
            ))
        end
    end
    
    return errors
end

return {
    collectRuntimeDependencySpecs = collect_runtime_dependency_specs,
    packageNameFromSpecifier = package_name_from_specifier,
    collectBundledPluginRuntimeDependencySpecs = collect_bundled_plugin_runtime_dependency_specs,
    collectRootDistBundledRuntimeMirrors = collect_root_dist_bundled_runtime_mirrors,
    collectBundledPluginRootRuntimeMirrorErrors = collect_bundled_plugin_root_runtime_mirror_errors
}
