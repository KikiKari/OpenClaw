#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "c4dee93548f21db61bbfeb37976a3c3f67b61934c2c61d9f1f663d0e2b35461d", "source_sha256": "c2445d9bf4b0ccf8c05eb944692addc1436cc68504dfc0ab9e6677d90ced3ec9", "target_language": "python"}
# index.html — portiert nach python
# Quelle: html, workspace@local:skills/github-clones/openclaw/ui/index.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import json
import sys
from typing import Dict, Any, Optional

def generate_html(output_file: str) -> None:
    """Generate the OpenClaw Control HTML page and write it to a file."""
    
    # Define constants
    THEMES = {"claw": 1, "knot": 1, "dash": 1}
    MODES = {"system": 1, "light": 1, "dark": 1}
    LEGACY = {
        "dark": "claw:dark",
        "light": "claw:light",
        "openknot": "knot:dark",
        "fieldmanual": "dash:dark",
        "clawdash": "dash:light",
        "system": "claw:system",
    }
    
    # JavaScript code as a template string
    js_code = f"""
      (function () {{
        var THEMES = {json.dumps(THEMES)};
        var MODES = {json.dumps(MODES)};
        var LEGACY = {json.dumps(LEGACY)};
        try {{
          var keys = Object.keys(localStorage);
          var raw;
          for (var i = 0; i < keys.length; i++) {{
            if (keys[i].indexOf("openclaw.control.settings.v1") === 0) {{
              raw = localStorage.getItem(keys[i]);
              if (raw) break;
            }}
          }}
          if (!raw) return;
          var s = JSON.parse(raw);
          var t = s && s.theme;
          var m = s && s.themeMode;
          if (typeof t !== "string") t = "";
          if (typeof m !== "string") m = "";
          var legacy = LEGACY[t];
          var theme = THEMES[t] ? t : legacy ? legacy.split(":")[0] : "claw";
          var mode = MODES[m] ? m : legacy ? legacy.split(":")[1] : "system";
          if (mode === "system") {{
            mode = window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
          }}
          var resolved =
            theme === "knot"
              ? mode === "light"
                ? "openknot-light"
                : "openknot"
              : theme === "dash"
                ? mode === "light"
                  ? "dash-light"
                  : "dash"
                : mode === "light"
                  ? "light"
                  : "dark";
          document.documentElement.setAttribute("data-theme", resolved);
          document.documentElement.setAttribute(
            "data-theme-mode",
            resolved.indexOf("light") !== -1 ? "light" : "dark",
          );
        }} catch (e) {{}}
      }})();
    """
    
    # Create the HTML structure
    html_content = f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>OpenClaw Control</title>
    <meta name="color-scheme" content="dark light" />
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png" />
    <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png" />
    <script>
{js_code}
    </script>
  </head>
  <body>
    <openclaw-app></openclaw-app>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>"""
    
    # Write to file
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(html_content)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <output_file>")
        sys.exit(1)
    
    output_file = sys.argv[1]
    generate_html(output_file)
    print(f"HTML file generated: {output_file}")
