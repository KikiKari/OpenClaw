#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "76a49e52f5ab159c851b7c5b2028d34b83955525c018a3e68992f7d6e088a2e6", "source_sha256": "292b977dd14f55e08a3852eccaf235d04d5f7e909ab6139a9ab2e379ae2305a1", "target_language": "lua"}
-- github_publisher.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

--[[Publish queued, provenance-checked artifacts without staging unrelated files.--]]
local json = require("cjson")
local openssl = require("openssl")
local ltn12 = require("ltn12")
local https = require("ssl.https")
local http = require("socket.http")
local url = require("socket.url")
local base64 = require("base64")

local LANGUAGES = {
    perl5 = true,
    powershell = true,
    perl6 = true,
    tcl = true,
    javascript = true,
    ruby = true,
    python = true,
    lua = true,
    shell = true,
    go = true
}

local function resolve_path(path)
    local resolved = path:gsub("/+", "/"):gsub("^~", os.getenv("HOME"))
    while resolved:match("/[^/]+/%.%./") do
        resolved = resolved:gsub("/[^/]+/%.%./", "/", 1)
    end
    resolved = resolved:gsub("/%.$", "/")
    return resolved
end

local function read_file(path)
    local file = io.open(path, "rb")
    if not file then
        error("Could not open file: " .. path)
    end
    local content = file:read("*a")
    file:close()
    return content
end

local function write_file(path, content)
    local file = io.open(path, "wb")
    if not file then
        error("Could not write file: " .. path)
    end
    file:write(content)
    file:close()
end

local function execute_command(cmd, timeout)
    local handle = io.popen(cmd .. " 2>/dev/null")
    local result = handle:read("*a")
    local success, _, code = handle:close()
    if not success then
        error("Command failed with exit code: " .. tostring(code))
    end
    return result
end

local function sha256_hex(data)
    local hash = openssl.digest.new("sha256")
    hash:update(data)
    return hash:final():toHex():lower()
end

local function git_clone(remote, branch, destination, timeout)
    local cmd = string.format(
        "git clone --quiet --depth=1 --single-branch --branch %s -- %s %s",
        branch, remote, destination
    )
    execute_command(cmd, timeout)
end

local function git_rev_parse(repo_path, ref)
    local cmd = string.format("git -C %s rev-parse %s", repo_path, ref)
    return execute_command(cmd, 30):gsub("%s+$", "")
end

local function mkdir_p(path)
    os.execute(string.format('mkdir -p "%s"', path))
end

local function file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

local function dir_list(path)
    local files = {}
    local handle = io.popen(string.format('find "%s" -maxdepth 1 -type f', path))
    for filename in handle:lines() do
        table.insert(files, filename)
    end
    handle:close()
    return files
end

local function basename(path)
    return path:match("[^/]*$")
end

local function dirname(path)
    return path:match("(.-)/[^/]*$")
end

local function splitext(filename)
    local name = filename:match("(.+)%.[^.]*$")
    local ext = filename:match("([^.]*)$")
    return name or filename, "." .. (ext or "")
end

local function synchronize_checkout(root, options)
    options = options or {}
    local remote = options.remote or "https://github.com/KikiKari/OpenClaw.git"
    local branch = options.branch or "gateway1-abstractions"
    
    root = resolve_path(root)
    if not file_exists(root) then
        error("Root directory does not exist: " .. root)
    end
    
    local tmp = os.tmpname()
    os.remove(tmp)
    local snapshot = tmp .. "/repo"
    
    git_clone(remote, branch, snapshot, 300)
    local revision = git_rev_parse(snapshot, "HEAD")
    
    local counts = {}
    
    local languages_sorted = {}
    for lang in pairs(LANGUAGES) do
        table.insert(languages_sorted, lang)
    end
    table.sort(languages_sorted)
    
    for _, language in ipairs(languages_sorted) do
        local source = snapshot .. "/" .. language
        local target = root .. "/" .. language
        
        if file_exists(source .. "/.") then
            if not file_exists(target .. "/.") then
                mkdir_p(target)
            end
            
            local known = {}
            if file_exists(target .. "/.") then
                for _, filepath in ipairs(dir_list(target)) do
                    local data = read_file(filepath)
                    known[sha256_hex(data)] = true
                end
            end
            
            local files = {}
            if file_exists(source .. "/.") then
                files = dir_list(source)
            end
            
            counts[language] = #files
            
            for _, item in ipairs(files) do
                local data = read_file(item)
                local digest = sha256_hex(data)
                
                if not known[digest] then
                    local destination = target .. "/" .. basename(item)
                    if file_exists(destination) then
                        local stem, suffix = splitext(basename(item))
                        destination = target .. "/" .. stem .. "__pool_" .. digest .. suffix
                    end
                    
                    local output = io.open(destination, "wb")
                    if output then
                        output:write(data)
                        output:close()
                        known[digest] = true
                    else
                        local existing_data = read_file(destination)
                        if existing_data ~= data then
                            error("Local abstraction conflict")
                        end
                    end
                end
            end
        else
            if not file_exists(target .. "/.") then
                mkdir_p(target)
            end
            counts[language] = 0
        end
    end
    
    os.execute("rm -rf " .. tmp)
    return revision, counts
end

local function update_status_counts(path, revision, counts)
    local text = read_file(path)
    
    local rows = {
        "## Bestand",
        "",
        string.format("GitHub-Stand: `%s`", revision),
        "",
        "| Zielsprache | Dateien |",
        "|---|---:|"
    }
    
    local languages_sorted = {}
    for lang in pairs(LANGUAGES) do
        table.insert(languages_sorted, lang)
    end
    table.sort(languages_sorted)
    
    for _, language in ipairs(languages_sorted) do
        table.insert(rows, string.format("| %s | %d |", language, counts[language]))
    end
    
    local total = 0
    for _, count in pairs(counts) do
        total = total + count
    end
    table.insert(rows, string.format("| **gesamt** | **%d** |", total))
    table.insert(rows, "")
    table.insert(rows, "")
    
    local rows_str = table.concat(rows, "\n")
    local updated = text:gsub("## Bestand\n.-## Quellen\n", rows_str .. "## Quellen\n", 1)
    
    write_file(path, updated)
end

local function queue_artifact(state, root, path)
    root = resolve_path(root)
    path = resolve_path(path)
    
    if not file_exists(path) then
        error("Artifact does not exist: " .. path)
    end
    
    local relative = path:sub(#root + 2)
    
    if relative ~= 'STATUS.md' then
        local parts = {}
        for part in relative:gmatch("[^/]+") do
            table.insert(parts, part)
        end
        if #parts == 0 or not LANGUAGES[parts[1]] then
            error("Artifact is outside a language directory")
        end
    end
    
    local data = read_file(path)
    local digest = sha256_hex(data)
    
    if not state.ausstehende_veroeffentlichungen then
        state.ausstehende_veroeffentlichungen = {}
    end
    state.ausstehende_veroeffentlichungen[relative] = digest
end

local function http_request(url, options)
    options = options or {}
    local headers = options.headers or {}
    local method = options.method or "GET"
    local body = options.body
    
    local response_body = {}
    local response, status, response_headers = https.request{
        url = url,
        method = method,
        headers = headers,
        source = body and ltn12.source.string(body),
        sink = ltn12.sink.table(response_body)
    }
    
    if not response then
        error("HTTP request failed: " .. tostring(status))
    end
    
    return {
        status = status,
        headers = response_headers,
        body = table.concat(response_body)
    }
end

local function publish_pending(root, state, save, token, options)
    options = options or {}
    local opener = options.opener or http_request
    local sync = options.sync
    
    local pending = state.ausstehende_veroeffentlichungen or {}
    if type(pending) ~= "table" then
        error("Invalid publication queue")
    end
    
    if next(pending) == nil and sync == nil then
        return true
    end
    
    if not token or token:match("^%s*$") then
        return false
    end
    
    root = resolve_path(root)
    local headers = {
        Authorization = "Bearer " .. token:gsub("^%s*(.-)%s*$", "%1"),
        Accept = "application/vnd.github+json",
        ["X-GitHub-Api-Version"] = "2022-11-28",
        ["User-Agent"] = "abstractions-manager"
    }
    
    local success = true
    local entries = {}
    for name, expected in pairs(pending) do
        table.insert(entries, {name = name, expected = expected})
    end
    
    table.sort(entries, function(a, b)
        if a.name == 'STATUS.md' and b.name ~= 'STATUS.md' then
            return false
        elseif b.name == 'STATUS.md' and a.name ~= 'STATUS.md' then
            return true
        else
            return a.name < b.name
        end
    end)
    
    local synced = false
    
    for _, entry in ipairs(entries) do
        local name = entry.name
        local expected = entry.expected
        
        local function lookup(remote_name)
            local endpoint = "https://api.github.com/repos/KikiKari/OpenClaw/contents/" .. 
                           url.escape(remote_name)
            local request_options = {
                headers = headers
            }
            
            local ok, result = pcall(function()
                return opener(endpoint .. "?ref=gateway1-abstractions", request_options)
            end)
            
            if not ok then
                if result:find("404") then
                    return endpoint, nil
                else
                    error(result)
                end
            end
            
            if result.status == 404 then
                return endpoint, nil
            elseif result.status >= 400 then
                error("HTTP error: " .. result.status)
            end
            
            return endpoint, json.decode(result.body)
        end
        
        local function same(existing)
            return type(existing) == "table" and 
                   existing.encoding == "base64" and
                   base64.dec(existing.content) == read_file(root .. "/" .. name)
        end
        
        local ok, err = pcall(function()
            local path = root .. "/" .. name
            if not file_exists(path) then
                error("Invalid queued path")
            end
            
            local data = read_file(path)
            if sha256_hex(data) ~= expected then
                error("Queued artifact changed")
            end
            
            if name == 'STATUS.md' and sync ~= nil then
                if not success then
                    error("Artifact publication incomplete")
                end
                
                local revision, counts = sync(root)
                synced = true
                update_status_counts(path, revision, counts)
                data = read_file(path)
                expected = sha256_hex(data)
                pending[name] = expected
                save(state)
            end
            
            local endpoint, existing = lookup(name)
            
            if name == 'STATUS.md' and existing ~= nil and not same(existing) then
                local sha = type(existing) == "table" and existing.sha or nil
                if type(sha) ~= "string" or sha == "" then
                    error("Missing remote status version")
                end
                
                local body_data = {
                    message = "Update abstraction status",
                    branch = "gateway1-abstractions",
                    content = base64.enc(data),
                    sha = sha
                }
                
                local request_options = {
                    method = "PUT",
                    headers = headers,
                    body = json.encode(body_data)
                }
                
                local response = opener(endpoint, request_options)
                json.decode(response.body)
            elseif existing ~= nil and not same(existing) then
                local candidate = name
                local alternate = dirname(candidate) .. "/" .. 
                                splitext(basename(candidate)) .. "_" .. 
                                expected:sub(1, 12) .. 
                                splitext(basename(candidate)):sub(-1)
                
                endpoint, existing = lookup(alternate)
                if existing ~= nil and not same(existing) then
                    error("Remote artifact conflict")
                end
            end
            
            if existing == nil then
                local body_data = {
                    message = "Publish script abstraction",
                    branch = "gateway1-abstractions",
                    content = base64.enc(data)
                }
                
                local request_options = {
                    method = "PUT",
                    headers = headers,
                    body = json.encode(body_data)
                }
                
                local response = opener(endpoint, request_options)
                json.decode(response.body)
            end
            
            pending[name] = nil
            save(state)
        end)
        
        if not ok then
            success = false
        end
    end
    
    if sync ~= nil and not synced then
        local ok, err = pcall(function()
            sync(root)
        end)
        if not ok then
            success = false
        end
    end
    
    return success
end

return {
    LANGUAGES = LANGUAGES,
    synchronize_checkout = synchronize_checkout,
    update_status_counts = update_status_counts,
    queue_artifact = queue_artifact,
    publish_pending = publish_pending
}
