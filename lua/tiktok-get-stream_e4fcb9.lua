#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "3dc1c989222c8aefda6fe044f683f951daf88ba84acb5f5b078678afd114934e", "source_sha256": "e4fcb95b6aa05b8fa419b7ed085317debab4e29b8cfb62a4d3ab8ec952610874", "target_language": "lua"}
-- tiktok-get-stream.js — portiert nach lua
-- Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-get-stream.js
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

local json = require("cjson")
local http = require("socket.http")
local ltn12 = require("ltn12")
local posix = require("posix")
local process = require("process")

local FALLBACK_TIMEOUT_MS = 45000
local FALLBACK_MAX_OUTPUT = 1024 * 1024

local function log(message)
    io.stderr:write(message .. "\n")
end

local function run_fallback(script_path, args)
    local command = {"bash", script_path}
    for _, arg in ipairs(args) do
        table.insert(command, arg)
    end

    local stdout = ""
    local stderr = ""
    local pid, errmsg = posix.fork()
    if pid == nil then
        return {code = 2, stdout = "", stderr = "Failed to fork: " .. errmsg}
    elseif pid == 0 then
        -- Child process
        local outfile = io.tmpfile()
        local errfile = io.tmpfile()
        posix.dup2(outfile:fileno(), 1)
        posix.dup2(errfile:fileno(), 2)
        posix.execp(command[1], unpack(command))
        os.exit(1)
    else
        -- Parent process
        local start_time = os.time()
        while true do
            local res = posix.waitpid(pid, "WNOHANG")
            if res ~= 0 then
                break
            end
            if os.difftime(os.time(), start_time) > FALLBACK_TIMEOUT_MS / 1000 then
                posix.kill(pid, "SIGTERM")
                posix.sleep(3)
                posix.kill(pid, "SIGKILL")
                return {code = 2, stdout = "", stderr = "fallback timeout"}
            end
            posix.sleep(0.1)
        end

        local _, status, _ = posix.waitpid(pid)
        if status == "exited" then
            return {code = 0, stdout = stdout, stderr = stderr}
        else
            return {code = 2, stdout = "", stderr = "Process terminated unexpectedly"}
        end
    end
end

local function parse_fallback_result(method, username, execution)
    for _, text in ipairs({execution.stdout, execution.stderr}) do
        if text and text ~= "" then
            local success, value = pcall(json.decode, text)
            if success and type(value) == "table" then
                return normalize_extractor_result(value, method, username)
            end
        end
    end
    return normalize_extractor_result({
        success = false,
        status = execution.code == 75 and "overloaded" or "technical_error",
        method = method,
        username = username,
        message = execution.stderr or ("fallback exited " .. tostring(execution.code))
    }, method, username)
end

local function playwright_preflight()
    -- Placeholder implementation as we don't have a direct equivalent in Lua
    return {ok = true, executable = "/usr/bin/chromium-browser"}
end

local function human_delay(min, max)
    math.randomseed(os.time())
    return math.random(min or 2000, max or 4000)
end

local function handle_popups(page)
    -- This would require a full browser automation library which doesn't exist natively in Lua
    -- Placeholder returning false to indicate no action taken
    return false
end

local function check_restrictions(page)
    -- This would also require browser automation capabilities
    -- Placeholder indicating unrestricted access
    return {restricted = false, reason = nil}
end

local function extract_with_playwright(username, quality_preference)
    local preflight = playwright_preflight()
    if not preflight.ok then
        return {
            success = false,
            method = "playwright",
            status = preflight.status,
            error = preflight.error
        }
    end

    -- Since we can't actually launch a browser in Lua without additional libraries,
    -- we'll simulate a failure here.
    return {
        success = false,
        method = "playwright",
        status = "technical_error",
        error = "Browser automation not supported in this environment"
    }
end

local function try_streamlink(username, quality)
    local script_path = "./extraction-methods/extract-tiktok-streamlink.sh"
    local execution = run_fallback(script_path, {username, quality, "--json"})
    return parse_fallback_result("streamlink", username, execution)
end

local function try_yt_dlp(username, quality)
    local script_path = "./extraction-methods/extract-tiktok-yt-dlp.sh"
    local yt_format_map = {
        original = "hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld",
        ["1080p60"] = "hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld",
        ["720p60"] = "hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld",
        ["720p"] = "hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld",
        ["540p"] = "hls-sd/hls-ld/flv-sd/flv-ld",
        ["360p"] = "hls-ld/flv-ld",
        auto = "hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld"
    }
    local yt_format = yt_format_map[quality] or yt_format_map.auto
    local execution = run_fallback(script_path, {username, yt_format, "--json"})
    return parse_fallback_result("yt-dlp", username, execution)
end

local function get_stream_url(username, quality_preference)
    local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")

    log("[1/3] Trying Playwright for @" .. username .. "...")
    local pw_result = extract_with_playwright(username, quality_preference)
    if pw_result.success then
        pw_result.timestamp = timestamp
        return pw_result
    end
    if pw_result.status == "restricted" or pw_result.status == "overloaded" then
        return pw_result
    end
    log("Playwright result: " .. (pw_result.reason or pw_result.error or "failed"))

    log("[2/3] Trying streamlink for @" .. username .. " (quality: " .. quality_preference .. ")...")
    local sl_result = try_streamlink(username, quality_preference)
    if sl_result.success then
        return sl_result
    end
    if sl_result.status == "restricted" or sl_result.status == "overloaded" then
        return sl_result
    end
    log("Streamlink result: " .. (sl_result.message or sl_result.error or "failed"))

    log("[3/3] Trying yt-dlp for @" .. username .. "...")
    local yt_result = try_yt_dlp(username, quality_preference)
    if yt_result.success then
        return yt_result
    end
    if yt_result.status == "restricted" or yt_result.status == "overloaded" then
        return yt_result
    end
    log("yt-dlp result: " .. (yt_result.message or yt_result.error or "failed"))

    local status = classify_final_failure({pw_result, sl_result, yt_result})
    return {
        success = false,
        status = status,
        username = username,
        message = "All extraction methods failed (Playwright, streamlink, yt-dlp).",
        playwright_reason = pw_result.reason or pw_result.error,
        streamlink_reason = sl_result.message or sl_result.error,
        ytdlp_reason = yt_result.message or yt_result.error,
        timestamp = timestamp
    }
end

local function main()
    if #arg < 1 then
        print("Usage: lua tiktok-get-stream.lua <username> [quality: original|1080p60|720p60|720p|540p|360p|auto] [--json]")
        os.exit(1)
    end

    local cli_username = normalize_username(arg[1])
    enforce_load_limit("playwright_streamlink_ytdlp")
    if forced_offline("playwright_streamlink_ytdlp", cli_username) then
        os.exit(1)
    end

    local cli_quality = "auto"
    local cli_json = false
    for i = 2, #arg do
        if arg[i] == "--json" then
            cli_json = true
        elseif not arg[i]:match("^%-") then
            cli_quality = arg[i]
        end
    end

    if not ({original=true, ["1080p60"]=true, ["720p60"]=true, ["720p"]=true, ["540p"]=true, ["360p"]=true, auto=true})[cli_quality] then
        print("Invalid quality; expected original, 1080p60, 720p60, 720p, 540p, 360p, or auto")
        os.exit(64)
    end

    local result = get_stream_url(cli_username, cli_quality)
    if cli_json then
        print(json.encode(result))
    else
        if result.success then
            print(result.url)
        else
            print(result.message)
        end
    end
    os.exit(exit_code_for_result(result))
end

main()
