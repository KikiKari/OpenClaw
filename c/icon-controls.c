// abstraction-provenance: {"artifact_sha256": "46cf6d9cdfe45676088d1168c59604edb253f127f2f4399896a210d29bd63b6b", "source_sha256": "fce23ec10c43acef00ba36b3975889539f87b908bd4cfce77616443d2b5f569e", "target_language": "c"}
// icon-controls.css — portiert nach c
// Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/icon-controls.css
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/icon-controls.css
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/icon-controls.css
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/icon-controls.css
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    const char* name;
    const char* plastisch_path;
    const char* glass_path;
    const char* linear_path;
} IconDefinition;

static const IconDefinition icons[] = {
    {"auto-chat-refresh-counter", "auto-chat-refresh-counter.png", "auto-chat-refresh-counter.png", "auto-chat-refresh-counter.png"},
    {"browser", "browser.png", "browser.png", "browser.png"},
    {"captions", "captions.png", "captions.png", "captions.png"},
    {"chat-counter", "chat-counter.png", "chat-counter.png", "chat-counter.png"},
    {"fullscreen", "fullscreen.png", "fullscreen.png", "fullscreen.png"},
    {"mute", "mute.png", "mute.png", "mute.png"},
    {"off", "off.png", "off.png", "off.png"},
    {"on", "on.png", "on.png", "on.png"},
    {"pip", "pip.png", "pip.png", "pip.png"},
    {"play", "play.png", "play.png", "play.png"},
    {"player", "player.png", "player.png", "player.png"},
    {"protection-slider", "protection-slider.png", "protection-slider.png", "protection-slider.png"},
    {"recommendation-counter", "recommendation-counter.png", "recommendation-counter.png", "recommendation-counter.png"},
    {"report", "report.png", "report.png", "report.png"},
    {"reset", "reset.png", "reset.png", "reset.png"},
    {"settings", "settings.png", "settings.png", "settings.png"},
    {"status", "status.png", "status.png", "status.png"},
    {"stop", "stop.png", "stop.png", "stop.png"},
    {"unmute", "unmute.png", "unmute.png", "unmute.png"},
    {"volume-slider", "volume-slider.png", "volume-slider.png", "volume-slider.png"}
};

static const int icon_count = sizeof(icons) / sizeof(IconDefinition);

void write_css_for_style(FILE* file, const char* style_name, const char* directory) {
    fprintf(file, "html[data-icon-style=\"%s\"] {", style_name);
    
    for (int i = 0; i < icon_count; i++) {
        fprintf(file, "--icon-%s:url(\"icons/%s/%s\");", 
                icons[i].name, directory, icons[i].name);
    }
    
    fprintf(file, "}\n");
}

void write_control_styles(FILE* file) {
    fprintf(file, "button[data-control-icon]::before,.control-icon::before { content:\"\"; display:inline-block; width:32px; height:32px; flex:0 0 32px; background:var(--control-icon) center/contain no-repeat; vertical-align:middle; margin-inline-end:0; pointer-events:none; }\n");
    fprintf(file, "button[data-control-icon] { min-height:44px; min-width:44px; font-size:0; display:inline-flex; align-items:center; justify-content:center; }\n");
    fprintf(file, "button[data-control-icon][hidden] { display:none; }\n");
    fprintf(file, "input[type=\"checkbox\"] { appearance:none; -webkit-appearance:none; width:44px; height:44px; min-width:44px; border:0; background:var(--icon-off) center/40px no-repeat; cursor:pointer; vertical-align:middle; }\n");
    fprintf(file, "input[type=\"checkbox\"]:checked { background-image:var(--icon-on); }\n");
    fprintf(file, "input[type=\"checkbox\"]:focus-visible,button[data-control-icon]:focus-visible { outline:2px solid #1769df; outline-offset:2px; }\n");
    fprintf(file, "input[type=\"checkbox\"]:disabled { opacity:.45; cursor:default; }\n");
    fprintf(file, ".control-icon { display:inline-flex; align-items:center; }\n");
    fprintf(file, "input[type=\"range\"] { min-height:32px; }\n");
    fprintf(file, ".icon-style-setting { display:flex; align-items:center; gap:8px; }\n");
    
    for (int i = 0; i < icon_count; i++) {
        fprintf(file, "[data-control-icon=\"%s\"] { --control-icon:var(--icon-%s); }\n", 
                icons[i].name, icons[i].name);
    }
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <output-file>\n", argv[0]);
        return 1;
    }
    
    FILE* output = fopen(argv[1], "w");
    if (!output) {
        perror("Failed to open output file");
        return 1;
    }
    
    // Generate CSS for each style
    write_css_for_style(output, "plastisch", "plastisch");
    write_css_for_style(output, "glass", "glass");
    write_css_for_style(output, "linear", "linear");
    
    // Write control styles
    write_control_styles(output);
    
    fclose(output);
    return 0;
}
