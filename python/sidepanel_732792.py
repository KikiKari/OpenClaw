#!/usr/bin/env python3
# sidepanel.html — portiert nach python
# Quelle: html, Projects@TikTok-Live-Companion:release/0.7.1/tiktok-live-companion-extension-0.7.1/sidepanel.html
# auch in: Projects@TikTok-Live-Companion-Android:release/0.7.1/tiktok-live-companion-extension-0.7.1/sidepanel.html
# auch in: Projects@TikTok-Live-Companion-iOS:release/0.7.1/tiktok-live-companion-extension-0.7.1/sidepanel.html
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import sys
from pathlib import Path

def generate_html():
    """Generate the complete HTML document as a string."""
    
    # Start with DOCTYPE and html tag
    html = '<!DOCTYPE html>\n'
    html += '<html lang="de">\n'
    
    # Head section
    html += '<head>\n'
    html += '  <meta charset="utf-8">\n'
    html += '  <meta name="viewport" content="width=device-width, initial-scale=1">\n'
    html += '  <title>TikTok LIVE Companion</title>\n'
    html += '  <link rel="stylesheet" href="sidepanel.css">\n'
    html += '</head>\n'
    
    # Body section
    html += '<body>\n'
    
    # Header
    html += '  <header>\n'
    html += '    <p id="page-title" class="muted">Kein TikTok-Tab ausgewählt</p>\n'
    html += '  </header>\n'
    
    # Main content
    html += '  <main>\n'
    
    # Chat section
    html += '    <section aria-labelledby="chat-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="chat-heading">Chatzeilen</h2>\n'
    html += '        <div class="title-actions">\n'
    html += '          <span id="chat-led" class="status-led off" role="status" aria-label="Chat inaktiv" title="Chat inaktiv"></span>\n'
    html += '          <button id="chat-count" class="count count-button" type="button" aria-haspopup="dialog" title="Gesammelte Chatzeilen öffnen">0</button>\n'
    html += '          <button id="refresh-chat" class="secondary compact" title="Chatanzeige leeren">Refresh</button>\n'
    html += '          <button id="toggle-speech" class="secondary compact" aria-pressed="false">Vorlesen an</button>\n'
    html += '          <span id="speech-led" class="status-led off" role="status" aria-label="Vorlesen inaktiv" title="Vorlesen inaktiv"></span>\n'
    html += '        </div>\n'
    html += '      </div>\n'
    html += '      <div id="chat-list" class="chat-list empty" role="log" aria-live="polite" aria-relevant="additions" aria-label="Die letzten fünf bereinigten Chatnachrichten">Noch keine Chatnachrichten erkannt.</div>\n'
    html += '      <p id="speech-status" role="status" class="inline-status">Vorlesen ist ausgeschaltet.</p>\n'
    
    # Speech volume controls
    html += '      <div class="control-label"><label for="speech-volume">Vorleselautstärke</label><output id="speech-volume-output" for="speech-volume">100%</output></div>\n'
    html += '      <input id="speech-volume" type="range" min="0" max="100" step="5" value="50">\n'
    
    # Speech settings grid
    html += '      <div class="settings-grid speech-settings">\n'
    html += '        <label><span>Sprache</span><select id="speech-language"><option value="auto">Auto</option><option value="de-DE">Deutsch</option><option value="en-US">Englisch</option><option value="ru-RU">Russisch</option><option value="uk-UA">Ukrainisch</option><option value="bg-BG">Bulgarisch</option><option value="sr-RS">Serbisch</option><option value="kk-KZ">Kasachisch</option><option value="zh-CN">Chinesisch</option><option value="ja-JP">Japanisch</option><option value="ko-KR">Koreanisch</option><option value="ar-JO">Arabisch</option><option value="fa-IR">Persisch</option><option value="ur-PK">Urdu</option><option value="hi-IN">Hindi</option><option value="ne-NP">Nepali</option><option value="ml-IN">Malayalam</option></select></label>\n'
    html += '        <label><span>Stimme</span><select id="speech-voice"><option value="">Standard</option></select></label>\n'
    html += '        <label id="audd-token-setting"><span id="audd-token-label">AudD API-Token (optional - <a href="https://audd.io/" target="_blank" rel="noopener noreferrer">https://AudD.io</a> Trial/Paid )</span><input id="audd-token" type="password" autocomplete="off" spellcheck="false"></label>\n'
    html += '        <label id="pairing-code-setting"><span>Pairing-Code</span><input id="pairing-code" type="password" autocomplete="off" spellcheck="false"></label>\n'
    html += '      </div>\n'
    
    # Service buttons
    html += '      <div class="button-row">\n'
    html += '        <button id="service-action" class="secondary">Sprachdienst installieren</button>\n'
    html += '        <button id="sherpa-action" class="secondary">Sherpa installieren</button>\n'
    html += '      </div>\n'
    
    # Service status
    html += '      <p id="service-status" class="inline-status">Lokaler Sprachdienst noch nicht geprüft.</p>\n'
    html += '      <div id="service-setup" class="inline-status" hidden>\n'
    html += '        <button id="copy-service-setup" class="secondary compact">Installation abschließen!</button>\n'
    html += '      </div>\n'
    
    # Options
    html += '      <label class="option-row"><input id="speak-names" type="checkbox" checked> Chatnamen sprechen</label>\n'
    html += '      <label class="option-row"><input id="shorten-names" type="checkbox"> Chatnamen kürzen</label>\n'
    html += '      <label class="option-row"><input id="game-mode" type="checkbox"> Game-Mode</label>\n'
    html += '      <label class="option-row auto-chat-refresh"><input id="auto-chat-refresh" type="checkbox"> Auto-Chat Refresh <input id="auto-chat-refresh-minutes" type="number" min="1" max="60" step="1" value="5" inputmode="numeric" aria-label="Auto-Chat-Refresh in Minuten"><span>min.</span></label>\n'
    html += '      <label class="option-row"><input id="keep-speech-active" type="checkbox"> Permanent aktiv</label>\n'
    html += '    </section>\n'
    
    # Top chatters section
    html += '    <section aria-labelledby="top-chatters-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="top-chatters-heading">Top-Chatter</h2>\n'
    html += '        <button id="open-audience" class="secondary compact">Zuschauer*innen</button>\n'
    html += '      </div>\n'
    html += '      <p id="team-tag-status" class="inline-status">Teamkürzel: noch nicht erkannt.</p>\n'
    html += '      <div id="top-chatters" class="top-chatters empty">Noch keine Personen im Chat beobachtet.</div>\n'
    html += '      <div id="top-chatters-actions" class="top-chatters-actions" hidden>\n'
    html += '        <button id="top-chatters-reset" class="top-chatter-link" type="button" hidden>Reset</button>\n'
    html += '        <button id="top-chatters-more" class="top-chatter-link" type="button">mehr…</button>\n'
    html += '      </div>\n'
    html += '    </section>\n'
    
    # Page info section
    html += '    <section id="page-info-section" aria-labelledby="page-info-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="page-info-heading">Seiteninformationen</h2>\n'
    html += '        <div class="title-actions">\n'
    html += '          <span id="page-info-source" class="live-indicator">Metadaten</span>\n'
    html += '          <button id="refresh-page-info" class="secondary compact">Refresh</button>\n'
    html += '          <button id="force-page-info" class="secondary compact danger-outline">Force</button>\n'
    html += '        </div>\n'
    html += '      </div>\n'
    html += '      <div id="profile-info" class="profile-info" hidden></div>\n'
    html += '      <div id="summary-info" class="summary-info"></div>\n'
    html += '    </section>\n'
    
    # Stats section
    html += '    <section aria-labelledby="stats-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="stats-heading">LIVE-Informationen</h2>\n'
    html += '        <span id="stats-live" class="live-indicator">warte</span>\n'
    html += '      </div>\n'
    html += '      <div id="live-stats" class="status-grid stats-grid"></div>\n'
    html += '      <p id="stats-status" class="inline-status"></p>\n'
    html += '    </section>\n'
    
    # WebSocket hook section
    html += '    <section aria-labelledby="hook-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="hook-heading">WebSocket-Hook</h2>\n'
    html += '        <span id="hook-led" class="status-led off" role="status" aria-label="Hook inaktiv" title="Hook inaktiv"></span>\n'
    html += '      </div>\n'
    html += '      <div class="button-row">\n'
    html += '        <button id="enable-hook" class="primary">Hook setzen</button>\n'
    html += '        <button id="disable-hook" class="secondary">Hook deaktivieren</button>\n'
    html += '        <button id="reset-tab" class="secondary danger-outline">Refresh</button>\n'
    html += '        <button id="open-embed-live" class="secondary">Embed</button>\n'
    html += '        <button id="open-normal-live" class="secondary">Normal</button>\n'
    html += '        <button id="player-vlc-frame" class="secondary compact">VLC Ersatz</button>\n'
    html += '      </div>\n'
    html += '      <p id="hook-status" class="inline-status"></p>\n'
    html += '      <label class="option-row"><input id="hook-autostart" type="checkbox"> Permanent Hook</label>\n'
    html += '      <label class="option-row"><input id="quick-recover" type="checkbox"> Auto-Reconnect</label>\n'
    html += '    </section>\n'
    
    # Captions section
    html += '    <section aria-labelledby="caption-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="caption-heading">Untertitel</h2>\n'
    html += '        <button id="scan" class="secondary">Seite prüfen</button>\n'
    html += '      </div>\n'
    html += '      <div id="caption-status" class="status-grid"></div>\n'
    html += '      <button id="enable-captions" class="primary">Untertitel aktivieren</button>\n'
    html += '      <p id="caption-action-status" role="status" class="inline-status action-status"></p>\n'
    html += '    </section>\n'
    
    # Player control section
    html += '    <section aria-labelledby="player-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="player-heading">Playersteuerung</h2>\n'
    html += '        <span id="player-time" class="player-time">–</span>\n'
    html += '      </div>\n'
    html += '      <div class="player-controls" role="group" aria-label="TikTok-Player steuern">\n'
    html += '        <button id="player-play" class="secondary compact">Pause</button>\n'
    html += '        <button id="player-replay" class="secondary compact">Neu laden</button>\n'
    html += '        <button id="player-mute" class="secondary compact">Stumm</button>\n'
    html += '        <button id="player-pip" class="secondary compact">Bild-in-Bild</button>\n'
    html += '        <button id="player-fullscreen" class="secondary compact">Vollbild</button>\n'
    html += '        <button id="player-report" class="secondary compact danger-outline">Melden öffnen</button>\n'
    html += '      </div>\n'
    
    # Audio controls
    html += '      <div class="audio-controls">\n'
    html += '        <div class="control-label"><label for="player-volume">Lautstärke</label><output id="player-volume-output" for="player-volume">–</output></div>\n'
    html += '        <input id="player-volume" type="range" min="0" max="100" step="1" value="100">\n'
    html += '        <div class="audio-meter-row"><span>Spitzenpegel</span><strong id="player-peak">–</strong></div>\n'
    html += '        <label class="option-row"><input id="limiter-enabled" type="checkbox"> Pegelschutz aktivieren</label>\n'
    html += '        <div class="control-label"><label for="limiter-strength">Schutzstärke</label><output id="limiter-strength-output" for="limiter-strength">30</output></div>\n'
    html += '        <input id="limiter-strength" type="range" min="0" max="100" step="1" value="30">\n'
    html += '      </div>\n'
    
    # Player status
    html += '      <p id="multi-guest-status" class="inline-status">Verbundene Streams: noch nicht erkannt.</p>\n'
    html += '      <p id="player-status" role="status" class="inline-status">Warte auf den TikTok-Player.</p>\n'
    html += '    </section>\n'
    
    # Song recognition section
    html += '    <section aria-labelledby="song-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="song-heading">Songerkennung</h2>\n'
    html += '        <span id="song-led" class="status-led off" role="status" aria-label="Songerkennung inaktiv"></span>\n'
    html += '      </div>\n'
    html += '      <label class="option-row"><input id="song-enabled" type="checkbox"> Songerkennung aktivieren</label>\n'
    html += '      <button id="recognize-song" class="primary" disabled>Jetzt erkennen</button>\n'
    html += '      <p id="song-status" class="inline-status"></p>\n'
    html += '      <div id="song-result" class="song-result" hidden></div>\n'
    html += '    </section>\n'
    
    # VLC links section
    html += '    <section aria-labelledby="links-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="links-heading">VLC-Links</h2>\n'
    html += '        <span id="media-count" class="count">0</span>\n'
    html += '      </div>\n'
    html += '      <div id="media-list" class="list empty">Noch keine FLV-/HLS-Links erkannt.</div>\n'
    html += '    </section>\n'
    
    # Caption log section
    html += '    <section aria-labelledby="log-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="log-heading">Caption-Protokoll</h2>\n'
    html += '        <span id="caption-count" class="count">0</span>\n'
    html += '      </div>\n'
    html += '      <div class="button-row">\n'
    html += '        <button id="export-log" class="secondary">JSONL exportieren</button>\n'
    html += '        <button id="clear" class="ghost">Anzeige leeren</button>\n'
    html += '      </div>\n'
    html += '      <div id="caption-list" class="list empty">Noch keine CaptionMessages empfangen.</div>\n'
    html += '    </section>\n'
    
    # Debug section
    html += '    <section aria-labelledby="debug-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="debug-heading">Debugmodus</h2>\n'
    html += '        <span id="debug-count" class="count">0</span>\n'
    html += '      </div>\n'
    html += '      <label class="option-row"><input id="debug-enabled" type="checkbox"> Diagnoseereignisse für diesen Tab protokollieren</label>\n'
    html += '      <div class="button-row">\n'
    html += '        <button id="export-debug" class="secondary">Debug exportieren</button>\n'
    html += '        <button id="clear-debug" class="ghost">Debug leeren</button>\n'
    html += '      </div>\n'
    html += '      <p class="muted small"></p>\n'
    html += '    </section>\n'
    
    # Audience modal
    html += '    <div id="audience-modal" class="modal-backdrop" hidden>\n'
    html += '      <section class="modal" role="dialog" aria-modal="true" aria-labelledby="audience-heading">\n'
    html += '        <div class="section-title">\n'
    html += '          <h2 id="audience-heading">Im Chat beobachtete Personen</h2>\n'
    html += '          <button id="close-audience" class="secondary compact" aria-label="Übersicht schließen">Schließen</button>\n'
    html += '        </div>\n'
    html += '        <p id="audience-limit" class="inline-status"></p>\n'
    html += '        <div id="audience-list" class="audience-list"></div>\n'
    html += '      </section>\n'
    html += '    </div>\n'
    
    # Chat history modal
    html += '    <div id="chat-history-modal" class="modal-backdrop" hidden>\n'
    html += '      <section class="modal" role="dialog" aria-modal="true" aria-labelledby="chat-history-heading">\n'
    html += '        <div class="section-title">\n'
    html += '          <h2 id="chat-history-heading">Gesammelte Chatzeilen</h2>\n'
    html += '          <button id="close-chat-history" class="secondary compact" aria-label="Chatzeilen schließen">Schließen</button>\n'
    html += '        </div>\n'
    html += '        <p id="chat-history-limit" class="inline-status"></p>\n'
    html += '        <div id="chat-history-list" class="chat-history-list"></div>\n'
    html += '      </section>\n'
    html += '    </div>\n'
    
    # Notice
    html += '    <p id="notice" role="alert" class="notice"></p>\n'
    
    # End main and body
    html += '  </main>\n'
    html += '  <script src="content-core.js"></script>\n'
    html += '  <script src="sidepanel.js"></script>\n'
    html += '</body>\n'
    
    # Close html
    html += '</html>\n'
    
    return html

def main():
    """Main function to write HTML to file or stdout."""
    if len(sys.argv) > 1:
        output_path = Path(sys.argv[1])
        try:
            output_path.write_text(generate_html(), encoding='utf-8')
        except Exception as e:
            print(f"Error writing to file: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        print(generate_html())

if __name__ == "__main__":
    main()
