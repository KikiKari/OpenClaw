// abstraction-provenance: {"artifact_sha256": "97c1c52144bda7e91b0cb47df1b026226cc565f530649076194bbf1acbe4879a", "source_sha256": "c2445d9bf4b0ccf8c05eb944692addc1436cc68504dfc0ab9e6677d90ced3ec9", "target_language": "c"}
// index.html — portiert nach c
// Quelle: html, workspace@local:skills/github-clones/openclaw/ui/index.html
// auch in: openclaw-css@local:workspace/skills/github-clones/openclaw/ui/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void write_index_html(const char* filename) {
    FILE* file = fopen(filename, "w");
    if (!file) {
        perror("Failed to open file");
        return;
    }

    fprintf(file, "<!doctype html>\n");
    fprintf(file, "<html lang=\"en\">\n");
    fprintf(file, "  <head>\n");
    fprintf(file, "    <meta charset=\"UTF-8\" />\n");
    fprintf(file, "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />\n");
    fprintf(file, "    <title>OpenClaw Control</title>\n");
    fprintf(file, "    <meta name=\"color-scheme\" content=\"dark light\" />\n");
    fprintf(file, "    <link rel=\"icon\" type=\"image/svg+xml\" href=\"/favicon.svg\" />\n");
    fprintf(file, "    <link rel=\"icon\" type=\"image/png\" sizes=\"32x32\" href=\"/favicon-32.png\" />\n");
    fprintf(file, "    <link rel=\"apple-touch-icon\" sizes=\"180x180\" href=\"/apple-touch-icon.png\" />\n");
    fprintf(file, "    <script>\n");
    fprintf(file, "      (function () {\n");
    fprintf(file, "        var THEMES = { claw: 1, knot: 1, dash: 1 };\n");
    fprintf(file, "        var MODES = { system: 1, light: 1, dark: 1 };\n");
    fprintf(file, "        var LEGACY = {\n");
    fprintf(file, "          dark: \"claw:dark\",\n");
    fprintf(file, "          light: \"claw:light\",\n");
    fprintf(file, "          openknot: \"knot:dark\",\n");
    fprintf(file, "          fieldmanual: \"dash:dark\",\n");
    fprintf(file, "          clawdash: \"dash:light\",\n");
    fprintf(file, "          system: \"claw:system\",\n");
    fprintf(file, "        };\n");
    fprintf(file, "        try {\n");
    fprintf(file, "          var keys = Object.keys(localStorage);\n");
    fprintf(file, "          var raw;\n");
    fprintf(file, "          for (var i = 0; i < keys.length; i++) {\n");
    fprintf(file, "            if (keys[i].indexOf(\"openclaw.control.settings.v1\") === 0) {\n");
    fprintf(file, "              raw = localStorage.getItem(keys[i]);\n");
    fprintf(file, "              if (raw) break;\n");
    fprintf(file, "            }\n");
    fprintf(file, "          }\n");
    fprintf(file, "          if (!raw) return;\n");
    fprintf(file, "          var s = JSON.parse(raw);\n");
    fprintf(file, "          var t = s && s.theme;\n");
    fprintf(file, "          var m = s && s.themeMode;\n");
    fprintf(file, "          if (typeof t !== \"string\") t = \"\";\n");
    fprintf(file, "          if (typeof m !== \"string\") m = \"\";\n");
    fprintf(file, "          var legacy = LEGACY[t];\n");
    fprintf(file, "          var theme = THEMES[t] ? t : legacy ? legacy.split(\":\")[0] : \"claw\";\n");
    fprintf(file, "          var mode = MODES[m] ? m : legacy ? legacy.split(\":\")[1] : \"system\";\n");
    fprintf(file, "          if (mode === \"system\") {\n");
    fprintf(file, "            mode = window.matchMedia(\"(prefers-color-scheme: light)\").matches ? \"light\" : \"dark\";\n");
    fprintf(file, "          }\n");
    fprintf(file, "          var resolved =\n");
    fprintf(file, "            theme === \"knot\"\n");
    fprintf(file, "              ? mode === \"light\"\n");
    fprintf(file, "                ? \"openknot-light\"\n");
    fprintf(file, "                : \"openknot\"\n");
    fprintf(file, "              : theme === \"dash\"\n");
    fprintf(file, "                ? mode === \"light\"\n");
    fprintf(file, "                  ? \"dash-light\"\n");
    fprintf(file, "                  : \"dash\"\n");
    fprintf(file, "                : mode === \"light\"\n");
    fprintf(file, "                  ? \"light\"\n");
    fprintf(file, "                  : \"dark\";\n");
    fprintf(file, "          document.documentElement.setAttribute(\"data-theme\", resolved);\n");
    fprintf(file, "          document.documentElement.setAttribute(\n");
    fprintf(file, "            \"data-theme-mode\",\n");
    fprintf(file, "            resolved.indexOf(\"light\") !== -1 ? \"light\" : \"dark\",\n");
    fprintf(file, "          );\n");
    fprintf(file, "        } catch (e) {}\n");
    fprintf(file, "      })();\n");
    fprintf(file, "    </script>\n");
    fprintf(file, "  </head>\n");
    fprintf(file, "  <body>\n");
    fprintf(file, "    <openclaw-app></openclaw-app>\n");
    fprintf(file, "    <script type=\"module\" src=\"/src/main.ts\"></script>\n");
    fprintf(file, "  </body>\n");
    fprintf(file, "</html>\n");

    fclose(file);
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <output_filename>\n", argv[0]);
        return 1;
    }

    write_index_html(argv[1]);
    return 0;
}
