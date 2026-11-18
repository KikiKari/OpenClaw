#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "907f528a52db9c3e7695f286668fca5871b8db0e41e001be6639b8e1de281a2c", "source_sha256": "47d390b58fc734629c213c66e58cb7f0c68bbd896bac294215d12289e5e21c07", "target_language": "lua"}
-- gateway-styles.css — portiert nach lua
-- Quelle: css, OpenClaw@main:examples/gateway-styles.css
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

local function generate_css(output_file)
  local css = {}

  -- Add comment
  table.insert(css, "/* OpenClaw Gateway Dashboard */\n")

  -- Universal selector
  table.insert(css, "*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }\n\n")

  -- Root variables
  table.insert(css, ":root {\n")
  table.insert(css, "  --bg:       #0d1117;\n")
  table.insert(css, "  --surface:  #161b22;\n")
  table.insert(css, "  --border:   #30363d;\n")
  table.insert(css, "  --text:     #e6edf3;\n")
  table.insert(css, "  --muted:    #8b949e;\n")
  table.insert(css, "  --green:    #3fb950;\n")
  table.insert(css, "  --yellow:   #d29922;\n")
  table.insert(css, "  --red:      #f85149;\n")
  table.insert(css, "  --accent:   #58a6ff;\n")
  table.insert(css, "}\n\n")

  -- Body styles
  table.insert(css, "body {\n")
  table.insert(css, "  background: var(--bg);\n")
  table.insert(css, "  color: var(--text);\n")
  table.insert(css, "  font-family: -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif;\n")
  table.insert(css, "  min-height: 100vh;\n")
  table.insert(css, "}\n\n")

  -- Header styles
  table.insert(css, "header {\n")
  table.insert(css, "  display: flex;\n")
  table.insert(css, "  align-items: center;\n")
  table.insert(css, "  gap: 1rem;\n")
  table.insert(css, "  padding: 1.25rem 2rem;\n")
  table.insert(css, "  border-bottom: 1px solid var(--border);\n")
  table.insert(css, "  background: var(--surface);\n")
  table.insert(css, "}\n\n")

  table.insert(css, "header h1 { font-size: 1.25rem; color: var(--accent); }\n\n")

  -- Badge styles
  table.insert(css, ".badge {\n")
  table.insert(css, "  padding: .25rem .75rem;\n")
  table.insert(css, "  border-radius: 999px;\n")
  table.insert(css, "  font-size: .75rem;\n")
  table.insert(css, "  font-weight: 600;\n")
  table.insert(css, "  background: var(--border);\n")
  table.insert(css, "  color: var(--muted);\n")
  table.insert(css, "}\n")
  table.insert(css, ".badge.ok    { background: #1a3a2a; color: var(--green); }\n")
  table.insert(css, ".badge.warn  { background: #3a2e0a; color: var(--yellow); }\n")
  table.insert(css, ".badge.error { background: #3a1010; color: var(--red); }\n\n")

  -- Main styles
  table.insert(css, "main { padding: 2rem; max-width: 960px; margin: 0 auto; }\n\n")

  -- Grid styles
  table.insert(css, ".grid {\n")
  table.insert(css, "  display: grid;\n")
  table.insert(css, "  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));\n")
  table.insert(css, "  gap: 1rem;\n")
  table.insert(css, "  margin-bottom: 2rem;\n")
  table.insert(css, "}\n\n")

  -- Card styles
  table.insert(css, ".card {\n")
  table.insert(css, "  background: var(--surface);\n")
  table.insert(css, "  border: 1px solid var(--border);\n")
  table.insert(css, "  border-radius: 8px;\n")
  table.insert(css, "  padding: 1.25rem;\n")
  table.insert(css, "  position: relative;\n")
  table.insert(css, "}\n\n")

  table.insert(css, ".card h2   { font-size: 1rem; margin-bottom: .25rem; }\n")
  table.insert(css, ".card .endpoint { font-size: .8rem; color: var(--muted); }\n\n")

  -- Status dot styles
  table.insert(css, ".status-dot {\n")
  table.insert(css, "  position: absolute;\n")
  table.insert(css, "  top: 1.25rem;\n")
  table.insert(css, "  right: 1.25rem;\n")
  table.insert(css, "  width: 10px;\n")
  table.insert(css, "  height: 10px;\n")
  table.insert(css, "  border-radius: 50%;\n")
  table.insert(css, "  background: var(--border);\n")
  table.insert(css, "}\n")
  table.insert(css, ".status-dot.green { background: var(--green); box-shadow: 0 0 6px var(--green); }\n")
  table.insert(css, ".status-dot.red   { background: var(--red);   box-shadow: 0 0 6px var(--red); }\n\n")

  -- Metrics styles
  table.insert(css, ".metrics h2 { font-size: 1rem; margin-bottom: 1rem; }\n\n")

  -- Table styles
  table.insert(css, "table {\n")
  table.insert(css, "  width: 100%;\n")
  table.insert(css, "  border-collapse: collapse;\n")
  table.insert(css, "  font-size: .875rem;\n")
  table.insert(css, "}\n")
  table.insert(css, "th, td {\n")
  table.insert(css, "  padding: .625rem 1rem;\n")
  table.insert(css, "  text-align: left;\n")
  table.insert(css, "  border-bottom: 1px solid var(--border);\n")
  table.insert(css, "}\n")
  table.insert(css, "th { color: var(--muted); font-weight: 500; }\n")
  table.insert(css, "tr:last-child td { border-bottom: none; }\n")

  -- Write to file
  local file = io.open(output_file, "w")
  if not file then
    error("Could not open file " .. output_file .. " for writing")
  end
  
  file:write(table.concat(css))
  file:close()
end

-- Main execution
local output_filename = arg[1] or "gateway-styles.css"
generate_css(output_filename)
