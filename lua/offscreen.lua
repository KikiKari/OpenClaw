#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "76809134144d86bd9ca83dc5baae39f6792e7f809fd08608efff168655d363b3", "source_sha256": "a5de51b02b40bbdeafb7fb0f4da19091ec351b10a9160307085ebcef403cdd67", "target_language": "lua"}
-- offscreen.html — portiert nach lua
-- Quelle: html, Projects@TikTok-Live-Companion:release/0.7.1/tiktok-live-companion-extension-0.7.1/offscreen.html
-- auch in: Projects@TikTok-Live-Companion-Android:release/0.7.1/tiktok-live-companion-extension-0.7.1/offscreen.html
-- auch in: Projects@TikTok-Live-Companion-iOS:release/0.7.1/tiktok-live-companion-extension-0.7.1/offscreen.html
-- auch in: Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/browser-extension/offscreen.html
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local function create_offscreen_html(output_file)
    local html_content = [[<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <title>TikTok LIVE Companion Sprachausgabe</title>
</head>
<body>
  <script src="offscreen.js"></script>
</body>
</html>]]

    local file = io.open(output_file, "w")
    if not file then
        error("Kann Datei " .. output_file .. " nicht erstellen")
    end
    
    file:write(html_content)
    file:close()
    
    print("HTML-Datei erfolgreich erstellt: " .. output_file)
end

-- Hauptprogramm
local output_filename = arg[1] or "offscreen.html"
create_offscreen_html(output_filename)
