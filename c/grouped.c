// abstraction-provenance: {"artifact_sha256": "dd3ebe33ba096bdf8d4f4c0c3ef4656172196a3a9f52892283d3fa7396107ef0", "source_sha256": "be7071091b8a4e461f665879c436317756f6591f0bcf132f78e03c8b0bb8eb0d", "target_language": "c"}
// grouped.css — portiert nach c
// Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat/grouped.css
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void write_css_rule(FILE *file, const char *selector, const char *properties) {
    fprintf(file, "%s {\n%s}\n\n", selector, properties);
}

void write_media_rule(FILE *file, const char *condition, const char *rules) {
    fprintf(file, "@media %s {\n%s}\n\n", condition, rules);
}

void write_keyframes_rule(FILE *file, const char *name, const char *keyframes) {
    fprintf(file, "@keyframes %s {\n%s}\n\n", name, keyframes);
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <output_file>\n", argv[0]);
        return 1;
    }

    FILE *output_file = fopen(argv[1], "w");
    if (!output_file) {
        perror("Error opening file");
        return 1;
    }

    // Write comment header
    fprintf(output_file, "/* =============================================\n");
    fprintf(output_file, "   GROUPED CHAT LAYOUT (Slack-style)\n");
    fprintf(output_file, "   ============================================= */\n\n");

    // Chat Group Layout - default (assistant/other on left)
    write_css_rule(output_file, ".chat-group", 
        "  display: flex;\n"
        "  gap: 10px;\n"
        "  align-items: flex-start;\n"
        "  margin-bottom: 14px;\n"
        "  margin-left: 4px;\n"
        "  margin-right: 16px;\n");

    // User messages on right
    write_css_rule(output_file, ".chat-group.user", 
        "  flex-direction: row-reverse;\n"
        "  justify-content: flex-start;\n");

    write_css_rule(output_file, ".chat-group-messages", 
        "  display: flex;\n"
        "  flex-direction: column;\n"
        "  gap: 2px;\n"
        "  flex: 1 1 auto;\n"
        "  max-width: min(900px, 68%);\n"
        "  align-items: flex-start;\n");

    // User messages align content right
    write_css_rule(output_file, ".chat-group.user .chat-group-messages", 
        "  align-items: flex-end;\n");

    write_css_rule(output_file, ".chat-group.user .chat-group-footer", 
        "  justify-content: flex-end;\n");

    // Footer at bottom of message group (role + time)
    write_css_rule(output_file, ".chat-group-footer", 
        "  display: flex;\n"
        "  gap: 8px;\n"
        "  align-items: baseline;\n"
        "  margin-top: 6px;\n");

    write_css_rule(output_file, ".chat-sender-name", 
        "  font-weight: 500;\n"
        "  font-size: 12px;\n"
        "  color: var(--muted);\n");

    write_css_rule(output_file, ".chat-group-timestamp", 
        "  font-size: 11px;\n"
        "  color: var(--muted);\n"
        "  opacity: 0.7;\n");

    // Group footer action buttons (TTS, delete)
    write_css_rule(output_file, ".chat-group-footer button", 
        "  background: none;\n"
        "  border: none;\n"
        "  cursor: pointer;\n"
        "  padding: 4px;\n"
        "  min-width: 24px;\n"
        "  min-height: 24px;\n"
        "  border-radius: var(--radius-sm, 4px);\n"
        "  color: var(--muted);\n"
        "  opacity: 0;\n"
        "  pointer-events: none;\n"
        "  transition:\n"
        "    opacity 120ms ease-out,\n"
        "    color 120ms ease-out,\n"
        "    background 120ms ease-out;\n"
        "  display: inline-flex;\n"
        "  align-items: center;\n"
        "  justify-content: center;\n");

    write_css_rule(output_file, ".chat-group:hover .chat-group-footer button", 
        "  opacity: 0.6;\n"
        "  pointer-events: auto;\n");

    write_css_rule(output_file, ".chat-group-footer button:hover", 
        "  opacity: 1 !important;\n"
        "  background: var(--bg-hover, rgba(255, 255, 255, 0.08));\n");

    write_css_rule(output_file, ".chat-group-footer button svg", 
        "  width: 14px;\n"
        "  height: 14px;\n"
        "  fill: none;\n"
        "  stroke: currentColor;\n"
        "  stroke-width: 2;\n"
        "  stroke-linecap: round;\n"
        "  stroke-linejoin: round;\n");

    write_css_rule(output_file, ".chat-tts-btn--active", 
        "  opacity: 1 !important;\n"
        "  pointer-events: auto !important;\n"
        "  color: var(--accent);\n");

    write_css_rule(output_file, ".chat-group-delete:hover", 
        "  color: var(--danger) !important;\n");

    // Chat divider (e.g., compaction marker)
    write_css_rule(output_file, ".chat-divider", 
        "  display: flex;\n"
        "  align-items: center;\n"
        "  gap: 10px;\n"
        "  margin: 18px 8px;\n"
        "  color: var(--muted);\n"
        "  font-size: 11px;\n"
        "  letter-spacing: 0.08em;\n"
        "  text-transform: uppercase;\n"
        "  user-select: none;\n");

    write_css_rule(output_file, ".chat-divider__line", 
        "  flex: 1 1 0;\n"
        "  height: 1px;\n"
        "  background: var(--border);\n"
        "  opacity: 0.9;\n");

    write_css_rule(output_file, ".chat-divider__label", 
        "  padding: 2px 10px;\n"
        "  border: 1px solid var(--border);\n"
        "  border-radius: var(--radius-full);\n"
        "  background: rgba(255, 255, 255, 0.02);\n");

    // Avatar Styles
    write_css_rule(output_file, ".chat-avatar", 
        "  width: 36px;\n"
        "  height: 36px;\n"
        "  border-radius: var(--radius-md);\n"
        "  background: var(--panel-strong);\n"
        "  display: grid;\n"
        "  place-items: center;\n"
        "  font-weight: 600;\n"
        "  font-size: 13px;\n"
        "  flex-shrink: 0;\n"
        "  align-self: flex-end;\n"
        "  margin-bottom: 4px;\n"
        "  border: 1px solid var(--border);\n");

    write_css_rule(output_file, ".chat-avatar.user", 
        "  background: var(--accent-subtle);\n"
        "  color: var(--accent);\n"
        "  border-color: color-mix(in srgb, var(--accent) 20%, transparent);\n");

    write_css_rule(output_file, ".chat-avatar.assistant", 
        "  background: var(--secondary);\n"
        "  color: var(--muted);\n");

    write_css_rule(output_file, ".chat-avatar.other", 
        "  background: var(--secondary);\n"
        "  color: var(--muted);\n");

    write_css_rule(output_file, ".chat-avatar.tool", 
        "  background: var(--secondary);\n"
        "  color: var(--muted);\n");

    // Image avatar support
    write_css_rule(output_file, "img.chat-avatar", 
        "  display: block;\n"
        "  object-fit: cover;\n"
        "  object-position: center;\n");

    // Minimal Bubble Design - dynamic width based on content
    write_css_rule(output_file, ".chat-bubble", 
        "  position: relative;\n"
        "  display: block;\n"
        "  border: 1px solid var(--border);\n"
        "  background: var(--card);\n"
        "  border-radius: var(--radius-lg);\n"
        "  padding: 10px 14px;\n"
        "  box-shadow: none;\n"
        "  transition:\n"
        "    background var(--duration-fast) ease-out,\n"
        "    border-color var(--duration-fast) ease-out;\n"
        "  width: auto;\n"
        "  max-width: 100%;\n"
        "  box-sizing: border-box;\n"
        "  word-wrap: break-word;\n");

    write_css_rule(output_file, ".chat-bubble.has-copy", 
        "  padding-right: 70px;\n");

    write_css_rule(output_file, ".chat-bubble-actions", 
        "  position: absolute;\n"
        "  top: 6px;\n"
        "  right: 8px;\n"
        "  display: flex;\n"
        "  gap: 4px;\n"
        "  opacity: 0;\n"
        "  pointer-events: none;\n"
        "  transition: opacity 120ms ease-out;\n");

    write_css_rule(output_file, ".chat-bubble:hover .chat-bubble-actions", 
        "  opacity: 1;\n"
        "  pointer-events: auto;\n");

    // Media query for hover none
    const char *hover_none_rules = 
        "  .chat-bubble-actions {\n"
        "    opacity: 1;\n"
        "    pointer-events: auto;\n"
        "  }\n";
    write_media_rule(output_file, "(hover: none)", hover_none_rules);

    write_css_rule(output_file, ".chat-copy-btn,\n.chat-expand-btn", 
        "  background: var(--bg);\n"
        "  color: var(--muted);\n");

    write_css_rule(output_file, ".chat-copy-btn__icon", 
        "  display: inline-flex;\n"
        "  width: 14px;\n"
        "  height: 14px;\n"
        "  position: relative;\n");

    write_css_rule(output_file, ".chat-copy-btn__icon svg,\n.chat-expand-btn__icon svg", 
        "  width: 14px;\n"
        "  height: 14px;\n");

    write_css_rule(output_file, ".chat-copy-btn__icon-copy,\n.chat-copy-btn__icon-check", 
        "  position: absolute;\n"
        "  top: 0;\n"
        "  left: 0;\n"
        "  transition: opacity 150ms ease;\n");

    write_css_rule(output_file, ".chat-copy-btn__icon-check", 
        "  opacity: 0;\n");

    write_css_rule(output_file, ".chat-copy-btn[data-copied=\"1\"] .chat-copy-btn__icon-copy", 
        "  opacity: 0;\n");

    write_css_rule(output_file, ".chat-copy-btn[data-copied=\"1\"] .chat-copy-btn__icon-check", 
        "  opacity: 1;\n");

    write_css_rule(output_file, ".chat-copy-btn[data-copying=\"1\"]", 
        "  opacity: 0;\n"
        "  pointer-events: none;\n");

    write_css_rule(output_file, ".chat-copy-btn[data-error=\"1\"]", 
        "  border-color: var(--danger-subtle);\n"
        "  background: var(--danger-subtle);\n"
        "  color: var(--danger);\n");

    write_css_rule(output_file, ".chat-copy-btn[data-copied=\"1\"]", 
        "  border-color: var(--ok-subtle);\n"
        "  background: var(--ok-subtle);\n"
        "  color: var(--ok);\n");

    write_css_rule(output_file, ".chat-copy-btn:focus-visible,\n.chat-expand-btn:focus-visible", 
        "  outline: 2px solid var(--accent);\n"
        "  outline-offset: 2px;\n");

    write_css_rule(output_file, ".chat-expand-btn__icon", 
        "  display: inline-flex;\n"
        "  width: 14px;\n"
        "  height: 14px;\n");

    // Light mode: restore borders
    write_css_rule(output_file, ":root[data-theme-mode=\"light\"] .chat-bubble", 
        "  border-color: var(--border);\n"
        "  box-shadow: inset 0 1px 0 var(--card-highlight);\n");

    write_css_rule(output_file, ".chat-bubble:hover", 
        "  background: var(--bg-hover);\n");

    // User bubbles have different styling
    write_css_rule(output_file, ".chat-group.user .chat-bubble", 
        "  background: var(--accent-subtle);\n"
        "  border-color: transparent;\n");

    write_css_rule(output_file, ":root[data-theme-mode=\"light\"] .chat-group.user .chat-bubble", 
        "  border-color: color-mix(in srgb, var(--accent) 20%, transparent);\n"
        "  background: var(--accent-subtle);\n");

    write_css_rule(output_file, ".chat-group.user .chat-bubble:hover", 
        "  background: color-mix(in srgb, var(--accent) 20%, transparent);\n");

    // Streaming animation
    write_css_rule(output_file, ".chat-bubble.streaming", 
        "  animation: pulsing-border 1.5s ease-out infinite;\n");

    const char *pulsing_border_keyframes = 
        "  0%,\n"
        "  100% {\n"
        "    border-color: var(--border);\n"
        "  }\n\n"
        "  50% {\n"
        "    border-color: var(--accent);\n"
        "  }\n";
    write_keyframes_rule(output_file, "pulsing-border", pulsing_border_keyframes);

    // Fade-in animation for new messages
    write_css_rule(output_file, ".chat-bubble.fade-in", 
        "  animation: fade-in 200ms ease-out;\n");

    const char *fade_in_keyframes = 
        "  from {\n"
        "    opacity: 0;\n"
        "    transform: translateY(4px);\n"
        "  }\n\n"
        "  to {\n"
        "    opacity: 1;\n"
        "    transform: translateY(0);\n"
        "  }\n";
    write_keyframes_rule(output_file, "fade-in", fade_in_keyframes);

    // Message metadata (tokens, cost, model, context %)
    write_css_rule(output_file, ".msg-meta", 
        "  display: inline-flex;\n"
        "  align-items: center;\n"
        "  gap: 8px;\n"
        "  font-size: 11px;\n"
        "  line-height: 1;\n"
        "  color: var(--muted);\n"
        "  margin-top: 4px;\n"
        "  flex-wrap: wrap;\n");

    write_css_rule(output_file, ".msg-meta__tokens,\n.msg-meta__cache,\n.msg-meta__cost,\n.msg-meta__ctx,\n.msg-meta__model", 
        "  display: inline-flex;\n"
        "  align-items: center;\n"
        "  gap: 2px;\n"
        "  white-space: nowrap;\n");

    write_css_rule(output_file, ".msg-meta__model", 
        "  background: var(--bg-hover, rgba(255, 255, 255, 0.06));\n"
        "  padding: 1px 6px;\n"
        "  border-radius: var(--radius-sm, 4px);\n"
        "  font-family: var(--font-mono, monospace);\n");

    write_css_rule(output_file, ".msg-meta__cost", 
        "  color: var(--ok);\n");

    write_css_rule(output_file, ".msg-meta__ctx--warn", 
        "  color: var(--warn);\n");

    write_css_rule(output_file, ".msg-meta__ctx--danger", 
        "  color: var(--danger);\n");

    // Delete confirmation popover
    write_css_rule(output_file, ".chat-delete-wrap", 
        "  position: relative;\n"
        "  display: inline-flex;\n");

    write_css_rule(output_file, ".chat-delete-confirm", 
        "  position: absolute;\n"
        "  bottom: calc(100% + 6px);\n"
        "  background: var(--card, #1a1a1a);\n"
        "  border: 1px solid var(--border, rgba(255, 255, 255, 0.1));\n"
        "  border-radius: var(--radius-md, 8px);\n"
        "  padding: 12px;\n"
        "  min-width: 200px;\n"
        "  max-width: calc(100vw - 48px);\n"
        "  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);\n"
        "  z-index: 100;\n"
        "  animation: scale-in 0.15s ease-out;\n");

    write_css_rule(output_file, ".chat-delete-confirm--left", 
        "  right: 0;\n");

    write_css_rule(output_file, ".chat-delete-confirm--right", 
        "  left: 0;\n");

    write_css_rule(output_file, ".chat-delete-confirm__text", 
        "  margin: 0 0 8px;\n"
        "  font-size: 13px;\n"
        "  font-weight: 500;\n"
        "  color: var(--fg, #fff);\n");

    write_css_rule(output_file, ".chat-delete-confirm__remember", 
        "  display: flex;\n"
        "  align-items: center;\n"
        "  gap: 6px;\n"
        "  font-size: 11px;\n"
        "  color: var(--muted, #888);\n"
        "  margin-bottom: 10px;\n"
        "  cursor: pointer;\n"
        "  user-select: none;\n");

    write_css_rule(output_file, ".chat-delete-confirm__check", 
        "  width: 14px;\n"
        "  height: 14px;\n"
        "  accent-color: var(--accent);\n"
        "  cursor: pointer;\n");

    write_css_rule(output_file, ".chat-delete-confirm__actions", 
        "  display: flex;\n"
        "  gap: 6px;\n"
        "  justify-content: flex-end;\n");

    write_css_rule(output_file, ".chat-delete-confirm__cancel,\n.chat-delete-confirm__yes", 
        "  border: none;\n"
        "  border-radius: var(--radius-sm, 4px);\n"
        "  padding: 4px 12px;\n"
        "  font-size: 12px;\n"
        "  font-weight: 500;\n"
        "  cursor: pointer;\n"
        "  transition: background 120ms ease-out;\n");

    write_css_rule(output_file, ".chat-delete-confirm__cancel", 
        "  background: var(--bg-hover, rgba(255, 255, 255, 0.08));\n"
        "  color: var(--muted, #888);\n");

    write_css_rule(output_file, ".chat-delete-confirm__cancel:hover", 
        "  background: rgba(255, 255, 255, 0.12);\n");

    write_css_rule(output_file, ".chat-delete-confirm__yes", 
        "  background: var(--danger);\n"
        "  color: #fff;\n");

    write_css_rule(output_file, ".chat-delete-confirm__yes:hover", 
        "  background: #dc2626;\n");

    // Media queries for responsive design
    const char *tablet_rules = 
        "  .chat-group {\n"
        "    margin-left: 0;\n"
        "    margin-right: 0;\n"
        "  }\n\n"
        "  .chat-group-messages {\n"
        "    max-width: 82%;\n"
        "  }\n";
    write_media_rule(output_file, "(max-width: 768px)", tablet_rules);

    const char *mobile_rules = 
        "  .chat-group-messages {\n"
        "    max-width: 100%;\n"
        "  }\n\n"
        "  .chat-avatar,\n"
        "  img.chat-avatar {\n"
        "    display: none;\n"
        "  }\n";
    write_media_rule(output_file, "(max-width: 400px)", mobile_rules);

    fclose(output_file);
    return 0;
}
