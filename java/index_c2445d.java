// abstraction-provenance: {"artifact_sha256": "0ecca8da1fb76781d6fbc9a5aadf8ac2ce6f0fe3abfca60bafc79288d8cb6ca3", "source_sha256": "c2445d9bf4b0ccf8c05eb944692addc1436cc68504dfc0ab9e6677d90ced3ec9", "target_language": "java"}
// index.html — portiert nach java
// Quelle: html, workspace@local:skills/github-clones/openclaw/ui/index.html
// auch in: openclaw-css@local:workspace/skills/github-clones/openclaw/ui/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

public class IndexGenerator {
    
    public static void main(String[] args) {
        if (args.length != 1) {
            System.err.println("Usage: java IndexGenerator <output-file>");
            System.exit(1);
        }
        
        String outputFile = args[0];
        
        try {
            String htmlContent = generateHtml();
            Files.write(Paths.get(outputFile), htmlContent.getBytes());
            System.out.println("HTML file generated successfully: " + outputFile);
        } catch (IOException e) {
            System.err.println("Error writing file: " + e.getMessage());
            System.exit(1);
        }
    }
    
    private static String generateHtml() {
        StringBuilder html = new StringBuilder();
        
        // DOCTYPE
        html.append("<!DOCTYPE html>\n");
        
        // HTML opening tag
        html.append("<html lang=\"en\">\n");
        
        // HEAD section
        html.append("  <head>\n");
        html.append("    <meta charset=\"UTF-8\" />\n");
        html.append("    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />\n");
        html.append("    <title>OpenClaw Control</title>\n");
        html.append("    <meta name=\"color-scheme\" content=\"dark light\" />\n");
        html.append("    <link rel=\"icon\" type=\"image/svg+xml\" href=\"/favicon.svg\" />\n");
        html.append("    <link rel=\"icon\" type=\"image/png\" sizes=\"32x32\" href=\"/favicon-32.png\" />\n");
        html.append("    <link rel=\"apple-touch-icon\" sizes=\"180x180\" href=\"/apple-touch-icon.png\" />\n");
        
        // Script tag with JavaScript
        html.append("    <script>\n");
        html.append("      (function () {\n");
        html.append("        var THEMES = { claw: 1, knot: 1, dash: 1 };\n");
        html.append("        var MODES = { system: 1, light: 1, dark: 1 };\n");
        html.append("        var LEGACY = {\n");
        html.append("          dark: \"claw:dark\",\n");
        html.append("          light: \"claw:light\",\n");
        html.append("          openknot: \"knot:dark\",\n");
        html.append("          fieldmanual: \"dash:dark\",\n");
        html.append("          clawdash: \"dash:light\",\n");
        html.append("          system: \"claw:system\",\n");
        html.append("        };\n");
        html.append("        try {\n");
        html.append("          var keys = Object.keys(localStorage);\n");
        html.append("          var raw;\n");
        html.append("          for (var i = 0; i < keys.length; i++) {\n");
        html.append("            if (keys[i].indexOf(\"openclaw.control.settings.v1\") === 0) {\n");
        html.append("              raw = localStorage.getItem(keys[i]);\n");
        html.append("              if (raw) break;\n");
        html.append("            }\n");
        html.append("          }\n");
        html.append("          if (!raw) return;\n");
        html.append("          var s = JSON.parse(raw);\n");
        html.append("          var t = s && s.theme;\n");
        html.append("          var m = s && s.themeMode;\n");
        html.append("          if (typeof t !== \"string\") t = \"\";\n");
        html.append("          if (typeof m !== \"string\") m = \"\";\n");
        html.append("          var legacy = LEGACY[t];\n");
        html.append("          var theme = THEMES[t] ? t : legacy ? legacy.split(\":\")[0] : \"claw\";\n");
        html.append("          var mode = MODES[m] ? m : legacy ? legacy.split(\":\")[1] : \"system\";\n");
        html.append("          if (mode === \"system\") {\n");
        html.append("            mode = window.matchMedia(\"(prefers-color-scheme: light)\").matches ? \"light\" : \"dark\";\n");
        html.append("          }\n");
        html.append("          var resolved =\n");
        html.append("            theme === \"knot\"\n");
        html.append("              ? mode === \"light\"\n");
        html.append("                ? \"openknot-light\"\n");
        html.append("                : \"openknot\"\n");
        html.append("              : theme === \"dash\"\n");
        html.append("                ? mode === \"light\"\n");
        html.append("                  ? \"dash-light\"\n");
        html.append("                  : \"dash\"\n");
        html.append("                : mode === \"light\"\n");
        html.append("                  ? \"light\"\n");
        html.append("                  : \"dark\";\n");
        html.append("          document.documentElement.setAttribute(\"data-theme\", resolved);\n");
        html.append("          document.documentElement.setAttribute(\n");
        html.append("            \"data-theme-mode\",\n");
        html.append("            resolved.indexOf(\"light\") !== -1 ? \"light\" : \"dark\",\n");
        html.append("          );\n");
        html.append("        } catch (e) {}\n");
        html.append("      })();\n");
        html.append("    </script>\n");
        html.append("  </head>\n");
        
        // BODY section
        html.append("  <body>\n");
        html.append("    <openclaw-app></openclaw-app>\n");
        html.append("    <script type=\"module\" src=\"/src/main.ts\"></script>\n");
        html.append("  </body>\n");
        
        // Close HTML tag
        html.append("</html>\n");
        
        return html.toString();
    }
}
