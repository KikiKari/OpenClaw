// abstraction-provenance: {"artifact_sha256": "c9f5cd762f2596e5e98c7ff581542ae68bac6ca961fcb6ad82817bd33f0a83a8", "source_sha256": "c2445d9bf4b0ccf8c05eb944692addc1436cc68504dfc0ab9e6677d90ced3ec9", "target_language": "fsharp"}
// index.html — portiert nach fsharp
// Quelle: html, workspace@local:skills/github-clones/openclaw/ui/index.html
// auch in: openclaw-css@local:workspace/skills/github-clones/openclaw/ui/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Text.Json

type Theme = Claw | Knot | Dash
type Mode = System | Light | Dark
type Settings = { theme: string; themeMode: string }

let themes = set ["claw"; "knot"; "dash"]
let modes = set ["system"; "light"; "dark"]

let legacyMap = Map [
    "dark", ("claw", "dark")
    "light", ("claw", "light")
    "openknot", ("knot", "dark")
    "fieldmanual", ("dash", "dark")
    "clawdash", ("dash", "light")
    "system", ("claw", "system")
]

let getResolvedTheme (theme: string) (mode: string) =
    let actualMode = 
        if mode = "system" then
            // In a real implementation, we would check system preferences
            // For now, defaulting to dark as in original logic
            "dark"
        else mode
    
    match theme with
    | "knot" -> if actualMode = "light" then "openknot-light" else "openknot"
    | "dash" -> if actualMode = "light" then "dash-light" else "dash"
    | _ -> if actualMode = "light" then "light" else "dark"

let generateHtml (outputPath: string) =
    let headSection = """
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
  </head>"""
    
    let bodySection = """
<body>
    <openclaw-app></openclaw-app>
    <script type="module" src="/src/main.ts"></script>
  </body>"""
    
    let htmlContent = $"""<!doctype html>
<html lang="en">
{headSection}
{bodySection}
</html>"""
    
    File.WriteAllText(outputPath, htmlContent)
    printfn $"HTML file generated at {outputPath}"

// Entry point
[<EntryPoint>]
let main argv =
    let outputPath = 
        if argv.Length > 0 then argv.[0] 
        else "index.html"
        
    generateHtml outputPath
    0
