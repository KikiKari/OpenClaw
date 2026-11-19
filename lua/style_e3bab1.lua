#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "b21c9be5ae1c785c60e4643549d02f93258b81e76bddf928ceba67501170ce70", "source_sha256": "e3bab1624f203b949716145357872ec8001a11d44b45121002215386ca7164b3", "target_language": "lua"}
-- style.css — portiert nach lua
-- Quelle: css, workspace@local:skills/github-clones/openclaw/docs/style.css
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local function generate_css(output_file)
    local css_rules = {}

    -- Regel 1: #content > h1:first-of-type
    table.insert(css_rules, {
        selector = "#content > h1:first-of-type",
        properties = {
            {"display", "none !important"}
        }
    })

    -- Regel 2: .nav-tabs
    table.insert(css_rules, {
        selector = ".nav-tabs",
        properties = {
            {"position", "relative"}
        }
    })

    -- Regel 3: .nav-tabs-item > div
    table.insert(css_rules, {
        selector = ".nav-tabs-item > div",
        properties = {
            {"opacity", "0"}
        }
    })

    -- Regel 4: .nav-tabs-underline
    table.insert(css_rules, {
        selector = ".nav-tabs-underline",
        properties = {
            {"position", "absolute"},
            {"left", "0"},
            {"bottom", "0"},
            {"height", "1.5px"},
            {"width", "var(--nav-tab-underline-width, 0)"},
            {"transform", "translateX(var(--nav-tab-underline-x, 0))"},
            {"background-color", "rgb(var(--primary))"},
            {"border-radius", "999px"},
            {"pointer-events", "none"},
            {"opacity", "0"},
            {"transition", "transform 260ms ease-in-out, width 260ms ease-in-out, opacity 160ms ease-in-out"},
            {"will-change", "transform, width"}
        }
    })

    -- Regel 5: html.dark .nav-tabs-underline
    table.insert(css_rules, {
        selector = "html.dark .nav-tabs-underline",
        properties = {
            {"background-color", "rgb(var(--primary-light))"}
        }
    })

    -- Regel 6: .nav-tabs-underline-ready .nav-tabs-underline
    table.insert(css_rules, {
        selector = ".nav-tabs-underline-ready .nav-tabs-underline",
        properties = {
            {"opacity", "1"}
        }
    })

    -- CSS generieren
    local css_content = ""
    for _, rule in ipairs(css_rules) do
        css_content = css_content .. rule.selector .. " {\n"
        for _, prop in ipairs(rule.properties) do
            css_content = css_content .. "  " .. prop[1] .. ": " .. prop[2] .. ";\n"
        end
        css_content = css_content .. "}\n\n"
    end

    -- In Datei schreiben
    local file = io.open(output_file, "w")
    if file then
        file:write(css_content)
        file:close()
        return true
    else
        return false
    end
end

-- Hauptprogramm
if #arg ~= 1 then
    print("Verwendung: " .. arg[0] .. " <ausgabedatei>")
    os.exit(1)
end

local output_file = arg[1]
if generate_css(output_file) then
    print("CSS erfolgreich in " .. output_file .. " geschrieben")
else
    print("Fehler beim Schreiben der CSS-Datei")
    os.exit(1)
end
