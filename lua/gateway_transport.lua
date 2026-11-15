#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "c1af9d70408946ae7b1591f4b9c26aad39db6b0bd3d6c11886211156909a7f0c", "source_sha256": "0cfda5c5495fad1eb8cbf8562ac3b851f251f1a3645890dc28e6f870336a28b5", "target_language": "lua"}
-- gateway_transport.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/gateway_transport.py
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

--[[Gateway-authenticated transport with manager-owned attempt records.

An attempt is saved before submission. If its outcome is uncertain, subsequent
calls only query the same node and attempt; they do not submit it again.
]]

local json = require("cjson")
local uuid = require("uuid")

-- Initialize UUID generator
uuid.seed()

local function TransportUnresolved(message)
    return {message = message, type = "TransportUnresolved"}
end

local function gateway_token()
    -- Use the local Gateway credential without changing its configuration.
    local token = os.getenv('OPENCLAW_GATEWAY_TOKEN') or ''
    token = string.match(token, "^%s*(.-)%s*$") or ''
    if token ~= '' then
        return token
    end
    
    local config_path = os.getenv('OPENCLAW_CONFIG_PATH')
    if not config_path then
        local home = os.getenv('HOME') or os.getenv('USERPROFILE') or '.'
        config_path = home .. '/.openclaw/openclaw.json'
    end
    
    local file = io.open(config_path, "r")
    if not file then
        return ''
    end
    
    local content = file:read("*a")
    file:close()
    
    local success, config = pcall(json.decode, content)
    if not success or type(config) ~= "table" then
        return ''
    end
    
    local gw_token = config.gateway and config.gateway.auth and config.gateway.auth.token
    if type(gw_token) == "string" and not string.match(gw_token, "^%${") then
        return string.match(gw_token, "^%s*(.-)%s*$") or ''
    end
    
    return ''
end

local GatewayTransport = {}
GatewayTransport.__index = GatewayTransport

function GatewayTransport:new(state, save, url, token, options)
    options = options or {}
    local timeout = options.timeout or 3900
    local interval = options.interval or 3
    local opener = options.opener or function(req, timeout_val)
        -- Simple HTTP request implementation using LuaSocket
        local http = require("socket.http")
        local ltn12 = require("ltn12")
        
        local response_body = {}
        local res, code, response_headers, status = http.request{
            url = req.url,
            method = req.method,
            headers = req.headers,
            source = ltn12.source.string(req.data),
            sink = ltn12.sink.table(response_body),
            timeout = timeout_val
        }
        
        if not res then
            error("HTTP request failed: " .. tostring(code))
        end
        
        return {
            read = function(limit)
                local body = table.concat(response_body)
                if limit and #body > limit then
                    error("Response too large")
                end
                return body
            end
        }
    end
    local clock = options.clock or os.clock
    local sleep = options.sleep or function(t) 
        local socket = require("socket")
        socket.sleep(t)
    end
    
    -- Parse URL
    local scheme, host
    if string.match(url, "^https://") then
        scheme, host = "https", string.match(url, "^https://([^/]+)")
    elseif string.match(url, "^http://") then
        scheme, host = "http", string.match(url, "^http://([^/]+)")
    else
        error("invalid Gateway URL")
    end
    
    if not scheme or not host then
        error("invalid Gateway URL")
    end
    
    if scheme == "http" and not (host == "127.0.0.1" or host == "localhost" or host == "::1") then
        error("unencrypted Gateway must use loopback")
    end
    
    if not token or string.match(token, "^%s*$") or timeout <= 0 or interval <= 0 then
        error("Gateway token and positive timeouts required")
    end
    
    local obj = {
        state = state,
        save = save,
        url = url,
        token = string.match(token, "^%s*(.-)%s*$"),
        timeout = timeout,
        interval = interval,
        opener = opener,
        clock = clock,
        sleep = sleep
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
    
    local req = {
        url = self.url,
        method = "POST",
        data = payload,
        headers = {
            ["Authorization"] = "Bearer " .. self.token,
            ["Content-Type"] = "application/json"
        }
    }
    
    local timeout_val = (node == "node4") and 150 or 40
    
    local success, result = pcall(function()
        local response = self.opener(req, timeout_val)
        local raw = response:read(4000001)
        
        if #raw > 4000000 then
            error("response too large")
        end
        
        local data = json.decode(raw)
        
        if type(data) ~= "table" or data.result == nil then
            error("invalid gateway response")
        end
        
        if device_id ~= nil and data.device_id ~= device_id then
            error("gateway device identity mismatch")
        end
        
        return data.result
    end)
    
    if not success then
        error(TransportUnresolved("Gateway request failed"))
    end
    
    return result
end

function GatewayTransport:available()
    local result = self:_request("node1", {operation = "availability"})
    
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
            operation = "release",
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
    local auftraege = self.state.auftraege or {}
    
    for _, entry in pairs(auftraege) do
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
    self.state.auftraege = self.state.auftraege or {}
    local entries = self.state.auftraege
    local entry = entries[key]
    local fresh = entry == nil
    
    if fresh then
        local original = {
            source_sha256 = job.source_sha256,
            target_language = job.target_language,
            selected_device_id = job.selected_device_id,
            selected_node = job.selected_node,
            job_id = job.job_id,
            attempt_id = uuid(),
        }
        entry = {job = original, status = "submitted"}
        entries[key] = entry
        -- If this write fails there must be no remote submission.
        self.save(self.state)
    end
    
    local original = entry.job
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
        local success = pcall(function()
            status = self:_request(original.selected_node, {
                operation = "execute",
                job = original
            }, original.selected_device_id)
        end)
        if not success then
            -- The request may have been accepted. Query, never resend.
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
