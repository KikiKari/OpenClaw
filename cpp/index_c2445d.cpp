// abstraction-provenance: {"artifact_sha256": "061b3273ea17f81f071d36ce525b85821183e8858c660705b10feab4a4b59535", "source_sha256": "c2445d9bf4b0ccf8c05eb944692addc1436cc68504dfc0ab9e6677d90ced3ec9", "target_language": "cpp"}
// index.html — portiert nach cpp
// Quelle: html, workspace@local:skills/github-clones/openclaw/ui/index.html
// auch in: openclaw-css@local:workspace/skills/github-clones/openclaw/ui/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <string>
#include <map>
#include <sstream>

void generateHTML(const std::string& filename) {
    std::ofstream file(filename);
    if (!file.is_open()) {
        std::cerr << "Error: Could not open file " << filename << " for writing." << std::endl;
        return;
    }

    // Write doctype
    file << "<!DOCTYPE html>" << std::endl;
    
    // Start html tag
    file << "<html lang=\"en\">" << std::endl;
    
    // Head section
    file << "  <head>" << std::endl;
    file << "    <meta charset=\"UTF-8\" />" << std::endl;
    file << "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />" << std::endl;
    file << "    <title>OpenClaw Control</title>" << std::endl;
    file << "    <meta name=\"color-scheme\" content=\"dark light\" />" << std::endl;
    file << "    <link rel=\"icon\" type=\"image/svg+xml\" href=\"/favicon.svg\" />" << std::endl;
    file << "    <link rel=\"icon\" type=\"image/png\" sizes=\"32x32\" href=\"/favicon-32.png\" />" << std::endl;
    file << "    <link rel=\"apple-touch-icon\" sizes=\"180x180\" href=\"/apple-touch-icon.png\" />" << std::endl;
    
    // JavaScript section
    file << "    <script>" << std::endl;
    file << "      (function () {" << std::endl;
    file << "        var THEMES = { claw: 1, knot: 1, dash: 1 };" << std::endl;
    file << "        var MODES = { system: 1, light: 1, dark: 1 };" << std::endl;
    file << "        var LEGACY = {" << std::endl;
    file << "          dark: \"claw:dark\"," << std::endl;
    file << "          light: \"claw:light\"," << std::endl;
    file << "          openknot: \"knot:dark\"," << std::endl;
    file << "          fieldmanual: \"dash:dark\"," << std::endl;
    file << "          clawdash: \"dash:light\"," << std::endl;
    file << "          system: \"claw:system\"," << std::endl;
    file << "        };" << std::endl;
    file << "        try {" << std::endl;
    file << "          var keys = Object.keys(localStorage);" << std::endl;
    file << "          var raw;" << std::endl;
    file << "          for (var i = 0; i < keys.length; i++) {" << std::endl;
    file << "            if (keys[i].indexOf(\"openclaw.control.settings.v1\") === 0) {" << std::endl;
    file << "              raw = localStorage.getItem(keys[i]);" << std::endl;
    file << "              if (raw) break;" << std::endl;
    file << "            }" << std::endl;
    file << "          }" << std::endl;
    file << "          if (!raw) return;" << std::endl;
    file << "          var s = JSON.parse(raw);" << std::endl;
    file << "          var t = s && s.theme;" << std::endl;
    file << "          var m = s && s.themeMode;" << std::endl;
    file << "          if (typeof t !== \"string\") t = \"\";" << std::endl;
    file << "          if (typeof m !== \"string\") m = \"\";" << std::endl;
    file << "          var legacy = LEGACY[t];" << std::endl;
    file << "          var theme = THEMES[t] ? t : legacy ? legacy.split(\":\")[0] : \"claw\";" << std::endl;
    file << "          var mode = MODES[m] ? m : legacy ? legacy.split(\":\")[1] : \"system\";" << std::endl;
    file << "          if (mode === \"system\") {" << std::endl;
    file << "            mode = window.matchMedia(\"(prefers-color-scheme: light)\").matches ? \"light\" : \"dark\";" << std::endl;
    file << "          }" << std::endl;
    file << "          var resolved =" << std::endl;
    file << "            theme === \"knot\"" << std::endl;
    file << "              ? mode === \"light\"" << std::endl;
    file << "                ? \"openknot-light\"" << std::endl;
    file << "                : \"openknot\"" << std::endl;
    file << "              : theme === \"dash\"" << std::endl;
    file << "                ? mode === \"light\"" << std::endl;
    file << "                  ? \"dash-light\"" << std::endl;
    file << "                  : \"dash\"" << std::endl;
    file << "                : mode === \"light\"" << std::endl;
    file << "                  ? \"light\"" << std::endl;
    file << "                  : \"dark\";" << std::endl;
    file << "          document.documentElement.setAttribute(\"data-theme\", resolved);" << std::endl;
    file << "          document.documentElement.setAttribute(" << std::endl;
    file << "            \"data-theme-mode\"," << std::endl;
    file << "            resolved.indexOf(\"light\") !== -1 ? \"light\" : \"dark\"," << std::endl;
    file << "          );" << std::endl;
    file << "        } catch (e) {}" << std::endl;
    file << "      })();" << std::endl;
    file << "    </script>" << std::endl;
    
    // End head
    file << "  </head>" << std::endl;
    
    // Body section
    file << "  <body>" << std::endl;
    file << "    <openclaw-app></openclaw-app>" << std::endl;
    file << "    <script type=\"module\" src=\"/src/main.ts\"></script>" << std::endl;
    file << "  </body>" << std::endl;
    
    // End html
    file << "</html>" << std::endl;
    
    file.close();
}

int main(int argc, char* argv[]) {
    std::string filename = "index.html";
    
    if (argc > 1) {
        filename = argv[1];
    }
    
    generateHTML(filename);
    
    return 0;
}
