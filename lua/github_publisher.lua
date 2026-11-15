#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "cc1f5c0f4761a584a01492360ab84d5f43e0aa5dd8263c31fb6218dede28ce80", "source_sha256": "b7508c3367d6d569a8c1beb0e8ada0a36433c0484d97610776744335d50c4f6f", "target_language": "lua"}
-- github_publisher.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

--[[Publish queued, provenance-checked artifacts without staging unrelated files.]]

local json = require("cjson")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local mime = require("mime")

local M = {}

-- Helper to compute SHA256 hash
local function sha256_hex(data)
    local b = require("crypto").digest.new("sha256")
    b:update(data)
    return b:final(true)
end

-- Helper to resolve path and check if it's under root
local function resolve_and_check(root, path_str)
    -- Normalize paths by resolving symlinks where possible
    local pl_path = require("pl.path")
    local resolved = pl_path.abspath(path_str)
    local rel = pl_path.relpath(resolved, root)
    if not rel then
        error("Could not determine relative path")
    end
    -- Check if relative path starts with allowed language directories
    local parts = {}
    for part in string.gmatch(rel, "[^/]+") do
        table.insert(parts, part)
    end
    if #parts == 0 or not ({
        perl5 = true, powershell = true, perl6 = true, tcl = true,
        javascript = true, ruby = true, python = true, lua = true,
        shell = true, go = true
    })[parts[1]] then
        error("artifact is outside a language directory")
    end
    return rel
end

function M.queue_artifact(state, root, path_str)
    local pl_path = require("pl.path")
    local f = io.open(path_str, "rb")
    if not f then
        error("Cannot open file: " .. path_str)
    end
    if pl_path.islink(path_str) then
        f:close()
        error("artifact must not be a symlink")
    end
    f:close()

    local rel = resolve_and_check(root, path_str)
    local content = assert(io.open(path_str, "rb")):read("*all")
    local hash = sha256_hex(content)
    if not state.ausstehende_veroeffentlichungen then
        state.ausstehende_veroeffentlichungen = {}
    end
    state.ausstehende_veroeffentlichungen[rel] = hash
end

function M.publish_pending(root, state, save, token, custom_opener)
    local pending = state.ausstehende_veroeffentlichungen
    if type(pending) ~= "table" then
        error("invalid publication queue")
    end
    if not next(pending) then
        return true
    end
    if not token or token:match("^%s*$") then
        return false
    end

    local headers = {
        ["Authorization"] = "Bearer " .. token:gsub("^%s+", ""):gsub("%s+$", ""),
        ["Accept"] = "application/vnd.github+json",
        ["X-GitHub-Api-Version"] = "2022-11-28",
        ["User-Agent"] = "abstractions-manager"
    }

    local success = true

    -- Copy keys to avoid modification during iteration
    local keys = {}
    for k in pairs(pending) do
        table.insert(keys, k)
    end

    for _, name in ipairs(keys) do
        local expected = pending[name]
        local full_path = root .. "/" .. name
        local f = io.open(full_path, "rb")
        if not f then
            success = false
            goto continue
        end
        if require("pl.path").islink(full_path) then
            f:close()
            success = false
            goto continue
        end
        local data = f:read("*all")
        f:close()
        local actual_hash = sha256_hex(data)
        if actual_hash ~= expected then
            success = false
            goto continue
        end

        local function lookup(remote_name)
            local endpoint = "https://api.github.com/repos/KikiKari/OpenClaw/contents/" .. remote_name:gsub("([^%w%/])", function(c)
                return string.format("%%%02X", string.byte(c))
            end)
            local url = endpoint .. "?ref=gateway1-abstractions"
            local response_body = {}
            local res, code, response_headers = custom_opener and custom_opener(url, headers) or https.request{
                url = url,
                headers = headers,
                sink = ltn12.sink.table(response_body)
            }
            if code == 404 then
                return endpoint, nil
            elseif not res or code >= 400 then
                error("HTTP error: " .. tostring(code))
            end
            local body = table.concat(response_body)
            local decoded = json.decode(body)
            return endpoint, decoded
        end

        local function same(existing)
            if type(existing) ~= "table" then return false end
            if existing.encoding ~= "base64" then return false end
            local decoded_content = mime.unb64(existing.content or "")
            return decoded_content == data
        end

        local endpoint, existing = lookup(name)
        if existing ~= nil and not same(existing) then
            local candidate_parts = {}
            for part in string.gmatch(name, "[^/]+") do
                table.insert(candidate_parts, part)
            end
            local filename = candidate_parts[#candidate_parts]
            local dir_parts = {}
            for i = 1, #candidate_parts - 1 do
                table.insert(dir_parts, candidate_parts[i])
            end
            local stem, ext = filename:match("^(.+)(%.%w+)$")
            if not stem then
                stem = filename
                ext = ""
            end
            local alt_name = table.concat(dir_parts, "/")
            if alt_name ~= "" then
                alt_name = alt_name .. "/"
            end
            alt_name = alt_name .. stem .. "_" .. expected:sub(1,12) .. ext
            endpoint, existing = lookup(alt_name)
            if existing ~= nil and not same(existing) then
                error("remote artifact conflict")
            end
        end

        if existing == nil then
            local encoded_data = mime.b64(data)
            local payload = {
                message = "Publish script abstraction",
                branch = "gateway1-abstractions",
                content = encoded_data
            }
            local json_payload = json.encode(payload)
            local post_body = {}
            local res, code = https.request{
                url = endpoint,
                method = "PUT",
                headers = headers,
                source = ltn12.source.string(json_payload),
                sink = ltn12.sink.table(post_body)
            }
            if not res or code >= 400 then
                error("Failed PUT request: " .. tostring(code))
            end
        end

        pending[name] = nil
        save(state)

        ::continue::
    end

    return success
end

return M
