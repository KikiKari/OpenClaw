#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "9021511db893147fb3c52419536fb36578f62f4782367a6da913fae2fa0051f0", "source_sha256": "0cfda5c5495fad1eb8cbf8562ac3b851f251f1a3645890dc28e6f870336a28b5", "target_language": "lua"}
-- gateway_transport.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/gateway_transport.py
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

--[[Gateway-authenticated transport with manager-owned attempt records.

An attempt is saved before submission. If its outcome is uncertain, subsequent
calls only query the same node and attempt; they do not submit it again.
--]]

local json = require("cjson")
local uuid = require("uuid")

-- Generate UUID v4
uuid.randomseed(os.time())

local function TransportUnresolved(msg)
    return {__name = "TransportUnresolved", msg = msg}
end

local function gateway_token()
    --[[Use the local Gateway credential without changing its configuration.--]]
    local token = os.getenv('OPENCLAW_GATEWAY_TOKEN') or ''
    token = string.gsub(token, "^%s*(.-)%s*$", "%1") -- strip whitespace
    if token ~= '' then
        return token
    end
    local config_path = os.getenv('OPENCLAW_CONFIG_PATH')
    if not config_path then
        config_path = (os.getenv('HOME') or '/tmp') .. '/.openclaw/openclaw.json'
    end
    local file = io.open(config_path, "r")
    if not file then
        return ''
    end
    local content = file:read("*a")
    file:close()
    local success, config = pcall(json.decode, content)
    if not success then
        return ''
    end
    if type(config) == "table" and config.gateway and config.gateway.auth and config.gateway.auth.token then
        local t = config.gateway.auth.token
        if type(t) == "string" and not string.match(t, "^%${") then
            return string.gsub(t, "^%s*(.-)%s*$", "%1") -- strip whitespace
        end
    end
    return ''
end

local GatewayTransport = {}
GatewayTransport.__index = GatewayTransport

function GatewayTransport:new(state, save, url, token, options)
    options = options or {}
    local parsed = {}
    -- Simple URL parsing
    local scheme, host
    if string.match(url, "^https://") then
        scheme = "https"
        host = string.match(url, "^https://([^/]+)")
    elseif string.match(url, "^http://") then
        scheme = "http"
        host = string.match(url, "^http://([^/]+)")
    else
        error("invalid Gateway URL")
    end
    if not scheme or not host then
        error("invalid Gateway URL")
    end
    if scheme == "http" and not (host == "127.0.0.1" or host == "localhost" or host == "::1") then
        error("unencrypted Gateway must use loopback")
    end
    if not string.match(token, "%S") or (options.timeout or 0) <= 0 or (options.interval or 0) <= 0 then
        error("Gateway token and positive timeouts required")
    end
    
    local obj = {
        state = state,
        save = save,
        url = url,
        token = string.gsub(token, "^%s*(.-)%s*$", "%1"),
        timeout = options.timeout or 3900,
        interval = options.interval or 3,
        opener = options.opener or function(req_url, body, headers, timeout_val)
            local curl_cmd = {"curl", "-s", "-m", tostring(timeout_val), "-X", "POST"}
            table.insert(curl_cmd, "-H")
            table.insert(curl_cmd, "Authorization: Bearer " .. headers.Authorization:sub(8))
            table.insert(curl_cmd, "-H")
            table.insert(curl_cmd, "Content-Type: application/json")
            table.insert(curl_cmd, "-d")
            table.insert(curl_cmd, body)
            table.insert(curl_cmd, req_url)
            
            local pipe = io.popen(table.concat(curl_cmd, " "), "r")
            local result = pipe:read("*a")
            local success, _, code = pipe:close()
            if not success and code ~= 0 then
                error("HTTP request failed")
            end
            return result
        end,
        clock = options.clock or os.clock,
        sleep = options.sleep or function(n)
            local start = os.clock()
            while os.clock() - start < n do end
        end
    }
    setmetatable(obj, GatewayTransport)
    return obj
end

function GatewayTransport:_request(node, request, device_id)
    local payload_data = {
        node = node,
        device_id = device_id,
        request = request
    }
    local payload = json.encode(payload_data)
    local timeout_val = (node == 'node4') and 150 or 40
    local headers = {
        Authorization = 'Bearer ' .. self.token,
        ['Content-Type'] = 'application/json'
    }
    
    local success, result_raw = pcall(function()
        return self.opener(self.url, payload, headers, timeout_val)
    end)
    
    if not success then
        error(TransportUnresolved("Gateway request failed"))
    end
    
    if #result_raw > 4000000 then
        error("response too large")
    end
    
    local success_json, data = pcall(json.decode, result_raw)
    if not success_json or type(data) ~= "table" or data.result == nil then
        error("invalid gateway response")
    end
    
    if device_id ~= nil and data.device_id ~= device_id then
        error("gateway device identity mismatch")
    end
    
    return data.result
end

function GatewayTransport:available()
    local result = self:_request('node1', {operation = 'availability'})
    if type(result) ~= "table" then
        error(TransportUnresolved("invalid node availability"))
    end
    return result
end

function GatewayTransport:_release(original, entry)
    if entry.released then
        return
    end
    local success, result = pcall(function()
        return self:_request(original.selected_node, {
            operation = 'release',
            job_id = original.job_id,
            attempt_id = original.attempt_id
        }, original.selected_device_id)
    end)
    if not success then
        return -- Retry cleanup later; the result is durable in manager state.
    end
    if (type(result) == "table" and result.status == "released" and
        result.job_id == original.job_id and
        result.attempt_id == original.attempt_id and
        result.selected_node == original.selected_node and
        result.target_language == original.target_language) then
        entry.released = true
        self.save(self.state)
    end
end

function GatewayTransport:release_pending()
    if not self.state.auftraege then
        return
    end
    for _, entry in pairs(self.state.auftraege) do
        if (type(entry) == "table" and 
            (entry.status == "completed" or entry.status == "failed" or entry.status == "unknown") and
            type(entry.job) == "table") then
            self:_release(entry.job, entry)
        end
    end
end

function GatewayTransport:__call(job)
    if not job.source_sha256 or not job.target_language or not job.selected_device_id then
        error("missing source identity")
    end
    local key = job.source_sha256 .. ":" .. job.target_language
    if not self.state.auftraege then
        self.state.auftraege = {}
    end
    local entries = self.state.auftraege
    local entry = entries[key]
    local fresh = entry == nil
    local original
    if fresh then
        original = {}
        for k, v in pairs(job) do
            original[k] = v
        end
        original.attempt_id = uuid()
        entry = {job = original, status = "submitted"}
        entries[key] = entry
        -- If this write fails there must be no remote submission.
        self.save(self.state)
    else
        original = entry.job
    end
    -- The dispatcher verifies the job object after transport returns.
    for k, v in pairs(original) do
        job[k] = v
    end
    if entry.response ~= nil then
        self:_release(original, entry)
        return entry.response
    end
    if entry.status == "failed" or entry.status == "unknown" then
        error(TransportUnresolved("attempt requires reconciliation"))
    end
    local status = nil
    if fresh then
        local success
        success, status = pcall(function()
            return self:_request(original.selected_node, {operation = "execute", job = original}, original.selected_device_id)
        end)
        if not success then
            status = nil -- The request may have been accepted. Query, never resend.
        end
    end
    local deadline = self.clock() + self.timeout
    while true do
        if status == nil then
            status = self:_request(original.selected_node, {
                operation = "status",
                job_id = original.job_id,
                attempt_id = original.attempt_id
            }, original.selected_device_id)
        end
        if type(status) ~= "table" then
            error(TransportUnresolved("attempt is not known by the node"))
        end
        if (status.job_id ~= original.job_id or
            status.attempt_id ~= original.attempt_id or
            status.selected_node ~= original.selected_node or
            status.target_language ~= original.target_language) then
            error(TransportUnresolved("status identity mismatch"))
        end
        local state = status.status
        if state == "completed" then
            local response = status.response
            if (type(response) ~= "table" or response.status ~= "ok" or
                response.job_id ~= original.job_id or
                response.selected_node ~= original.selected_node or
                response.target_language ~= original.target_language or
                type(response.code) ~= "string" or string.match(response.code, "^%s*$")) then
                error(TransportUnresolved("invalid translation result"))
            end
            entry.response = response
            entry.status = "completed"
            self.save(self.state)
            self:_release(original, entry)
            return response
        end
        if state == "failed" or state == "unknown" then
            entry.status = state
            self.save(self.state)
            self:_release(original, entry)
            error(TransportUnresolved("attempt requires reconciliation"))
        end
        if state ~= "running" or self.clock() >= deadline then
            error(TransportUnresolved("attempt is unresolved"))
        end
        self.sleep(self.interval)
        status = nil
    end
end

return {
    TransportUnresolved = TransportUnresolved,
    gateway_token = gateway_token,
    GatewayTransport = GatewayTransport
}
