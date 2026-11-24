// abstraction-provenance: {"artifact_sha256": "eddb41010f35f9a64a7e14d198cfb6d943d445141b431370c4a8b0e9321c15f0", "source_sha256": "fce23ec10c43acef00ba36b3975889539f87b908bd4cfce77616443d2b5f569e", "target_language": "cpp"}
// icon-controls.css — portiert nach cpp
// Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/icon-controls.css
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/icon-controls.css
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/icon-controls.css
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/icon-controls.css
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <string>
#include <map>
#include <vector>

class CSSGenerator {
private:
    struct IconStyle {
        std::string name;
        std::string path;
    };
    
    std::vector<IconStyle> iconStyles = {
        {"plastisch", "plastisch"},
        {"glass", "glass"},
        {"linear", "linear"}
    };
    
    std::vector<std::string> iconNames = {
        "auto-chat-refresh-counter",
        "browser",
        "captions",
        "chat-counter",
        "fullscreen",
        "mute",
        "off",
        "on",
        "pip",
        "play",
        "player",
        "protection-slider",
        "recommendation-counter",
        "report",
        "reset",
        "settings",
        "status",
        "stop",
        "unmute",
        "volume-slider"
    };

public:
    std::string generateCSS() {
        std::string css;
        
        // Generate icon style definitions
        for (const auto& style : iconStyles) {
            css += "html[data-icon-style=\"" + style.name + "\"] {";
            for (const auto& iconName : iconNames) {
                css += "--icon-" + iconName + ":url(\"icons/" + style.path + "/" + iconName + ".png\");";
            }
            css += "}\n";
        }
        
        // Add generic styles
        css += "button[data-control-icon]::before,.control-icon::before { content:\"\"; display:inline-block; width:32px; height:32px; flex:0 0 32px; background:var(--control-icon) center/contain no-repeat; vertical-align:middle; margin-inline-end:0; pointer-events:none; }\n";
        css += "button[data-control-icon] { min-height:44px; min-width:44px; font-size:0; display:inline-flex; align-items:center; justify-content:center; }\n";
        css += "button[data-control-icon][hidden] { display:none; }\n";
        css += "input[type=\"checkbox\"] { appearance:none; -webkit-appearance:none; width:44px; height:44px; min-width:44px; border:0; background:var(--icon-off) center/40px no-repeat; cursor:pointer; vertical-align:middle; }\n";
        css += "input[type=\"checkbox\"]:checked { background-image:var(--icon-on); }\n";
        css += "input[type=\"checkbox\"]:focus-visible,button[data-control-icon]:focus-visible { outline:2px solid #1769df; outline-offset:2px; }\n";
        css += "input[type=\"checkbox\"]:disabled { opacity:.45; cursor:default; }\n";
        css += ".control-icon { display:inline-flex; align-items:center; }\n";
        css += "input[type=\"range\"] { min-height:32px; }\n";
        css += ".icon-style-setting { display:flex; align-items:center; gap:8px; }\n";
        
        // Add control icon mappings
        for (const auto& iconName : iconNames) {
            css += "[data-control-icon=\"" + iconName + "\"] { --control-icon:var(--icon-" + iconName + "); }\n";
        }
        
        return css;
    }
    
    bool writeToFile(const std::string& filename) {
        std::ofstream file(filename);
        if (!file.is_open()) {
            return false;
        }
        
        file << generateCSS();
        file.close();
        return true;
    }
};

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <output-file>" << std::endl;
        return 1;
    }
    
    CSSGenerator generator;
    if (!generator.writeToFile(argv[1])) {
        std::cerr << "Error writing to file: " << argv[1] << std::endl;
        return 1;
    }
    
    return 0;
}
