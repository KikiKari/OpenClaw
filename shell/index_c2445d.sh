#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "9d2554b01b14953a025fbcfa61d332f3e7480a67143a62eab95f15944586269f", "source_sha256": "c2445d9bf4b0ccf8c05eb944692addc1436cc68504dfc0ab9e6677d90ced3ec9", "target_language": "shell"}
# index.html — portiert nach shell
# Quelle: html, workspace@local:skills/github-clones/openclaw/ui/index.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Function to generate the complete HTML document
generate_html() {
    cat << 'EOF'
<!doctype html>
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
      (function () {
        var THEMES = { claw: 1, knot: 1, dash: 1 };
        var MODES = { system: 1, light: 1, dark: 1 };
        var LEGACY = {
          dark: "claw:dark",
          light: "claw:light",
          openknot: "knot:dark",
          fieldmanual: "dash:dark",
          clawdash: "dash:light",
          system: "claw:system",
        };
        try {
          var keys = Object.keys(localStorage);
          var raw;
          for (var i = 0; i < keys.length; i++) {
            if (keys[i].indexOf("openclaw.control.settings.v1") === 0) {
              raw = localStorage.getItem(keys[i]);
              if (raw) break;
            }
          }
          if (!raw) return;
          var s = JSON.parse(raw);
          var t = s && s.theme;
          var m = s && s.themeMode;
          if (typeof t !== "string") t = "";
          if (typeof m !== "string") m = "";
          var legacy = LEGACY[t];
          var theme = THEMES[t] ? t : legacy ? legacy.split(":")[0] : "claw";
          var mode = MODES[m] ? m : legacy ? legacy.split(":")[1] : "system";
          if (mode === "system") {
            mode = window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
          }
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
        } catch (e) {}
      })();
    </script>
  </head>
  <body>
    <openclaw-app></openclaw-app>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>
EOF
}

# Main function
main() {
    local output_file="${1:-}"

    if [[ -z "$output_file" ]]; then
        # Output to stdout if no file specified
        generate_html
    else
        # Output to specified file
        generate_html > "$output_file"
    fi
}

# Call main with all arguments
main "$@"
