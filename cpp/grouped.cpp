// abstraction-provenance: {"artifact_sha256": "77069c366b522e0a8512147ba01e412ed02d6a4c61b67367eb80f982bb3fd080", "source_sha256": "be7071091b8a4e461f665879c436317756f6591f0bcf132f78e03c8b0bb8eb0d", "target_language": "cpp"}
// grouped.css — portiert nach cpp
// Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat/grouped.css
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <string>

void writeCSS(std::ofstream& file) {
    file << "/* =============================================\n";
    file << "   GROUPED CHAT LAYOUT (Slack-style)\n";
    file << "   ============================================= */\n\n";
    
    file << "/* Chat Group Layout - default (assistant/other on left) */\n";
    file << ".chat-group {\n";
    file << "  display: flex;\n";
    file << "  gap: 10px;\n";
    file << "  align-items: flex-start;\n";
    file << "  margin-bottom: 14px;\n";
    file << "  margin-left: 4px;\n";
    file << "  margin-right: 16px;\n";
    file << "}\n\n";
    
    file << "/* User messages on right */\n";
    file << ".chat-group.user {\n";
    file << "  flex-direction: row-reverse;\n";
    file << "  justify-content: flex-start;\n";
    file << "}\n\n";
    
    file << ".chat-group-messages {\n";
    file << "  display: flex;\n";
    file << "  flex-direction: column;\n";
    file << "  gap: 2px;\n";
    file << "  flex: 1 1 auto;\n";
    file << "  max-width: min(900px, 68%);\n";
    file << "  align-items: flex-start;\n";
    file << "}\n\n";
    
    file << "/* User messages align content right */\n";
    file << ".chat-group.user .chat-group-messages {\n";
    file << "  align-items: flex-end;\n";
    file << "}\n\n";
    
    file << ".chat-group.user .chat-group-footer {\n";
    file << "  justify-content: flex-end;\n";
    file << "}\n\n";
    
    file << "/* Footer at bottom of message group (role + time) */\n";
    file << ".chat-group-footer {\n";
    file << "  display: flex;\n";
    file << "  gap: 8px;\n";
    file << "  align-items: baseline;\n";
    file << "  margin-top: 6px;\n";
    file << "}\n\n";
    
    file << ".chat-sender-name {\n";
    file << "  font-weight: 500;\n";
    file << "  font-size: 12px;\n";
    file << "  color: var(--muted);\n";
    file << "}\n\n";
    
    file << ".chat-group-timestamp {\n";
    file << "  font-size: 11px;\n";
    file << "  color: var(--muted);\n";
    file << "  opacity: 0.7;\n";
    file << "}\n\n";
    
    file << "/* ── Group footer action buttons (TTS, delete) ── */\n";
    file << ".chat-group-footer button {\n";
    file << "  background: none;\n";
    file << "  border: none;\n";
    file << "  cursor: pointer;\n";
    file << "  padding: 4px;\n";
    file << "  min-width: 24px;\n";
    file << "  min-height: 24px;\n";
    file << "  border-radius: var(--radius-sm, 4px);\n";
    file << "  color: var(--muted);\n";
    file << "  opacity: 0;\n";
    file << "  pointer-events: none;\n";
    file << "  transition:\n";
    file << "    opacity 120ms ease-out,\n";
    file << "    color 120ms ease-out,\n";
    file << "    background 120ms ease-out;\n";
    file << "  display: inline-flex;\n";
    file << "  align-items: center;\n";
    file << "  justify-content: center;\n";
    file << "}\n\n";
    
    file << ".chat-group:hover .chat-group-footer button {\n";
    file << "  opacity: 0.6;\n";
    file << "  pointer-events: auto;\n";
    file << "}\n\n";
    
    file << ".chat-group-footer button:hover {\n";
    file << "  opacity: 1 !important;\n";
    file << "  background: var(--bg-hover, rgba(255, 255, 255, 0.08));\n";
    file << "}\n\n";
    
    file << ".chat-group-footer button svg {\n";
    file << "  width: 14px;\n";
    file << "  height: 14px;\n";
    file << "  fill: none;\n";
    file << "  stroke: currentColor;\n";
    file << "  stroke-width: 2;\n";
    file << "  stroke-linecap: round;\n";
    file << "  stroke-linejoin: round;\n";
    file << "}\n\n";
    
    file << ".chat-tts-btn--active {\n";
    file << "  opacity: 1 !important;\n";
    file << "  pointer-events: auto !important;\n";
    file << "  color: var(--accent);\n";
    file << "}\n\n";
    
    file << ".chat-group-delete:hover {\n";
    file << "  color: var(--danger) !important;\n";
    file << "}\n\n";
    
    file << "/* Chat divider (e.g., compaction marker) */\n";
    file << ".chat-divider {\n";
    file << "  display: flex;\n";
    file << "  align-items: center;\n";
    file << "  gap: 10px;\n";
    file << "  margin: 18px 8px;\n";
    file << "  color: var(--muted);\n";
    file << "  font-size: 11px;\n";
    file << "  letter-spacing: 0.08em;\n";
    file << "  text-transform: uppercase;\n";
    file << "  user-select: none;\n";
    file << "}\n\n";
    
    file << ".chat-divider__line {\n";
    file << "  flex: 1 1 0;\n";
    file << "  height: 1px;\n";
    file << "  background: var(--border);\n";
    file << "  opacity: 0.9;\n";
    file << "}\n\n";
    
    file << ".chat-divider__label {\n";
    file << "  padding: 2px 10px;\n";
    file << "  border: 1px solid var(--border);\n";
    file << "  border-radius: var(--radius-full);\n";
    file << "  background: rgba(255, 255, 255, 0.02);\n";
    file << "}\n\n";
    
    file << "/* Avatar Styles */\n";
    file << ".chat-avatar {\n";
    file << "  width: 36px;\n";
    file << "  height: 36px;\n";
    file << "  border-radius: var(--radius-md);\n";
    file << "  background: var(--panel-strong);\n";
    file << "  display: grid;\n";
    file << "  place-items: center;\n";
    file << "  font-weight: 600;\n";
    file << "  font-size: 13px;\n";
    file << "  flex-shrink: 0;\n";
    file << "  align-self: flex-end;\n";
    file << "  margin-bottom: 4px;\n";
    file << "  border: 1px solid var(--border);\n";
    file << "}\n\n";
    
    file << ".chat-avatar.user {\n";
    file << "  background: var(--accent-subtle);\n";
    file << "  color: var(--accent);\n";
    file << "  border-color: color-mix(in srgb, var(--accent) 20%, transparent);\n";
    file << "}\n\n";
    
    file << ".chat-avatar.assistant {\n";
    file << "  background: var(--secondary);\n";
    file << "  color: var(--muted);\n";
    file << "}\n\n";
    
    file << ".chat-avatar.other {\n";
    file << "  background: var(--secondary);\n";
    file << "  color: var(--muted);\n";
    file << "}\n\n";
    
    file << ".chat-avatar.tool {\n";
    file << "  background: var(--secondary);\n";
    file << "  color: var(--muted);\n";
    file << "}\n\n";
    
    file << "/* Image avatar support */\n";
    file << "img.chat-avatar {\n";
    file << "  display: block;\n";
    file << "  object-fit: cover;\n";
    file << "  object-position: center;\n";
    file << "}\n\n";
    
    file << "/* Minimal Bubble Design - dynamic width based on content */\n";
    file << ".chat-bubble {\n";
    file << "  position: relative;\n";
    file << "  display: block;\n";
    file << "  border: 1px solid var(--border);\n";
    file << "  background: var(--card);\n";
    file << "  border-radius: var(--radius-lg);\n";
    file << "  padding: 10px 14px;\n";
    file << "  box-shadow: none;\n";
    file << "  transition:\n";
    file << "    background var(--duration-fast) ease-out,\n";
    file << "    border-color var(--duration-fast) ease-out;\n";
    file << "  width: auto;\n";
    file << "  max-width: 100%;\n";
    file << "  box-sizing: border-box;\n";
    file << "  word-wrap: break-word;\n";
    file << "}\n\n";
    
    file << ".chat-bubble.has-copy {\n";
    file << "  padding-right: 70px;\n";
    file << "}\n\n";
    
    file << ".chat-bubble-actions {\n";
    file << "  position: absolute;\n";
    file << "  top: 6px;\n";
    file << "  right: 8px;\n";
    file << "  display: flex;\n";
    file << "  gap: 4px;\n";
    file << "  opacity: 0;\n";
    file << "  pointer-events: none;\n";
    file << "  transition: opacity 120ms ease-out;\n";
    file << "}\n\n";
    
    file << ".chat-bubble:hover .chat-bubble-actions {\n";
    file << "  opacity: 1;\n";
    file << "  pointer-events: auto;\n";
    file << "}\n\n";
    
    file << "@media (hover: none) {\n";
    file << "  .chat-bubble-actions {\n";
    file << "    opacity: 1;\n";
    file << "    pointer-events: auto;\n";
    file << "  }\n";
    file << "}\n\n";
    
    file << ".chat-copy-btn,\n";
    file << ".chat-expand-btn {\n";
    file << "  background: var(--bg);\n";
    file << "  color: var(--muted);\n";
    file << "}\n\n";
    
    file << ".chat-copy-btn__icon {\n";
    file << "  display: inline-flex;\n";
    file << "  width: 14px;\n";
    file << "  height: 14px;\n";
    file << "  position: relative;\n";
    file << "}\n\n";
    
    file << ".chat-copy-btn__icon svg,\n";
    file << ".chat-expand-btn__icon svg {\n";
    file << "  width: 14px;\n";
    file << "  height: 14px;\n";
    file << "}\n\n";
    
    file << ".chat-copy-btn__icon-copy,\n";
    file << ".chat-copy-btn__icon-check {\n";
    file << "  position: absolute;\n";
    file << "  top: 0;\n";
    file << "  left: 0;\n";
    file << "  transition: opacity 150ms ease;\n";
    file << "}\n\n";
    
    file << ".chat-copy-btn__icon-check {\n";
    file << "  opacity: 0;\n";
    file << "}\n\n";
    
    file << ".chat-copy-btn[data-copied=\"1\"] .chat-copy-btn__icon-copy {\n";
    file << "  opacity: 0;\n";
    file << "}\n\n";
    
    file << ".chat-copy-btn[data-copied=\"1\"] .chat-copy-btn__icon-check {\n";
    file << "  opacity: 1;\n";
    file << "}\n\n";
    
    file << ".chat-copy-btn[data-copying=\"1\"] {\n";
    file << "  opacity: 0;\n";
    file << "  pointer-events: none;\n";
    file << "}\n\n";
    
    file << ".chat-copy-btn[data-error=\"1\"] {\n";
    file << "  border-color: var(--danger-subtle);\n";
    file << "  background: var(--danger-subtle);\n";
    file << "  color: var(--danger);\n";
    file << "}\n\n";
    
    file << ".chat-copy-btn[data-copied=\"1\"] {\n";
    file << "  border-color: var(--ok-subtle);\n";
    file << "  background: var(--ok-subtle);\n";
    file << "  color: var(--ok);\n";
    file << "}\n\n";
    
    file << ".chat-copy-btn:focus-visible,\n";
    file << ".chat-expand-btn:focus-visible {\n";
    file << "  outline: 2px solid var(--accent);\n";
    file << "  outline-offset: 2px;\n";
    file << "}\n\n";
    
    file << ".chat-expand-btn__icon {\n";
    file << "  display: inline-flex;\n";
    file << "  width: 14px;\n";
    file << "  height: 14px;\n";
    file << "}\n\n";
    
    file << "/* Light mode: restore borders */\n";
    file << ":root[data-theme-mode=\"light\"] .chat-bubble {\n";
    file << "  border-color: var(--border);\n";
    file << "  box-shadow: inset 0 1px 0 var(--card-highlight);\n";
    file << "}\n\n";
    
    file << ".chat-bubble:hover {\n";
    file << "  background: var(--bg-hover);\n";
    file << "}\n\n";
    
    file << "/* User bubbles have different styling */\n";
    file << ".chat-group.user .chat-bubble {\n";
    file << "  background: var(--accent-subtle);\n";
    file << "  border-color: transparent;\n";
    file << "}\n\n";
    
    file << ":root[data-theme-mode=\"light\"] .chat-group.user .chat-bubble {\n";
    file << "  border-color: color-mix(in srgb, var(--accent) 20%, transparent);\n";
    file << "  background: var(--accent-subtle);\n";
    file << "}\n\n";
    
    file << ".chat-group.user .chat-bubble:hover {\n";
    file << "  background: color-mix(in srgb, var(--accent) 20%, transparent);\n";
    file << "}\n\n";
    
    file << "/* Streaming animation */\n";
    file << ".chat-bubble.streaming {\n";
    file << "  animation: pulsing-border 1.5s ease-out infinite;\n";
    file << "}\n\n";
    
    file << "@keyframes pulsing-border {\n";
    file << "  0%,\n";
    file << "  100% {\n";
    file << "    border-color: var(--border);\n";
    file << "  }\n\n";
    file << "  50% {\n";
    file << "    border-color: var(--accent);\n";
    file << "  }\n";
    file << "}\n\n";
    
    file << "/* Fade-in animation for new messages */\n";
    file << ".chat-bubble.fade-in {\n";
    file << "  animation: fade-in 200ms ease-out;\n";
    file << "}\n\n";
    
    file << "@keyframes fade-in {\n";
    file << "  from {\n";
    file << "    opacity: 0;\n";
    file << "    transform: translateY(4px);\n";
    file << "  }\n\n";
    file << "  to {\n";
    file << "    opacity: 1;\n";
    file << "    transform: translateY(0);\n";
    file << "  }\n";
    file << "}\n\n";
    
    file << "/* ── Message metadata (tokens, cost, model, context %) ── */\n";
    file << ".msg-meta {\n";
    file << "  display: inline-flex;\n";
    file << "  align-items: center;\n";
    file << "  gap: 8px;\n";
    file << "  font-size: 11px;\n";
    file << "  line-height: 1;\n";
    file << "  color: var(--muted);\n";
    file << "  margin-top: 4px;\n";
    file << "  flex-wrap: wrap;\n";
    file << "}\n\n";
    
    file << ".msg-meta__tokens,\n";
    file << ".msg-meta__cache,\n";
    file << ".msg-meta__cost,\n";
    file << ".msg-meta__ctx,\n";
    file << ".msg-meta__model {\n";
    file << "  display: inline-flex;\n";
    file << "  align-items: center;\n";
    file << "  gap: 2px;\n";
    file << "  white-space: nowrap;\n";
    file << "}\n\n";
    
    file << ".msg-meta__model {\n";
    file << "  background: var(--bg-hover, rgba(255, 255, 255, 0.06));\n";
    file << "  padding: 1px 6px;\n";
    file << "  border-radius: var(--radius-sm, 4px);\n";
    file << "  font-family: var(--font-mono, monospace);\n";
    file << "}\n\n";
    
    file << ".msg-meta__cost {\n";
    file << "  color: var(--ok);\n";
    file << "}\n\n";
    
    file << ".msg-meta__ctx--warn {\n";
    file << "  color: var(--warn);\n";
    file << "}\n\n";
    
    file << ".msg-meta__ctx--danger {\n";
    file << "  color: var(--danger);\n";
    file << "}\n\n";
    
    file << "/* ── Delete confirmation popover ── */\n";
    file << ".chat-delete-wrap {\n";
    file << "  position: relative;\n";
    file << "  display: inline-flex;\n";
    file << "}\n\n";
    
    file << ".chat-delete-confirm {\n";
    file << "  position: absolute;\n";
    file << "  bottom: calc(100% + 6px);\n";
    file << "  background: var(--card, #1a1a1a);\n";
    file << "  border: 1px solid var(--border, rgba(255, 255, 255, 0.1));\n";
    file << "  border-radius: var(--radius-md, 8px);\n";
    file << "  padding: 12px;\n";
    file << "  min-width: 200px;\n";
    file << "  max-width: calc(100vw - 48px);\n";
    file << "  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);\n";
    file << "  z-index: 100;\n";
    file << "  animation: scale-in 0.15s ease-out;\n";
    file << "}\n\n";
    
    file << ".chat-delete-confirm--left {\n";
    file << "  right: 0;\n";
    file << "}\n\n";
    
    file << ".chat-delete-confirm--right {\n";
    file << "  left: 0;\n";
    file << "}\n\n";
    
    file << ".chat-delete-confirm__text {\n";
    file << "  margin: 0 0 8px;\n";
    file << "  font-size: 13px;\n";
    file << "  font-weight: 500;\n";
    file << "  color: var(--fg, #fff);\n";
    file << "}\n\n";
    
    file << ".chat-delete-confirm__remember {\n";
    file << "  display: flex;\n";
    file << "  align-items: center;\n";
    file << "  gap: 6px;\n";
    file << "  font-size: 11px;\n";
    file << "  color: var(--muted, #888);\n";
    file << "  margin-bottom: 10px;\n";
    file << "  cursor: pointer;\n";
    file << "  user-select: none;\n";
    file << "}\n\n";
    
    file << ".chat-delete-confirm__check {\n";
    file << "  width: 14px;\n";
    file << "  height: 14px;\n";
    file << "  accent-color: var(--accent);\n";
    file << "  cursor: pointer;\n";
    file << "}\n\n";
    
    file << ".chat-delete-confirm__actions {\n";
    file << "  display: flex;\n";
    file << "  gap: 6px;\n";
    file << "  justify-content: flex-end;\n";
    file << "}\n\n";
    
    file << ".chat-delete-confirm__cancel,\n";
    file << ".chat-delete-confirm__yes {\n";
    file << "  border: none;\n";
    file << "  border-radius: var(--radius-sm, 4px);\n";
    file << "  padding: 4px 12px;\n";
    file << "  font-size: 12px;\n";
    file << "  font-weight: 500;\n";
    file << "  cursor: pointer;\n";
    file << "  transition: background 120ms ease-out;\n";
    file << "}\n\n";
    
    file << ".chat-delete-confirm__cancel {\n";
    file << "  background: var(--bg-hover, rgba(255, 255, 255, 0.08));\n";
    file << "  color: var(--muted, #888);\n";
    file << "}\n\n";
    
    file << ".chat-delete-confirm__cancel:hover {\n";
    file << "  background: rgba(255, 255, 255, 0.12);\n";
    file << "}\n\n";
    
    file << ".chat-delete-confirm__yes {\n";
    file << "  background: var(--danger);\n";
    file << "  color: #fff;\n";
    file << "}\n\n";
    
    file << ".chat-delete-confirm__yes:hover {\n";
    file << "  background: #dc2626;\n";
    file << "}\n\n";
    
    file << "@media (max-width: 768px) {\n";
    file << "  .chat-group {\n";
    file << "    margin-left: 0;\n";
    file << "    margin-right: 0;\n";
    file << "  }\n\n";
    file << "  .chat-group-messages {\n";
    file << "    max-width: 82%;\n";
    file << "  }\n";
    file << "}\n\n";
    
    file << "@media (max-width: 400px) {\n";
    file << "  .chat-group-messages {\n";
    file << "    max-width: 100%;\n";
    file << "  }\n\n";
    file << "  .chat-avatar,\n";
    file << "  img.chat-avatar {\n";
    file << "    display: none;\n";
    file << "  }\n";
    file << "}\n";
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <output_file>\n";
        return 1;
    }
    
    std::ofstream outputFile(argv[1]);
    if (!outputFile.is_open()) {
        std::cerr << "Error: Could not open file " << argv[1] << " for writing.\n";
        return 1;
    }
    
    writeCSS(outputFile);
    outputFile.close();
    
    return 0;
}
