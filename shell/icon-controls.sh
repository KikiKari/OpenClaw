#!/bin/bash
# icon-controls.css — portiert nach shell
# Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/icon-controls.css
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/icon-controls.css
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/icon-controls.css
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/icon-controls.css
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Function to generate CSS for a specific icon style
generate_icon_style() {
    local style="$1"
    cat <<EOF
html[data-icon-style="$style"] {
EOF

    # Define all icons with their respective paths
    local icons=(
        "auto-chat-refresh-counter:auto-chat-refresh-counter.png"
        "browser:browser.png"
        "captions:captions.png"
        "chat-counter:chat-counter.png"
        "fullscreen:fullscreen.png"
        "mute:mute.png"
        "off:off.png"
        "on:on.png"
        "pip:pip.png"
        "play:play.png"
        "player:player.png"
        "protection-slider:protection-slider.png"
        "recommendation-counter:recommendation-counter.png"
        "report:report.png"
        "reset:reset.png"
        "settings:settings.png"
        "status:status.png"
        "stop:stop.png"
        "unmute:unmute.png"
        "volume-slider:volume-slider.png"
    )

    # Generate each icon variable
    for icon in "${icons[@]}"; do
        local name="${icon%%:*}"
        local file="${icon##*:}"
        echo "  --icon-$name:url(\"icons/$style/$file\");"
    done

    echo "}"
}

# Main function to generate the complete CSS
generate_css() {
    # Generate styles for each theme
    generate_icon_style "plastisch"
    echo
    generate_icon_style "glass"
    echo
    generate_icon_style "linear"
    echo

    # Common control styles
    cat <<'EOF'
button[data-control-icon]::before,
.control-icon::before {
  content: "";
  display: inline-block;
  width: 32px;
  height: 32px;
  flex: 0 0 32px;
  background: var(--control-icon) center/contain no-repeat;
  vertical-align: middle;
  margin-inline-end: 0;
  pointer-events: none;
}

button[data-control-icon] {
  min-height: 44px;
  min-width: 44px;
  font-size: 0;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

button[data-control-icon][hidden] {
  display: none;
}

input[type="checkbox"] {
  appearance: none;
  -webkit-appearance: none;
  width: 44px;
  height: 44px;
  min-width: 44px;
  border: 0;
  background: var(--icon-off) center/40px no-repeat;
  cursor: pointer;
  vertical-align: middle;
}

input[type="checkbox"]:checked {
  background-image: var(--icon-on);
}

input[type="checkbox"]:focus-visible,
button[data-control-icon]:focus-visible {
  outline: 2px solid #1769df;
  outline-offset: 2px;
}

input[type="checkbox"]:disabled {
  opacity: .45;
  cursor: default;
}

.control-icon {
  display: inline-flex;
  align-items: center;
}

input[type="range"] {
  min-height: 32px;
}

.icon-style-setting {
  display: flex;
  align-items: center;
  gap: 8px;
}

EOF

    # Icon mappings
    local icon_names=(
        "auto-chat-refresh-counter" "browser" "captions" "chat-counter"
        "fullscreen" "mute" "off" "on" "pip" "play" "player"
        "protection-slider" "recommendation-counter" "report"
        "reset" "settings" "status" "stop" "unmute" "volume-slider"
    )

    for name in "${icon_names[@]}"; do
        echo "[data-control-icon=\"$name\"] { --control-icon:var(--icon-$name); }"
    done
}

# Check if output file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <output-file>"
    exit 1
fi

# Generate CSS and write to file
generate_css > "$1"
