#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "d22ed9b5465c3a9da178cd8b3a9d7ae58c3b7ee0d67408cd572f43ead0ab7fbe", "source_sha256": "dfe62418dcbef9ea8aa7f18ada4f57d0ef73593432b7c7cefd85ee87eee622b4", "target_language": "lua"}
-- github_publisher.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
-- Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

--[[Publish queued, provenance-checked artifacts without staging unrelated files.]]

local json = require("cjson")
local openssl = require("openssl")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local git = require("git")

local LANGUAGES = {
    perl5 = true, powershell = true, perl6 = true, tcl = true,
    javascript = true, ruby = true, python = true, lua = true,
    shell = true, go = true, java = true, c = true, cpp = true,
    php = true, fsharp = true, css = true
}

local function sha256_hex(data)
    local evp = openssl.digest.new("sha256")
    evp:update(data)
    return evp:final(true)
end

local function read_file(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local content = file:read("*all")
    file:close()
    return content
end

local function write_file(path, content)
    local file = io.open(path, "wb")
    if not file then return false end
    file:write(content)
    file:close()
    return true
end

local function run_command(cmd, timeout)
    local handle = io.popen(cmd, "r")
    if not handle then return nil end
    local result = handle:read("*a")
    handle:close()
    return result
end

local function synchronize_checkout(root, remote, branch)
    remote = remote or "https://github.com/KikiKari/OpenClaw.git"
    branch = branch or "gateway1-abstractions"
    
    -- Create temporary directory
    local tmp = os.tmpname()
    os.remove(tmp)
    os.execute("mkdir -p " .. tmp)
    local snapshot = tmp .. "/repo"
    
    -- Clone repository
    local clone_cmd = string.format(
        "git clone --quiet --depth=1 --single-branch --branch %s %s %s 2>/dev/null",
        branch, remote, snapshot
    )
    os.execute(clone_cmd)
    
    -- Get revision
    local rev_cmd = string.format("git -C %s rev-parse HEAD", snapshot)
    local revision = run_command(rev_cmd)
    if not revision then
        os.execute("rm -rf " .. tmp)
        error("Failed to get revision")
    end
    revision = revision:gsub("%s+$", "")
    
    local counts = {}
    
    -- Process each language
    for language, _ in pairs(LANGUAGES) do
        local source = snapshot .. "/" .. language
        local target = root .. "/" .. language
        
        -- Check if directories exist
        local source_exists = os.rename(source, source) ~= nil
        local target_exists = os.rename(target, target) ~= nil
        
        if not target_exists then
            os.execute("mkdir -p " .. target)
        end
        
        -- Get known files checksums
        local known = {}
        if target_exists then
            local handle = io.popen("find " .. target .. " -type f -not -name '.*'")
            if handle then
                for file in handle:lines() do
                    local data = read_file(file)
                    if data then
                        known[sha256_hex(data)] = true
                    end
                end
                handle:close()
            end
        end
        
        -- Process files
        local files = {}
        if source_exists then
            local handle = io.popen("find " .. source .. " -type f")
            if handle then
                for file in handle:lines() do
                    table.insert(files, file)
                end
                handle:close()
            end
        end
        
        counts[language] = #files
        
        for _, item in ipairs(files) do
            local data = read_file(item)
            if data then
                local digest = sha256_hex(data)
                if not known[digest] then
                    local filename = item:match("([^/]+)$")
                    local destination = target .. "/" .. filename
                    
                    -- Check if destination exists
                    if os.rename(destination, destination) ~= nil then
                        -- Generate new filename with digest
                        local basename = filename:match("(.-)%..*$") or filename
                        local ext = filename:match("%.(.*)$")
                        ext = ext and "." .. ext or ""
                        destination = target .. "/" .. basename .. "__pool_" .. digest .. ext
                    end
                    
                    -- Write file
                    if not write_file(destination, data) then
                        os.execute("rm -rf " .. tmp)
                        error("Failed to write file")
                    end
                    known[digest] = true
                end
            end
        end
    end
    
    os.execute("rm -rf " .. tmp)
    return revision, counts
end

local function update_status_counts(path, revision, counts)
    local content = read_file(path)
    if not content then return end
    
    local rows = {
        "## Bestand", "", 
        string.format("GitHub-Stand: `%s`", revision), "",
        "| Zielsprache | Dateien |", "|---|---:|"
    }
    
    local total = 0
    local sorted_langs = {}
    for lang, _ in pairs(LANGUAGES) do
        table.insert(sorted_langs, lang)
    end
    table.sort(sorted_langs)
    
    for _, language in ipairs(sorted_langs) do
        local count = counts[language] or 0
        table.insert(rows, string.format("| %s | %d |", language, count))
        total = total + count
    end
    
    table.insert(rows, string.format("| **gesamt** | **%d** |", total))
    table.insert(rows, "")
    table.insert(rows, "")
    
    local rows_str = table.concat(rows, "\n")
    content = content:gsub("## Bestand\n.-## Quellen\n", rows_str, 1)
    
    write_file(path, content)
end

local function queue_artifact(state, root, path)
    -- Resolve paths
    local abs_path = path
    local rel_path = path:gsub("^" .. root .. "/", "")
    
    -- Check if artifact is valid
    if rel_path ~= "STATUS.md" then
        local parts = {}
        for part in rel_path:gmatch("[^/]+") do
            table.insert(parts, part)
        end
        if #parts == 0 or not LANGUAGES[parts[1]] then
            error("artifact is outside a language directory")
        end
    end
    
    -- Read and hash file
    local data = read_file(path)
    if not data then
        error("could not read artifact")
    end
    
    local hash = sha256_hex(data)
    
    -- Add to pending publications
    if not state.ausstehende_veroeffentlichungen then
        state.ausstehende_veroeffentlichungen = {}
    end
    state.ausstehende_veroeffentlichungen[rel_path] = hash
end

local function http_request(url, headers, method, body)
    local request = {
        url = url,
        method = method or "GET",
        headers = headers or {},
        sink = ltn12.sink.table(),
        source = body and ltn12.source.string(body)
    }
    
    local ok, code, headers, status = https.request(request)
    if not ok then
        return nil, code
    end
    
    local response_body = table.concat(request.sink_result or {})
    local response_data = {}
    if response_body and response_body ~= "" then
        response_data = json.decode(response_body)
    end
    
    return {
        code = code,
        headers = headers,
        data = response_data
    }
end

local function publish_pending(root, state, save, token, opener, sync)
    opener = opener or http_request
    local pending = state.ausstehende_veroeffentlichungen or {}
    
    if type(pending) ~= "table" then
        error("invalid publication queue")
    end
    
    if next(pending) == nil and sync == nil then
        return true
    end
    
    if not token or token:gsub("%s+", "") == "" then
        return false
    end
    
    local headers = {
        Authorization = "Bearer " .. token:gsub("%s+", ""),
        Accept = "application/vnd.github+json",
        ["X-GitHub-Api-Version"] = "2022-11-28",
        ["User-Agent"] = "abstractions-manager"
    }
    
    local success = true
    local entries = {}
    
    -- Sort entries putting STATUS.md last
    local status_entry
    for name, hash in pairs(pending) do
        if name == "STATUS.md" then
            status_entry = {name, hash}
        else
            table.insert(entries, {name, hash})
        end
    end
    if status_entry then
        table.insert(entries, status_entry)
    end
    
    local synced = false
    
    for _, entry in ipairs(entries) do
        local name, expected = entry[1], entry[2]
        local path = root .. "/" .. name
        
        local function lookup(remote_name)
            local endpoint = "https://api.github.com/repos/KikiKari/OpenClaw/contents/" .. remote_name
            local request_headers = {}
            for k, v in pairs(headers) do
                request_headers[k] = v
            end
            request_headers["Accept"] = "*/*"
            
            local response, err = opener(endpoint .. "?ref=gateway1-abstractions", request_headers)
            if not response and err == 404 then
                return endpoint, nil
            elseif not response then
                error(err)
            end
            
            return endpoint, response.data
        end
        
        local function same(existing)
            if type(existing) ~= "table" or existing.encoding ~= "base64" then
                return false
            end
            local decoded = openssl.base64_decode(existing.content or "")
            local file_data = read_file(path)
            return decoded == file_data
        end
        
        local ok, err = pcall(function()
            -- Verify file integrity
            local data = read_file(path)
            if not data then
                error("could not read file")
            end
            
            if sha256_hex(data) ~= expected then
                error("queued artifact changed")
            end
            
            -- Handle STATUS.md synchronization
            if name == "STATUS.md" and sync ~= nil then
                if not success then
                    error("artifact publication incomplete")
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
            
            if name == "STATUS.md" and existing ~= nil and not same(existing) then
                local sha = type(existing) == "table" and existing.sha or nil
                if type(sha) ~= "string" or sha == "" then
                    error("missing remote status version")
                end
                
                local body = json.encode({
                    message = "Update abstraction status",
                    branch = "gateway1-abstractions",
                    content = openssl.base64_encode(data),
                    sha = sha
                })
                
                local request_headers = {}
                for k, v in pairs(headers) do
                    request_headers[k] = v
                end
                request_headers["Content-Type"] = "application/json"
                
                local response = opener(endpoint, request_headers, "PUT", body)
                if not response then
                    error("failed to update status")
                end
            elseif existing ~= nil and not same(existing) then
                -- Handle conflicts by creating alternate names
                local candidate_parts = {}
                for part in name:gmatch("[^/]+") do
                    table.insert(candidate_parts, part)
                end
                local filename = candidate_parts[#candidate_parts]
                local dir_parts = {}
                for i = 1, #candidate_parts - 1 do
                    table.insert(dir_parts, candidate_parts[i])
                end
                local dir_path = table.concat(dir_parts, "/")
                
                local basename = filename:match("(.-)%..*$") or filename
                local ext = filename:match("%.(.*)$")
                ext = ext and "." .. ext or ""
                local alternate = (dir_path ~= "" and dir_path .. "/" or "") .. 
                                basename .. "_" .. expected:sub(1, 12) .. ext
                
                endpoint, existing = lookup(alternate)
                if existing ~= nil and not same(existing) then
                    error("remote artifact conflict")
                end
            end
            
            if existing == nil then
                local body = json.encode({
                    message = "Publish script abstraction",
                    branch = "gateway1-abstractions",
                    content = openssl.base64_encode(data)
                })
                
                local request_headers = {}
                for k, v in pairs(headers) do
                    request_headers[k] = v
                end
                request_headers["Content-Type"] = "application/json"
                
                local response = opener(endpoint, request_headers, "PUT", body)
                if not response then
                    error("failed to publish artifact")
                end
            end
            
            pending[name] = nil
            save(state)
        end)
        
        if not ok then
            success = false
        end
    end
    
    if sync ~= nil and not synced then
        local ok = pcall(function()
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
