#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "44d1bab955501b72a25987b221aafe767bbe1eb70e552ccfb563c1159ba6a692", "source_sha256": "502dcda47466a4ab74da59badbe4b12c4782ed031c43d5038f8bd8534373cd35", "target_language": "lua"}
-- model_usage.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/model-usage/scripts/model_usage.py
-- auch in: OpenClaw@gateway2:skills/model-usage/scripts/model_usage.py
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

--[[
Summarize CodexBar local cost usage by model.

Defaults to current model (most recent daily entry), or list all models.
]]

local argparse = require "argparse"
local json = require "cjson"

local function eprint(msg)
    io.stderr:write(msg .. "\n")
end

local function run_codexbar_cost(provider)
    local cmd = {"codexbar", "cost", "--format", "json", "--provider", provider}
    local success, result, exit_code = pcall(function()
        local handle = io.popen(table.concat(cmd, " "))
        local output = handle:read("*a")
        handle:close()
        return output
    end)
    
    if not success then
        error("codexbar not found on PATH. Install CodexBar CLI first.")
    end
    
    if exit_code ~= 0 then
        error("codexbar cost failed (exit " .. tostring(exit_code) .. ").")
    end
    
    local ok, payload = pcall(json.decode, result)
    if not ok then
        error("Failed to parse codexbar JSON output: " .. payload)
    end
    
    if type(payload) ~= "table" then
        error("Expected codexbar cost JSON array.")
    end
    
    return payload
end

local function load_payload(input_path, provider)
    local data
    if input_path then
        local raw
        if input_path == "-" then
            raw = io.stdin:read("*a")
        else
            local file = io.open(input_path, "r")
            if not file then
                error("Could not open file: " .. input_path)
            end
            raw = file:read("*a")
            file:close()
        end
        data = json.decode(raw)
    else
        data = run_codexbar_cost(provider)
    end

    if type(data) == "table" and data.provider then
        return data
    end

    if type(data) == "table" then
        for _, entry in ipairs(data) do
            if type(entry) == "table" and entry.provider == provider then
                return entry
            end
        end
        error("Provider '" .. provider .. "' not found in codexbar payload.")
    end

    error("Unsupported JSON input format.")
end

local function parse_daily_entries(payload)
    local daily = payload.daily
    if not daily then
        return {}
    end
    if type(daily) ~= "table" then
        return {}
    end
    local result = {}
    for _, entry in ipairs(daily) do
        if type(entry) == "table" then
            table.insert(result, entry)
        end
    end
    return result
end

local function parse_date(value)
    local pattern = "(%d+)-(%d+)-(%d+)"
    local year, month, day = string.match(value, pattern)
    if year and month and day then
        return {year = tonumber(year), month = tonumber(month), day = tonumber(day)}
    end
    return nil
end

local function date_tostring(date_obj)
    return string.format("%04d-%02d-%02d", date_obj.year, date_obj.month, date_obj.day)
end

local function filter_by_days(entries, days)
    if not days then
        return entries
    end
    
    local today = os.date("*t")
    local cutoff = {year = today.year, month = today.month, day = today.day}
    
    -- Simple approximation for cutoff date calculation
    cutoff.day = cutoff.day - (days - 1)
    if cutoff.day < 1 then
        cutoff.month = cutoff.month - 1
        if cutoff.month < 1 then
            cutoff.year = cutoff.year - 1
            cutoff.month = 12
        end
        -- This is a simplification - real implementation would need proper calendar logic
        cutoff.day = cutoff.day + 30
    end
    
    local filtered = {}
    for _, entry in ipairs(entries) do
        local day = entry.date
        if type(day) == "string" then
            local parsed = parse_date(day)
            if parsed then
                -- Simple comparison - year, month, day
                local entry_date = parsed.year * 10000 + parsed.month * 100 + parsed.day
                local cutoff_date = cutoff.year * 10000 + cutoff.month * 100 + cutoff.day
                if entry_date >= cutoff_date then
                    table.insert(filtered, entry)
                end
            end
        end
    end
    return filtered
end

local function aggregate_costs(entries)
    local totals = {}
    for _, entry in ipairs(entries) do
        local breakdowns = entry.modelBreakdowns
        if breakdowns and type(breakdowns) == "table" then
            for _, item in ipairs(breakdowns) do
                if type(item) == "table" then
                    local model = item.modelName
                    local cost = item.cost
                    if type(model) == "string" and (type(cost) == "number" or type(cost) == "string") then
                        totals[model] = (totals[model] or 0) + tonumber(cost)
                    end
                end
            end
        end
    end
    return totals
end

local function pick_current_model(entries)
    if #entries == 0 then
        return nil, nil
    end
    
    -- Sort entries by date
    local sorted_entries = {}
    for i, entry in ipairs(entries) do
        sorted_entries[i] = entry
    end
    table.sort(sorted_entries, function(a, b)
        local date_a = a.date or ""
        local date_b = b.date or ""
        return date_a < date_b
    end)
    
    for i = #sorted_entries, 1, -1 do
        local entry = sorted_entries[i]
        local breakdowns = entry.modelBreakdowns
        if type(breakdowns) == "table" and #breakdowns > 0 then
            local scored = {}
            for _, item in ipairs(breakdowns) do
                if type(item) == "table" then
                    local model = item.modelName
                    local cost = item.cost
                    if type(model) == "string" and (type(cost) == "number" or type(cost) == "string") then
                        table.insert(scored, {model = model, cost = tonumber(cost)})
                    end
                end
            end
            
            if #scored > 0 then
                table.sort(scored, function(a, b) return a.cost > b.cost end)
                local latest_date = entry.date
                if type(latest_date) ~= "string" then
                    latest_date = nil
                end
                return scored[1].model, latest_date
            end
        end
        
        local models_used = entry.modelsUsed
        if type(models_used) == "table" and #models_used > 0 then
            local last = models_used[#models_used]
            if type(last) == "string" then
                local latest_date = entry.date
                if type(latest_date) ~= "string" then
                    latest_date = nil
                end
                return last, latest_date
            end
        end
    end
    
    return nil, nil
end

local function usd(value)
    if value == nil then
        return "—"
    end
    return "$" .. string.format("%.2f", value):gsub("(%d)(%d%d%d)$", "%1,%2")
end

local function latest_day_cost(entries, model)
    if #entries == 0 then
        return nil, nil
    end
    
    -- Sort entries by date
    local sorted_entries = {}
    for i, entry in ipairs(entries) do
        sorted_entries[i] = entry
    end
    table.sort(sorted_entries, function(a, b)
        local date_a = a.date or ""
        local date_b = b.date or ""
        return date_a < date_b
    end)
    
    for i = #sorted_entries, 1, -1 do
        local entry = sorted_entries[i]
        local breakdowns = entry.modelBreakdowns
        if type(breakdowns) == "table" then
            for _, item in ipairs(breakdowns) do
                if type(item) == "table" and item.modelName == model then
                    local cost = item.cost
                    if type(cost) == "number" or type(cost) == "string" then
                        local day = entry.date
                        if type(day) ~= "string" then
                            day = nil
                        end
                        return day, tonumber(cost)
                    end
                end
            end
        end
    end
    
    return nil, nil
end

local function render_text_current(provider, model, latest_date, total_cost, latest_cost, latest_cost_date, entry_count)
    local lines = {
        "Provider: " .. provider,
        "Current model: " .. model
    }
    
    if latest_date then
        table.insert(lines, "Latest model date: " .. latest_date)
    end
    
    table.insert(lines, "Total cost (rows): " .. usd(total_cost))
    
    if latest_cost_date then
        table.insert(lines, "Latest day cost: " .. usd(latest_cost) .. " (" .. latest_cost_date .. ")")
    end
    
    table.insert(lines, "Daily rows: " .. entry_count)
    
    return table.concat(lines, "\n")
end

local function render_text_all(provider, totals)
    local lines = {"Provider: " .. provider, "Models:"}
    
    -- Convert to array for sorting
    local items = {}
    for model, cost in pairs(totals) do
        table.insert(items, {model = model, cost = cost})
    end
    
    table.sort(items, function(a, b) return a.cost > b.cost end)
    
    for _, item in ipairs(items) do
        table.insert(lines, "- " .. item.model .. ": " .. usd(item.cost))
    end
    
    return table.concat(lines, "\n")
end

local function build_json_current(provider, model, latest_date, total_cost, latest_cost, latest_cost_date, entry_count)
    return {
        provider = provider,
        mode = "current",
        model = model,
        latestModelDate = latest_date,
        totalCostUSD = total_cost,
        latestDayCostUSD = latest_cost,
        latestDayCostDate = latest_cost_date,
        dailyRowCount = entry_count
    }
end

local function build_json_all(provider, totals)
    local models = {}
    
    -- Convert to array for sorting
    local items = {}
    for model, cost in pairs(totals) do
        table.insert(items, {model = model, cost = cost})
    end
    
    table.sort(items, function(a, b) return a.cost > b.cost end)
    
    for _, item in ipairs(items) do
        table.insert(models, {
            model = item.model,
            totalCostUSD = item.cost
        })
    end
    
    return {
        provider = provider,
        mode = "all",
        models = models
    }
end

local function main()
    local parser = argparse()
    parser:group("general")
    parser:option("--provider", "Provider"):default("codex"):choices({"codex", "claude"})
    parser:option("--mode", "Mode"):default("current"):choices({"current", "all"})
    parser:option("--model", "Explicit model name to report instead of auto-current.")
    parser:option("--input", "Path to codexbar cost JSON (or '-' for stdin).")
    parser:option("--days", "Limit to last N days (based on daily rows)."):convert(tonumber)
    parser:option("--format", "Output format"):default("text"):choices({"text", "json"})
    parser:flag("--pretty", "Pretty-print JSON output.")
    
    local args = parser:parse()
    
    local payload
    local ok, err = pcall(function()
        payload = load_payload(args.input, args.provider)
    end)
    
    if not ok then
        eprint(tostring(err))
        return 1
    end
    
    local entries = parse_daily_entries(payload)
    entries = filter_by_days(entries, args.days)
    
    if args.mode == "current" then
        local model = args.model
        local latest_date = nil
        if not model then
            model, latest_date = pick_current_model(entries)
        end
        if not model then
            eprint("No model data found in codexbar cost payload.")
            return 2
        end
        local totals = aggregate_costs(entries)
        local total_cost = totals[model]
        local latest_cost_date, latest_cost = latest_day_cost(entries, model)
        
        if args.format == "json" then
            local payload_out = build_json_current(
                args.provider,
                model,
                latest_date,
                total_cost,
                latest_cost,
                latest_cost_date,
                #entries
            )
            if args.pretty then
                print(json.encode(payload_out))
            else
                print(json.encode(payload_out))
            end
        else
            print(render_text_current(
                args.provider,
                model,
                latest_date,
                total_cost,
                latest_cost,
                latest_cost_date,
                #entries
            ))
        end
        return 0
    end
    
    local totals = aggregate_costs(entries)
    if not next(totals) then
        eprint("No model breakdowns found in codexbar cost payload.")
        return 2
    end
    
    if args.format == "json" then
        local payload_out = build_json_all(args.provider, totals)
        if args.pretty then
            print(json.encode(payload_out))
        else
            print(json.encode(payload_out))
        end
    else
        print(render_text_all(args.provider, totals))
    end
    
    return 0
end

os.exit(main())
