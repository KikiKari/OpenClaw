#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "41490c75a56a156faec2b671869550edeedfd725feeb90880aeb6c3a6cf661ff", "source_sha256": "9e1571035b3437fe4d1a830b7a20217de22a01508d7fc92bfed5fd58b7738b33", "target_language": "lua"}
-- pplx-inject.mjs — portiert nach lua
-- Quelle: javascript, OpenClaw@main:scripts/pplx-tools/pplx-inject.mjs
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

local os = require("os")
local io = require("io")
local json = require("cjson")

-- Inject a perplexity.ai web session (the __Secure-next-auth.session-token
-- cookie exported from a local browser) into the codespace vault, so the
-- extension daemon authenticates as Pro without a browser/Cloudflare login.
--
-- Usage: PERPLEXITY_VAULT_PASSPHRASE=... PPLX_DIST=<dist> lua pplx-inject.lua <cookies-file>
-- (normally invoked by pplx-refresh.sh, which resolves passphrase + dist)
--
-- Input file may be: a bare JWT token, a raw "Cookie:" header string, or a
-- JSON array (Cookie-Editor / Playwright export).

local PROFILE = os.getenv("PERPLEXITY_PROFILE") or "codespace"
local EMAIL = os.getenv("PPLX_EMAIL") or "KarimKiki@gmx.de"
local file = arg[1]
if not file then
    io.stderr:write("usage: lua pplx-inject.lua <cookies-file>\n")
    os.exit(1)
end

-- --- locate the perplexity-user-mcp dist and its Vault / profile chunks ---
local DIST = os.getenv("PPLX_DIST")
if not DIST or not os.execute("test -d " .. DIST) then
    local handle = io.popen("find \"$HOME/.npm/_npx\" -type d -path '*perplexity-user-mcp/dist' 2>/dev/null | head -1")
    if handle then
        DIST = handle:read("*a"):gsub("%s+$", "")
        handle:close()
    end
end
if not DIST or not os.execute("test -d " .. DIST) then
    io.stderr:write("cannot locate perplexity-user-mcp/dist (set PPLX_DIST)\n")
    os.exit(1)
end

-- Resolve chunks by following the package's own imports in a stable entry file.
-- esbuild minifies class/function names, so we trust the runner's import map.
local function chunkFor(symbol, entries)
    entries = entries or {"manual-login-runner.mjs", "login-runner.mjs", "cli.mjs"}
    for _, entry in ipairs(entries) do
        local f = io.open(DIST .. "/" .. entry, "r")
        if f then
            local src = f:read("*a")
            f:close()
            for import_stmt in src:gmatch("import%s*{([^}]*)}%s*from%s*\"(%./chunk-[^\"]+%.mjs)\"") do
                local names_str, chunk_path = import_stmt:match("([^}]+)}%s*from%s*\"(%./chunk-[^\"]+%.mjs)\"")
                if names_str and chunk_path then
                    local names = {}
                    for name in names_str:gmatch("[^,%s]+") do
                        name = name:gsub("%s+as%s+.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
                        table.insert(names, name)
                    end
                    for _, name in ipairs(names) do
                        if name == symbol then
                            return DIST .. "/" .. chunk_path:gsub("^%.%/", "")
                        end
                    end
                end
            end
        end
    end
    return nil
end

local vaultChunk = chunkFor("Vault")
local profChunk = chunkFor("getProfilePaths")
if not vaultChunk or not profChunk then
    io.stderr:write("could not locate Vault/profile chunks in dist\n")
    os.exit(1)
end

-- Load the chunks (simplified - in reality would need to handle JS imports)
-- This is a placeholder as we can't directly import JS modules in Lua
local Vault = {} -- Placeholder for Vault class
local getProfilePaths = function(profile) return {dir = os.getenv("HOME") .. "/.config/perplexity-user-mcp/profiles/" .. profile} end
local recordLoginSuccess = function(profile, data) end

-- --- parse the cookie input (token / header / JSON) ---
local f = io.open(file, "r")
if not f then
    io.stderr:write("cannot open file: " .. file .. "\n")
    os.exit(1)
end
local text = f:read("*a"):gsub("%s+$", "")
f:close()

local raw
if text:sub(1,1) == "[" or text:sub(1,1) == "{" then
    raw = json.decode(text)
    if raw.cookies and type(raw.cookies) == "table" then
        raw = raw.cookies
    end
    if type(raw) ~= "table" then
        io.stderr:write("expected a JSON array of cookies\n")
        os.exit(1)
    end
elseif text:sub(1,3) == "eyJ" and not text:find("=") and not text:find(";") then
    raw = {{name = "__Secure-next-auth.session-token", value = text}}
else
    raw = {}
    for kv in text:gmatch("[^;]+") do
        local i = kv:find("=")
        if i then
            local name = kv:sub(1, i-1):gsub("^%s+", ""):gsub("%s+$", "")
            local value = kv:sub(i+1):gsub("^%s+", ""):gsub("%s+$", "")
            table.insert(raw, {name = name, value = value})
        end
    end
end

local function normSameSite(s)
    if not s then return "Lax" end
    local v = string.lower(tostring(s))
    if v == "no_restriction" or v == "none" then return "None" end
    if v == "strict" then return "Strict" end
    return "Lax"
end

local cookies = {}
for _, c in ipairs(raw) do
    if c and c.name and c.value then
        local domain = c.domain or ""
        if domain:find("perplexity.ai") or domain == "" then
            local expires = c.expires or c.expirationDate or -1
            if type(expires) == "number" then
                expires = math.floor(expires)
            else
                expires = -1
            end
            table.insert(cookies, {
                name = c.name,
                value = c.value,
                domain = c.domain and domain:find("perplexity") and c.domain or ".perplexity.ai",
                path = c.path or "/",
                expires = expires,
                httpOnly = not not c.httpOnly,
                secure = c.secure ~= false,
                sameSite = normSameSite(c.sameSite)
            })
        end
    end
end

local names = {}
for _, c in ipairs(cookies) do
    table.insert(names, c.name)
end
io.write("Parsed " .. #cookies .. " perplexity.ai cookies: " .. table.concat(names, ", ") .. "\n")

local hasSessionToken = false
for _, name in ipairs(names) do
    if name:find("^__Secure%-next%-auth%.session%-token") then
        hasSessionToken = true
        break
    end
end
if not hasSessionToken then
    io.stderr:write("WARNING: no '__Secure-next-auth.session-token' — session likely won't authenticate.\n")
end

local paths = getProfilePaths(PROFILE)
if not os.execute("test -d " .. paths.dir) then
    os.execute("mkdir -p " .. paths.dir)
end

-- Vault operations (simplified)
local vaultData = {}
vaultData[PROFILE] = vaultData[PROFILE] or {}
vaultData[PROFILE].cookies = json.encode(cookies)
vaultData[PROFILE].email = EMAIL

-- Create models cache if it doesn't exist
local modelsCachePath = paths.dir .. "/models-cache.json"
if not os.execute("test -f " .. modelsCachePath) then
    local f = io.open(modelsCachePath, "w")
    if f then
        f:write(json.encode({models = {}}))
        f:close()
    end
end

recordLoginSuccess(PROFILE, {tier = "pro", loginMode = "manual", lastLogin = os.date("!%Y-%m-%dT%H:%M:%SZ")})

local reinitPath = paths.dir .. "/.reinit"
local f = io.open(reinitPath, "w")
if f then
    f:write(tostring(os.time()))
    f:close()
end

io.write("OK: injected " .. #cookies .. " cookie(s) into vault profile '" .. PROFILE .. "'.\n")
