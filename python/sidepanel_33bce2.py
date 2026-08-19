#!/usr/bin/env python3
# sidepanel.html — portiert nach python
# Quelle: html, Projects@TikTok-Live-Companion:release/0.6.0/tiktok-live-companion-extension-0.6.0/sidepanel.html
# auch in: Projects@TikTok-Live-Companion:release/0.7.0/tiktok-live-companion-extension-0.7.0/sidepanel.html
# auch in: Projects@TikTok-Live-Companion-Android:release/0.6.0/tiktok-live-companion-extension-0.6.0/sidepanel.html
# auch in: Projects@TikTok-Live-Companion-Android:release/0.7.0/tiktok-live-companion-extension-0.7.0/sidepanel.html
# auch in: 2 weiteren Fundstellen
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import sys
from pathlib import Path

def generate_html():
    """Generate the complete HTML document as a string"""
    
    # Start with DOCTYPE and html tag
    html = '<!doctype html>\n'
    html += '<html lang="de">\n'
    html += '<head>\n'
    html += '  <meta charset="utf-8">\n'
    html += '  <meta name="viewport" content="width=device-width, initial-scale=1">\n'
    html += '  <title>TikTok LIVE Companion</title>\n'
    html += '  <link rel="stylesheet" href="sidepanel.css">\n'
    html += '</head>\n'
    html += '<body>\n'
    
    # Header section
    html += '  <header>\n'
    html += '    <p id="page-title" class="muted">Kein TikTok-Tab ausgewählt</p>\n'
    html += '  </header>\n\n'
    
    # Main content
    html += '  <main>\n'
    
    # Chat section
    html += '    <section aria-labelledby="chat-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="chat-heading">Chatzeilen</h2>\n'
    html += '        <div class="title-actions">\n'
    html += '          <span id="chat-led" class="status-led off" role="status" aria-label="Chat inaktiv" title="Chat inaktiv"></span>\n'
    html += '          <span id="chat-count" class="count">0</span>\n'
    html += '          <button id="refresh-chat" class="secondary compact" title="Chatanzeige leeren">Refresh</button>\n'
    html += '          <button id="toggle-speech" class="secondary compact" aria-pressed="false">Vorlesen an</button>\n'
    html += '          <span id="speech-led" class="status-led off" role="status" aria-label="Vorlesen inaktiv" title="Vorlesen inaktiv"></span>\n'
    html += '        </div>\n'
    html += '      </div>\n'
    html += '      <div id="chat-list" class="chat-list empty" role="log" aria-live="polite" aria-relevant="additions" aria-label="Die letzten fünf bereinigten Chatnachrichten">Noch keine Chatnachrichten erkannt.</div>\n'
    html += '      <p id="speech-status" role="status" class="inline-status">Vorlesen ist ausgeschaltet.</p>\n'
    html += '      <div class="control-label"><label for="speech-volume">Vorleselautstärke</label><output id="speech-volume-output" for="speech-volume">100%</output></div>\n'
    html += '      <input id="speech-volume" type="range" min="0" max="100" step="5" value="50">\n'
    html += '      <div class="settings-grid speech-settings">\n'
    html += '        <label><span>Sprache</span><select id="speech-language"><option value="auto">Auto</option><option value="de-DE">Deutsch</option><option value="en-US">Englisch</option></select></label>\n'
    html += '        <label><span>Dienstadresse</span><input id="service-url" type="url" value="http://127.0.0.1:43117" spellcheck="false"></label>\n'
    html += '        <label><span>Pairing-Code</span><input id="pairing-code" type="password" autocomplete="off"></label>\n'
    html += '      </div>\n'
    html += '      <p id="service-status" class="inline-status">Lokaler Sprachdienst noch nicht geprüft.</p>\n'
    html += '      <label class="option-row"><input id="speak-names" type="checkbox" checked> Chatnamen vorlesen</label>\n'
    html += '      <label class="option-row"><input id="shorten-names" type="checkbox"> Geeignete lange Namen kürzen</label>\n'
    html += '      <label class="option-row"><input id="keep-speech-active" type="checkbox"> Vorlesen bei Tabwechsel oder Minimieren aktiv lassen</label>\n'
    html += '    </section>\n\n'
    
    # Top chatters section
    html += '    <section aria-labelledby="top-chatters-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="top-chatters-heading">Top-Chatter</h2>\n'
    html += '        <button id="open-audience" class="secondary compact">Zuschauer*innen</button>\n'
    html += '      </div>\n'
    html += '      <p id="team-tag-status" class="inline-status">Teamkürzel: noch nicht erkannt.</p>\n'
    html += '      <div id="top-chatters" class="top-chatters empty">Noch keine Personen im Chat beobachtet.</div>\n'
    html += '    </section>\n\n'
    
    # Song recognition section
    html += '    <section aria-labelledby="song-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="song-heading">Songerkennung</h2>\n'
    html += '        <span id="song-led" class="status-led off" role="status" aria-label="Songerkennung inaktiv"></span>\n'
    html += '      </div>\n'
    html += '      <label class="option-row"><input id="song-enabled" type="checkbox"> Songerkennung aktivieren</label>\n'
    html += '      <button id="recognize-song" class="primary" disabled>Jetzt erkennen</button>\n'
    html += '      <p id="song-status" class="inline-status">Es wird nichts aufgenommen oder übertragen.</p>\n'
    html += '      <div id="song-result" class="song-result" hidden></div>\n'
    html += '      <p class="muted small">Nach einem Klick werden etwa 12 Sekunden Tab-Audio über den lokalen Dienst an AudD übertragen. Anbietergebühren können anfallen.</p>\n'
    html += '    </section>\n\n'
    
    # Captions section
    html += '    <section aria-labelledby="caption-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="caption-heading">Untertitel</h2>\n'
    html += '        <button id="scan" class="secondary">Seite prüfen</button>\n'
    html += '      </div>\n'
    html += '      <div id="caption-status" class="status-grid"></div>\n'
    html += '      <button id="enable-captions" class="primary">Untertitel aktivieren</button>\n'
    html += '      <p id="caption-action-status" role="status" class="inline-status action-status">Noch keine manuelle Prüfung ausgeführt.</p>\n'
    html += '    </section>\n\n'
    
    # WebSocket hook section
    html += '    <section aria-labelledby="hook-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="hook-heading">WebSocket-Hook</h2>\n'
    html += '        <span id="hook-led" class="status-led off" role="status" aria-label="Hook inaktiv" title="Hook inaktiv"></span>\n'
    html += '      </div>\n'
    html += '      <p class="muted small">Der Hook wird vor dem Player-Code gesetzt. Der aktuelle Tab wird danach neu geladen.</p>\n'
    html += '      <div class="button-row">\n'
    html += '        <button id="enable-hook" class="primary">Hook setzen</button>\n'
    html += '        <button id="disable-hook" class="secondary">Hook deaktivieren</button>\n'
    html += '        <button id="reset-tab" class="secondary danger-outline">Refresh</button>\n'
    html += '      </div>\n'
    html += '      <p id="hook-status" class="inline-status"></p>\n'
    html += '      <label class="option-row"><input id="hook-autostart" type="checkbox"> Hook beim Öffnen von TikTok automatisch starten</label>\n'
    html += '      <p class="muted small reset-note">Refresh leert nur die flüchtigen Daten dieses Tabs, aktiviert den Hook erneut und lädt TikTok ohne Seitencache. cookies bleiben unverändert.</p>\n'
    html += '    </section>\n\n'
    
    # Live stats section
    html += '    <section aria-labelledby="stats-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="stats-heading">LIVE-Informationen</h2>\n'
    html += '        <span id="stats-live" class="live-indicator">warte</span>\n'
    html += '      </div>\n'
    html += '      <div id="live-stats" class="status-grid stats-grid"></div>\n'
    html += '      <p id="stats-status" class="inline-status">Der WebSocket-Hook liefert die Werte nach dem Neuladen des Streams.</p>\n'
    html += '    </section>\n\n'
    
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
    html += '      <div class="audio-controls">\n'
    html += '        <div class="control-label"><label for="player-volume">Lautstärke</label><output id="player-volume-output" for="player-volume">–</output></div>\n'
    html += '        <input id="player-volume" type="range" min="0" max="100" step="1" value="100">\n'
    html += '        <div class="audio-meter-row"><span>Digitaler Spitzenpegel</span><strong id="player-peak">– dBFS</strong></div>\n'
    html += '        <label class="option-row"><input id="limiter-enabled" type="checkbox"> Digitalen Pegelschutz aktivieren</label>\n'
    html += '        <div class="control-label"><label for="limiter-threshold">Grenzwert</label><output id="limiter-threshold-output" for="limiter-threshold">−6 dBFS</output></div>\n'
    html += '        <input id="limiter-threshold" type="range" min="-30" max="-1" step="1" value="-6">\n'
    html += '        <p class="muted small audio-note">dBFS ist ein digitaler Signalpegel, kein am Ohr messbarer dB-SPL-Wert. Der Schutz komprimiert Spitzen oberhalb des Grenzwerts lokal im Browser.</p>\n'
    html += '      </div>\n'
    html += '      <p id="multi-guest-status" class="inline-status">Verbundene Streams: noch nicht erkannt.</p>\n'
    html += '      <p id="player-status" role="status" class="inline-status">Warte auf den TikTok-Player.</p>\n'
    html += '    </section>\n\n'
    
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
    html += '    </section>\n\n'
    
    # Quality section
    html += '    <section aria-labelledby="quality-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="quality-heading">Verfügbare Bildqualitäten</h2>\n'
    html += '        <span id="quality-count" class="count">0</span>\n'
    html += '      </div>\n'
    html += '      <div id="quality-list" class="list empty">Noch keine Qualitätsstufen aus den Stream-Metadaten erkannt.</div>\n'
    html += '      <p id="quality-action-status" role="status" class="inline-status"></p>\n'
    html += '    </section>\n\n'
    
    # VLC links section
    html += '    <section aria-labelledby="links-heading">\n'
    html += '      <div class="section-title">\n'
    html += '        <h2 id="links-heading">VLC-Links</h2>\n'
    html += '        <span id="media-count" class="count">0</span>\n'
    html += '      </div>\n'
    html += '      <div id="media-list" class="list empty">Noch keine FLV-/HLS-Links erkannt.</div>\n'
    html += '    </section>\n\n'
    
    # Log section
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
    html += '    </section>\n\n'
    
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
    html += '      <p class="muted small">Der Export entfernt Werte signierter URL-Parameter und enthält keine cookies oder API-Keys.</p>\n'
    html += '    </section>\n\n'
    
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
    html += '    </div>\n\n'
    
    # Notice
    html += '    <p id="notice" role="alert" class="notice"></p>\n'
    html += '  </main>\n\n'
    
    # Scripts
    html += '  <script src="content-core.js"></script>\n'
    html += '  <script src="sidepanel.js"></script>\n'
    html += '</body>\n'
    html += '</html>\n'
    
    return html

def main():
    """Main function to write HTML to file or stdout"""
    if len(sys.argv) > 1:
        output_file = Path(sys.argv[1])
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(generate_html())
            print(f"HTML document written to {output_file}")
        except Exception as e:
            print(f"Error writing to file: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        print(generate_html())

if __name__ == "__main__":
    main()
