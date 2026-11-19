#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "38840badc7d062fca09e49591c76d5fb283fcd39677d1d0d8b04d69624b16f08", "source_sha256": "4e253f02b715d7d8ae256f0b72f993ca4646b5e466c1f39a9d5e2d3864a4fe77", "target_language": "lua"}
-- gateway_transport.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/gateway_transport.py
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

--[[Gateway-authenticated transport with manager-owned attempt records.

An attempt is saved before submission. If its outcome is uncertain, subsequent
calls only query the same node and attempt; they do not submit it again.
]]
local json = require("cjson")
local uuid = require("uuid")

local TransportUnresolved = {}
TransportUnresolved.__index = TransportUnresolved

function TransportUnresolved:new(message)
    local obj = {message = message}
    setmetatable(obj, self)
    return obj
end

function TransportUnresolved:__tostring()
    return "TransportUnresolved: " .. self.message
end

local function gateway_token()
    --[[Use the local Gateway credential without changing its configuration.]]
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
    if not success then
        return ''
    end
    
    if type(config) == "table" and 
       type(config.gateway) == "table" and 
       type(config.gateway.auth) == "table" and 
       type(config.gateway.auth.token) == "string" then
        token = config.gateway.auth.token
        if not string.match(token, "^%${") then
            return string.match(token, "^%s*(.-)%s*$") or ''
        end
    end
    
    return ''
end

local GatewayTransport = {}
GatewayTransport.__index = GatewayTransport

function GatewayTransport:new(state, save, url, token, options)
    options = options or {}
    local obj = {
        state = state,
        save = save,
        url = url,
        token = token,
        timeout = options.timeout or 3900,
        interval = options.interval or 3,
        opener = options.opener or function(req) return http.request(req) end,
        clock = options.clock or os.clock,
        sleep = options.sleep or function(t) 
            local start = os.time()
            while os.time() - start < t do end
        end
    }
    setmetatable(obj, self)
    
    -- Parse URL
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
    
    if string.match(token, "^%s*$") or obj.timeout <= 0 or obj.interval <= 0 then
        error("Gateway token and positive timeouts required")
    end
    
    return obj
end

function GatewayTransport:_request(node, request, device_id)
    local payload_data = {
        node = node,
        device_id = device_id,
        request = request
    }
    
    local payload = json.encode(payload_data)
    local headers = {
        ["Authorization"] = "Bearer " .. self.token,
        ["Content-Type"] = "application/json"
    }
    
    local timeout = (node == "node4") and 150 or 40
    
    -- This is a simplified HTTP request - in real usage you'd need a proper HTTP client
    local success, result = pcall(function()
        -- Placeholder for actual HTTP request implementation
        -- This would need to be replaced with a real HTTP library call
        return self.opener({
            url = self.url,
            method = "POST",
            headers = headers,
            data = payload,
            timeout = timeout
        })
    end)
    
    if not success then
        error(TransportUnresolved:new("Gateway request failed"))
    end
    
    -- Simulate reading response
    local raw = result.body or ""
    if #raw > 4000000 then
        error("response too large")
    end
    
    local success, data = pcall(json.decode, raw)
    if not success or type(data) ~= "table" or data.result == nil then
        error("invalid gateway response")
    end
    
    if device_id ~= nil and data.device_id ~= device_id then
        error("gateway device identity mismatch")
    end
    
    return data.result
end

function GatewayTransport:available()
    local result = self:_request("node1", {operation = "availability"})
    if type(result) ~= "table" then
        error(TransportUnresolved:new("invalid node availability"))
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
    
    if type(result) == "table" and 
       result.status == "released" and
       result.job_id == original.job_id and
       result.attempt_id == original.attempt_id and
       result.selected_node == original.selected_node and
       result.target_language == original.target_language then
        entry.released = true
        self.save(self.state)
    end
end

function GatewayTransport:release_pending()
    local auftraege = self.state.auftraege or {}
    for _, entry in pairs(auftraege) do
        if type(entry) == "table" and 
           (entry.status == "completed" or entry.status == "rejected" or entry.status == "failed") and
           type(entry.job) == "table" then
            self:_release(entry.job, entry)
        end
    end
end

function GatewayTransport:reject(job, reason)
    --[[Record a completed response rejected by validation, before retrying it.]]
    if not job.source_sha256 or not job.target_language then
        return
    end
    
    local key = job.source_sha256 .. ":" .. job.target_language
    local auftraege = self.state.auftraege or {}
    local entry = auftraege[key]
    
    if type(entry) ~= "table" or entry.status ~= "completed" then
        return
    end
    
    if not entry.job or entry.job.attempt_id ~= job.attempt_id then
        error(TransportUnresolved:new("rejected attempt identity mismatch"))
    end
    
    entry.status = "rejected"
    entry.validation_error = string.sub(tostring(reason), 1, 500)
    self.save(self.state)
end

function GatewayTransport:__call(job)
    if not job.source_sha256 or not job.target_language or not job.selected_device_id then
        error("missing source identity")
    end
    
    local key = job.source_sha256 .. ":" .. job.target_language
    self.state.auftraege = self.state.auftraege or {}
    local entries = self.state.auftraege
    local entry = entries[key]
    
    local fresh
    if type(entry) == "table" and entry.status == "rejected" then
        self:_release(entry.job, entry)
        if not entry.released then
            error(TransportUnresolved:new("rejected attempt release is unresolved"))
        end
        
        local previous = entry
        local original = {
            source_sha256 = job.source_sha256,
            target_language = job.target_language,
            selected_device_id = job.selected_device_id,
            selected_node = job.selected_node,
            job_id = job.job_id,
            attempt_id = uuid()
        }
        
        entry = {
            job = original,
            status = "submitted",
            previous_attempts = previous.previous_attempts or {}
        }
        
        table.insert(entry.previous_attempts, {
            job_id = previous.job.job_id,
            attempt_id = previous.job.attempt_id,
            selected_node = previous.job.selected_node,
            validation_error = previous.validation_error
        })
        
        entries[key] = entry
        self.save(self.state)
        fresh = true
    else
        fresh = entry == nil
    end
    
    if entry == nil then
        local original = {
            source_sha256 = job.source_sha256,
            target_language = job.target_language,
            selected_device_id = job.selected_device_id,
            selected_node = job.selected_node,
            job_id = job.job_id,
            attempt_id = uuid()
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
        error(TransportUnresolved:new("attempt requires reconciliation"))
    end
    
    local status = nil
    if fresh then
        local success = pcall(function()
            status = self:_request(original.selected_node, {
                operation = "execute",
                job = original
            }, original.selected_device_id)
        end)
        -- The request may have been accepted. Query, never resend.
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
            error(TransportUnresolved:new("attempt is not known by the node"))
        end
        
        if status.job_id ~= original.job_id or
           status.attempt_id ~= original.attempt_id or
           status.selected_node ~= original.selected_node or
           status.target_language ~= original.target_language then
            error(TransportUnresolved:new("status identity mismatch"))
        end
        
        local state = status.status
        if state == "completed" then
            local response = status.response
            if type(response) ~= "table" or 
               response.status ~= "ok" or
               response.job_id ~= original.job_id or
               response.selected_node ~= original.selected_node or
               response.target_language ~= original.target_language or
               type(response.code) ~= "string" or
               string.match(response.code, "^%s*$") then
                error(TransportUnresolved:new("invalid translation result"))
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
            if state == "failed" then
                self:_release(original, entry)
            end
            error(TransportUnresolved:new("attempt requires reconciliation"))
        end
        
        if state ~= "running" or self.clock() >= deadline then
            error(TransportUnresolved:new("attempt is unresolved"))
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
