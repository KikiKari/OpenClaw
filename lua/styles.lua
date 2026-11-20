#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "55caebef231a1a58d3db29626c5c9b91541f2d0d2e59b760220ae20ad1900ff0", "source_sha256": "17d9118c74c9951b6bd9c5e3475b496be57f796a591823384aa44dbdad5a115d", "target_language": "lua"}
-- styles.css — portiert nach lua
-- Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles.css
-- Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

local function write_css_file(filename, content)
    local file = io.open(filename, "w")
    if not file then
        error("Could not open file for writing: " .. filename)
    end
    file:write(content)
    file:close()
end

local function create_base_css()
    return [[
/* Base styles */
:root {
  --mono: #2d2d2d;
  --accent: #007acc;
  --info: #00a0d0;
  --warn: #ffa500;
  --ok: #00c000;
  --danger: #ff0000;
}
]]
end

local function create_layout_css()
    return [[
/* Layout styles */
.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 20px;
}
]]
end

local function create_layout_mobile_css()
    return [[
/* Mobile layout styles */
@media (max-width: 768px) {
  .container {
    padding: 0 10px;
  }
}
]]
end

local function create_components_css()
    return [[
/* Component styles */
.button {
  display: inline-block;
  padding: 8px 16px;
  border-radius: 4px;
  text-decoration: none;
  cursor: pointer;
}
]]
end

local function create_chat_css()
    return [[
/* Chat component styles */
.chat-container {
  display: flex;
  flex-direction: column;
  height: 100vh;
}

.chat-messages {
  flex-grow: 1;
  overflow-y: auto;
  padding: 20px;
}

.chat-input {
  display: flex;
  padding: 20px;
  border-top: 1px solid #eee;
}
]]
end

local function create_config_css()
    return [[
/* Configuration styles */
.config-panel {
  background: #f5f5f5;
  border-radius: 8px;
  padding: 20px;
  margin: 20px 0;
}
]]
end

local function create_usage_css()
    return [[
/* Usage documentation styles */
.usage-example {
  background: #f8f8f8;
  border-left: 4px solid var(--accent);
  padding: 16px;
  margin: 16px 0;
  font-family: monospace;
}
]]
end

local function create_dreams_css()
    return [[
/* Dreams feature styles */
.dream-entry {
  border-bottom: 1px solid #eee;
  padding: 20px 0;
}

.dream-title {
  font-size: 1.2em;
  margin-bottom: 8px;
}

.dream-content {
  line-height: 1.6;
}
]]
end

local function create_system_css()
    return [[
/* System theme styles */
[data-theme="dark"] {
  --background: #1a1a1a;
  --text: #ffffff;
  --border: #444444;
}

[data-theme="light"] {
  --background: #ffffff;
  --text: #333333;
  --border: #dddddd;
}
]]
end

local function generate_main_css()
    local imports = {
        "./styles/base.css",
        "./styles/layout.css", 
        "./styles/layout.mobile.css",
        "./styles/components.css",
        "./styles/chat.css",
        "./styles/config.css",
        "./styles/usage.css",
        "./styles/dreams.css",
        "@create-markdown/preview/themes/system.css"
    }
    
    local content = ""
    
    -- Add import statements
    for _, import_path in ipairs(imports) do
        content = content .. "@import \"" .. import_path .. "\";\n"
    end
    
    -- Add cm-preview class
    content = content .. "\n.cm-preview {\n"
    content = content .. "  --cm-mono: var(--mono);\n"
    content = content .. "  --cm-link: var(--accent);\n"
    content = content .. "  --cm-info: var(--info);\n"
    content = content .. "  --cm-warning: var(--warn);\n"
    content = content .. "  --cm-success: var(--ok);\n"
    content = content .. "  --cm-danger: var(--danger);\n"
    content = content .. "}\n"
    
    return content
end

local function main()
    local output_file = arg[1] or "styles.css"
    
    -- Create directory structure if needed
    os.execute("mkdir -p styles")
    os.execute("mkdir -p @create-markdown/preview/themes")
    
    -- Write individual CSS files
    write_css_file("styles/base.css", create_base_css())
    write_css_file("styles/layout.css", create_layout_css())
    write_css_file("styles/layout.mobile.css", create_layout_mobile_css())
    write_css_file("styles/components.css", create_components_css())
    write_css_file("styles/chat.css", create_chat_css())
    write_css_file("styles/config.css", create_config_css())
    write_css_file("styles/usage.css", create_usage_css())
    write_css_file("styles/dreams.css", create_dreams_css())
    write_css_file("@create-markdown/preview/themes/system.css", create_system_css())
    
    -- Generate and write main CSS file
    local main_css_content = generate_main_css()
    write_css_file(output_file, main_css_content)
    
    print("CSS files generated successfully!")
end

main()
