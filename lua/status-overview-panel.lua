#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "103bc6914274ce190ab9c65bc3672353edb42dadb9ec2a464855bb5634cec348", "source_sha256": "9be2a45ff3b835da1be1793cc88c8cb54d6a2456cf2ccc358c8243df836440e3", "target_language": "lua"}
-- status-overview-panel.css — portiert nach lua
-- Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview-panel.css
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local function writeCSS(filename)
    local file = io.open(filename, "w")
    if not file then
        error("Cannot open file for writing: " .. filename)
    end

    -- Helper function to write rules with multiple selectors
    local function writeRule(selectors, properties)
        local selectorStr = table.concat(selectors, ", ")
        file:write(selectorStr .. " { ")
        for key, value in pairs(properties) do
            file:write(key .. ":" .. value .. "; ")
        end
        file:write("}\n")
    end

    -- Overview row layout
    writeRule({".overview-row"}, {
        display = "grid",
        ["grid-template-columns"] = "24px minmax(0,1fr) 11px 22px auto",
        gap = "7px",
        ["align-items"] = "center",
        margin = "6px 0"
    })

    writeRule({".overview-row input"}, {
        ["min-width"] = "0",
        width = "100%"
    })

    -- State indicator styling
    writeRule({".overview-state"}, {
        width = "11px",
        height = "11px",
        ["border-radius"] = "50%",
        background = "#888"
    })

    writeRule({".overview-state.online"}, {
        background = "var(--good)",
        ["box-shadow"] = "0 0 0 3px color-mix(in srgb, var(--good) 15%, transparent)"
    })

    writeRule({".overview-state.offline"}, {
        background = "var(--bad)",
        ["box-shadow"] = "0 0 0 3px color-mix(in srgb, var(--bad) 15%, transparent)"
    })

    writeRule({".overview-state.checking", ".overview-state.error"}, {
        background = "var(--warn)"
    })

    -- Count display
    writeRule({".overview-count"}, {
        ["font-size"] = "11px",
        ["text-align"] = "center",
        ["font-variant-numeric"] = "tabular-nums"
    })

    -- Action buttons container
    writeRule({".overview-actions"}, {
        display = "grid",
        ["grid-template-columns"] = "44px repeat(2,minmax(0,1fr))",
        gap = "6px",
        ["align-items"] = "stretch"
    })

    writeRule({".overview-actions button"}, {
        ["min-width"] = "0",
        padding = "8px 2px",
        ["font-size"] = "11px",
        ["white-space"] = "nowrap"
    })

    -- Rows container
    writeRule({"#overview-rows"}, {
        display = "flex",
        ["flex-direction"] = "column"
    })

    -- Monitor settings
    writeRule({".monitor-settings > label:not(.option-row)"}, {
        display = "block",
        margin = "12px 0"
    })

    writeRule({".monitor-settings .option-row input"}, {
        appearance = "auto",
        width = "13px",
        height = "13px",
        ["min-width"] = "13px",
        background = "none"
    })

    -- Link styling
    writeRule({".overview-link"}, {
        padding = "8px 0",
        ["border-bottom"] = "1px solid #bbb",
        ["overflow-wrap"] = "anywhere"
    })

    writeRule({".overview-link p"}, {
        margin = "4px 0"
    })

    -- Retry button specific styling
    writeRule({".overview-row .overview-retry"}, {
        width = "24px",
        ["min-width"] = "24px",
        height = "26px",
        ["min-height"] = "26px",
        padding = "0",
        ["background-image"] = "var(--icon-reset)",
        ["background-size"] = "20px",
        ["background-position"] = "center",
        ["background-repeat"] = "no-repeat"
    })

    -- Top setting checkbox
    writeRule({".top-setting input"}, {
        appearance = "auto",
        ["-webkit-appearance"] = "checkbox",
        width = "13px",
        height = "13px",
        ["min-width"] = "13px",
        background = "none"
    })

    -- Visually hidden elements
    writeRule({".overview-visually-hidden"}, {
        position = "absolute",
        width = "1px",
        height = "1px",
        padding = "0",
        margin = "-1px",
        overflow = "hidden",
        clip = "rect(0,0,0,0)",
        ["white-space"] = "nowrap",
        border = "0"
    })

    -- Hidden rows
    writeRule({".overview-row[hidden]" }, {
        display = "none"
    })

    file:close()
end

-- Main execution
if #arg ~= 1 then
    print("Usage: " .. arg[0] .. " <output-file>")
    os.exit(1)
end

writeCSS(arg[1])
