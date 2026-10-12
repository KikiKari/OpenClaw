#!/usr/bin/env tclsh
# sidepanel.html — portiert nach tcl
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/sidepanel.html
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/sidepanel.html
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/sidepanel.html
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

# Tcl/Tk port of sidepanel.html
# This script generates the HTML structure programmatically

proc generateSidePanel {} {
    set html "<!DOCTYPE html>\n"
    append html "<html lang=\"de\">\n"
    append html "<head>\n"
    append html "  <meta charset=\"utf-8\">\n"
    append html "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
    append html "  <title>TikTok LIVE Companion</title>\n"
    append html "  <link rel=\"stylesheet\" href=\"sidepanel.css\">\n"
    append html "</head>\n"
    append html "<body>\n"
    
    # Header section
    append html "  <header>\n"
    append html "    <p id=\"page-title\" class=\"muted\">Kein TikTok-Tab ausgewählt</p>\n"
    append html "  </header>\n\n"
    
    append html "  <main>\n"
    
    # Chat section
    append html "    <section aria-labelledby=\"chat-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"chat-heading\">Chat</h2>\n"
    append html "        <div class=\"title-actions\">\n"
    append html "          <span id=\"chat-led\" class=\"status-led off\" role=\"status\" aria-label=\"Chat inaktiv\" title=\"Chat inaktiv\"></span>\n"
    append html "          <button id=\"chat-count\" class=\"count count-button\" type=\"button\" aria-haspopup=\"dialog\" title=\"Gesammelte Chatzeilen öffnen\">0</button>\n"
    append html "          <button id=\"refresh-chat\" class=\"secondary compact\" title=\"Chatanzeige leeren\">Refresh</button>\n"
    append html "          <button id=\"toggle-speech\" class=\"secondary compact\" aria-pressed=\"false\" aria-label=\"Vorlesen\">On</button>\n"
    append html "          <span id=\"speech-led\" class=\"status-led off\" role=\"status\" aria-label=\"Vorlesen inaktiv\" title=\"Vorlesen inaktiv\"></span>\n"
    append html "        </div>\n"
    append html "      </div>\n"
    append html "      <div id=\"chat-list\" class=\"chat-list empty\" role=\"log\" aria-live=\"polite\" aria-relevant=\"additions\" aria-label=\"Die letzten fünf bereinigten Chatnachrichten\">Noch keine Chatnachrichten erkannt.</div>\n"
    append html "      <p id=\"speech-status\" role=\"status\" class=\"inline-status\">Vorlesen ist ausgeschaltet.</p>\n"
    append html "      <div class=\"control-label\"><label for=\"speech-volume\">Vorleselautstärke</label><output id=\"speech-volume-output\" for=\"speech-volume\">100%</output></div>\n"
    append html "      <input id=\"speech-volume\" type=\"range\" min=\"0\" max=\"100\" step=\"5\" value=\"50\">\n"
    append html "      <div class=\"button-row\">\n"
    append html "        <button id=\"service-action\" class=\"secondary\">Sprachdienst</button>\n"
    append html "        <button id=\"sherpa-action\" class=\"secondary\">Sherpa</button>\n"
    append html "        <button id=\"open-speech-settings\" class=\"secondary compact settings-button\" type=\"button\" aria-label=\"Erweiterte Einstellungen öffnen\" aria-haspopup=\"dialog\" title=\"Einstellungen\">⚙</button>\n"
    append html "      </div>\n"
    append html "      <p id=\"service-status\" class=\"inline-status\">Lokaler Sprachdienst noch nicht geprüft.</p>\n"
    append html "      <div id=\"service-setup\" class=\"inline-status\" hidden>\n"
    append html "        <button id=\"copy-service-setup\" class=\"secondary compact\">Installation abschließen!</button>\n"
    append html "      </div>\n"
    append html "      <label class=\"option-row\"><input id=\"keep-speech-active\" type=\"checkbox\"> Permanent aktiv</label>\n"
    append html "    </section>\n\n"
    
    # Top chatters section
    append html "    <section aria-labelledby=\"top-chatters-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"top-chatters-heading\">Top-Chatter</h2>\n"
    append html "        <button id=\"open-audience\" class=\"secondary compact\">Zuschauer*innen</button>\n"
    append html "      </div>\n"
    append html "      <p id=\"team-tag-status\" class=\"inline-status\">Teamkürzel: noch nicht erkannt.</p>\n"
    append html "      <div id=\"top-chatters\" class=\"top-chatters empty\">Noch keine Personen im Chat beobachtet.</div>\n"
    append html "      <div id=\"top-chatters-actions\" class=\"top-chatters-actions\" hidden>\n"
    append html "        <button id=\"top-chatters-reset\" class=\"top-chatter-link\" type=\"button\" hidden>Reset</button>\n"
    append html "        <button id=\"top-chatters-more\" class=\"top-chatter-link\" type=\"button\">mehr…</button>\n"
    append html "      </div>\n"
    append html "    </section>\n\n"
    
    # Page info section
    append html "    <section id=\"page-info-section\" aria-labelledby=\"page-info-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"page-info-heading\">PROFIL-Information</h2>\n"
    append html "        <div class=\"title-actions\">\n"
    append html "          <span id=\"page-info-source\" class=\"live-indicator\">Metadaten</span>\n"
    append html "          <button id=\"refresh-page-info\" class=\"secondary compact\">Refresh</button>\n"
    append html "          <button id=\"force-page-info\" class=\"secondary compact danger-outline\">Force</button>\n"
    append html "        </div>\n"
    append html "      </div>\n"
    append html "      <div id=\"profile-info\" class=\"profile-info\" hidden></div>\n"
    append html "      <div id=\"summary-info\" class=\"summary-info\"></div>\n"
    append html "    </section>\n\n"
    
    # Stats section
    append html "    <section aria-labelledby=\"stats-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"stats-heading\">LIVE-Information</h2>\n"
    append html "        <span id=\"stats-live\" class=\"live-indicator\">warte</span>\n"
    append html "      </div>\n"
    append html "      <div id=\"live-stats\" class=\"status-grid stats-grid\"></div>\n"
    append html "      <p id=\"stats-status\" class=\"inline-status\"></p>\n"
    append html "    </section>\n\n"
    
    # Hook section
    append html "    <section aria-labelledby=\"hook-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"hook-heading\">Connection</h2>\n"
    append html "        <span id=\"hook-led\" class=\"status-led off\" role=\"status\" aria-label=\"Hook inaktiv\" title=\"Hook inaktiv\"></span>\n"
    append html "      </div>\n"
    append html "      <div class=\"button-row\">\n"
    append html "        <button id=\"toggle-hook\" class=\"primary\" aria-label=\"Connection\" aria-pressed=\"false\">On</button>\n"
    append html "        <button id=\"reset-tab\" class=\"secondary danger-outline\">Refresh</button>\n"
    append html "        <button id=\"open-embed-live\" class=\"secondary\">Embed</button>\n"
    append html "        <button id=\"open-normal-live\" class=\"secondary\">Browser</button>\n"
    append html "        <button id=\"player-vlc-frame\" class=\"secondary compact\">Player</button>\n"
    append html "        <button id=\"open-connection-settings\" class=\"secondary compact settings-button\" type=\"button\" aria-label=\"Connection-Einstellungen öffnen\" aria-haspopup=\"dialog\">⚙</button>\n"
    append html "      </div>\n"
    append html "      <p id=\"hook-status\" class=\"inline-status\"></p>\n"
    append html "      <p id=\"embed-startup-status\" class=\"inline-status\" role=\"status\" aria-live=\"polite\" hidden></p>\n"
    append html "      <button id=\"cancel-embed-startup\" class=\"secondary\" hidden>Embed-Start abbrechen</button>\n"
    append html "      <label class=\"option-row\"><input id=\"hook-autostart\" type=\"checkbox\"> Permanent Hook</label>\n"
    append html "      <p id=\"hook-reconnect-status\" class=\"inline-status\" role=\"status\">Hook-Reconnect: aus</p>\n"
    append html "      <p id=\"player-recovery-status\" class=\"inline-status\" role=\"status\">Player-Recovery: aus</p>\n"
    append html "    </section>\n\n"
    
    # Recommendations section
    append html "    <section id=\"recommendations-section\" aria-labelledby=\"recommendations-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"recommendations-heading\">LIVE-Empfehlungen</h2>\n"
    append html "        <span id=\"recommendation-status\" class=\"live-indicator\">bereit</span>\n"
    append html "      </div>\n"
    append html "      <div class=\"recommendation-controls\">\n"
    append html "        <label><span>Anzahl</span><input id=\"recommendation-limit\" type=\"number\" min=\"1\" max=\"50\" step=\"1\" value=\"20\" inputmode=\"numeric\"></label>\n"
    append html "        <label><span>Sortierung</span><select id=\"recommendation-sort\"><option value=\"tiktok\">TikTok-Reihenfolge</option><option value=\"viewers\">Zuschauer*innen</option></select></label>\n"
    append html "      </div>\n"
    append html "      <div class=\"button-row\">\n"
    append html "        <button id=\"scan-recommendations\" class=\"primary\">Empfehlungen scannen</button>\n"
    append html "        <button id=\"cancel-recommendations\" class=\"secondary\" hidden>Abbrechen</button>\n"
    append html "      </div>\n"
    append html "      <p id=\"recommendation-progress\" class=\"inline-status\" aria-live=\"polite\">Noch kein Scan gestartet.</p>\n"
    append html "      <div id=\"recommendation-list\" class=\"recommendation-list empty\">Noch keine Empfehlungen erfasst.</div>\n"
    append html "      <div id=\"recommendation-actions\" class=\"top-chatters-actions\" hidden>\n"
    append html "        <button id=\"recommendation-more\" class=\"top-chatter-link\" type=\"button\">mehr…</button>\n"
    append html "      </div>\n"
    append html "    </section>\n\n"
    
    # Caption section
    append html "    <section aria-labelledby=\"caption-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"caption-heading\">Titel</h2>\n"
    append html "        <button id=\"scan\" class=\"secondary\">Seite prüfen</button>\n"
    append html "      </div>\n"
    append html "      <div id=\"caption-status\" class=\"status-grid\"></div>\n"
    append html "      <button id=\"enable-captions\" class=\"primary\">Untertitel aktivieren</button>\n"
    append html "      <p id=\"caption-action-status\" role=\"status\" class=\"inline-status action-status\"></p>\n"
    append html "    </section>\n\n"
    
    # Player section
    append html "    <section aria-labelledby=\"player-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"player-heading\">Player</h2>\n"
    append html "        <span id=\"player-time\" class=\"player-time\">–</span>\n"
    append html "      </div>\n"
    append html "      <div class=\"player-controls\" role=\"group\" aria-label=\"TikTok-Player steuern\">\n"
    append html "        <button id=\"player-play\" class=\"secondary compact\">Pause</button>\n"
    append html "        <button id=\"player-replay\" class=\"secondary compact\">Neu laden</button>\n"
    append html "        <button id=\"player-mute\" class=\"secondary compact\">Stumm</button>\n"
    append html "        <button id=\"player-pip\" class=\"secondary compact\">Bild-in-Bild</button>\n"
    append html "        <button id=\"player-fullscreen\" class=\"secondary compact\">Vollbild</button>\n"
    append html "        <button id=\"player-report\" class=\"secondary compact danger-outline\">Melden öffnen</button>\n"
    append html "      </div>\n"
    append html "      <div class=\"audio-controls\">\n"
    append html "        <div class=\"control-label\"><label for=\"player-volume\">Lautstärke</label><output id=\"player-volume-output\" for=\"player-volume\">–</output></div>\n"
    append html "        <input id=\"player-volume\" type=\"range\" min=\"0\" max=\"100\" step=\"1\" value=\"100\">\n"
    append html "        <div class=\"audio-meter-row\"><span>Spitzenpegel</span><strong id=\"player-peak\">–</strong></div>\n"
    append html "        <label class=\"option-row\"><input id=\"limiter-enabled\" type=\"checkbox\"> Pegelschutz aktivieren</label>\n"
    append html "        <div class=\"control-label\"><label for=\"limiter-strength\">Schutzstärke</label><output id=\"limiter-strength-output\" for=\"limiter-strength\">30</output></div>\n"
    append html "        <input id=\"limiter-strength\" type=\"range\" min=\"0\" max=\"100\" step=\"1\" value=\"30\">\n"
    append html "      </div>\n"
    append html "      <p id=\"multi-guest-status\" class=\"inline-status\">Verbundene Streams: noch nicht erkannt.</p>\n"
    append html "      <p id=\"player-status\" role=\"status\" class=\"inline-status\">Warte auf den TikTok-Player.</p>\n"
    append html "    </section>\n\n"
    
    # Song section
    append html "    <section aria-labelledby=\"song-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"song-heading\">Songs</h2>\n"
    append html "        <span id=\"song-led\" class=\"status-led off\" role=\"status\" aria-label=\"Songerkennung inaktiv\"></span>\n"
    append html "      </div>\n"
    append html "      <label class=\"option-row\"><input id=\"song-enabled\" type=\"checkbox\"> Songerkennung aktivieren</label>\n"
    append html "      <button id=\"recognize-song\" class=\"primary\" disabled>Jetzt erkennen</button>\n"
    append html "      <p id=\"song-status\" class=\"inline-status\"></p>\n"
    append html "      <div id=\"song-result\" class=\"song-result\" hidden></div>\n"
    append html "    </section>\n\n"
    
    # Links section
    append html "    <section aria-labelledby=\"links-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"links-heading\">HAR-Logs</h2>\n"
    append html "        <span id=\"media-count\" class=\"count\">0</span>\n"
    append html "      </div>\n"
    append html "      <div id=\"media-list\" class=\"list empty\">Noch keine FLV-/HLS-Links erkannt.</div>\n"
    append html "      <p class=\"hint\">Extern gestarteter VLC liegt außerhalb des Companion-Pegelschutzes.</p>\n"
    append html "    </section>\n\n"
    
    # Log section
    append html "    <section aria-labelledby=\"log-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"log-heading\">LIVE-Logs</h2>\n"
    append html "        <span id=\"caption-count\" class=\"count\">0</span>\n"
    append html "      </div>\n"
    append html "      <div class=\"button-row\">\n"
    append html "        <button id=\"export-log\" class=\"secondary\">JSON-L-Export</button>\n"
    append html "        <button id=\"export-caption-raw\" class=\"secondary\">RAW-JSON-Export</button>\n"
    append html "        <button id=\"clear\" class=\"ghost\">Anzeige leeren</button>\n"
    append html "      </div>\n"
    append html "      <div id=\"caption-list\" class=\"list empty\">Noch keine CaptionMessages empfangen.</div>\n"
    append html "    </section>\n\n"
    
    # Debug section
    append html "    <section aria-labelledby=\"debug-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"debug-heading\">Debugmodus</h2>\n"
    append html "        <span id=\"debug-count\" class=\"count\">0</span>\n"
    append html "      </div>\n"
    append html "      <label class=\"option-row\"><input id=\"debug-enabled\" type=\"checkbox\"> Diagnoseereignisse für diesen Tab protokollieren</label>\n"
    append html "      <div class=\"button-row\">\n"
    append html "        <button id=\"export-debug\" class=\"secondary\">Debug exportieren</button>\n"
    append html "        <button id=\"clear-debug\" class=\"ghost\">Debug leeren</button>\n"
    append html "      </div>\n"
    append html "      <p class=\"muted small\"></p>\n"
    append html "    </section>\n\n"
    
    # Audience modal
    append html "    <div id=\"audience-modal\" class=\"modal-backdrop\" hidden>\n"
    append html "      <section class=\"modal\" role=\"dialog\" aria-modal=\"true\" aria-labelledby=\"audience-heading\">\n"
    append html "        <div class=\"section-title\">\n"
    append html "          <h2 id=\"audience-heading\">Im Chat beobachtete Personen</h2>\n"
    append html "          <button id=\"close-audience\" class=\"secondary compact\" aria-label=\"Übersicht schließen\">Schließen</button>\n"
    append html "        </div>\n"
    append html "        <p id=\"audience-limit\" class=\"inline-status\"></p>\n"
    append html "        <div id=\"audience-list\" class=\"audience-list\"></div>\n"
    append html "      </section>\n"
    append html "    </div>\n\n"
    
    # Speech settings modal
    append html "    <div id=\"speech-settings-modal\" class=\"modal-backdrop\" hidden>\n"
    append html "      <section class=\"modal\" role=\"dialog\" aria-modal=\"true\" aria-labelledby=\"speech-settings-heading\">\n"
    append html "        <div class=\"section-title\">\n"
    append html "          <h2 id=\"speech-settings-heading\">Erweiterte Einstellungen</h2>\n"
    append html "          <button id=\"close-speech-settings\" class=\"secondary compact\" aria-label=\"Einstellungen schließen\">Schließen</button>\n"
    append html "        </div>\n"
    append html "        <div class=\"settings-grid speech-integration-settings\">\n"
    append html "          <label><span>Sprache</span><select id=\"speech-language\"><option value=\"auto\">Auto</option><option value=\"de-DE\">Deutsch</option><option value=\"en-US\">Englisch</option><option value=\"ru-RU\">Russisch</option><option value=\"uk-UA\">Ukrainisch</option><option value=\"bg-BG\">Bulgarisch</option><option value=\"sr-RS\">Serbisch</option><option value=\"kk-KZ\">Kasachisch</option><option value=\"zh-CN\">Chinesisch</option><option value=\"ja-JP\">Japanisch</option><option value=\"ko-KR\">Koreanisch</option><option value=\"ar-JO\">Arabisch</option><option value=\"fa-IR\">Persisch</option><option value=\"ur-PK\">Urdu</option><option value=\"hi-IN\">Hindi</option><option value=\"ne-NP\">Nepali</option><option value=\"ml-IN\">Malayalam</option></select></label>\n"
    append html "          <label><span>Stimme</span><select id=\"speech-voice\"><option value=\"\">Standard</option></select></label>\n"
    append html "          <label id=\"audd-token-setting\"><span id=\"audd-token-label\">AudD API-Token (optional - <a href=\"https://audd.io/\" target=\"_blank\" rel=\"noopener noreferrer\">https://AudD.io</a> Trial/Paid)</span><input id=\"audd-token\" type=\"password\" autocomplete=\"off\" spellcheck=\"false\"></label>\n"
    append html "          <label id=\"pairing-code-setting\"><span>Pairing-Code</span><input id=\"pairing-code\" type=\"password\" autocomplete=\"off\" spellcheck=\"false\"></label>\n"
    append html "          <label><span>Universal API-Key</span><input id=\"universal-caption-api-key\" type=\"password\" autocomplete=\"off\" spellcheck=\"false\"></label>\n"
    append html "        </div>\n"
    append html "        <label class=\"option-row\"><input id=\"speak-names\" type=\"checkbox\" checked> Chatnamen sprechen</label>\n"
    append html "        <label class=\"option-row\"><input id=\"shorten-names\" type=\"checkbox\"> Chatnamen kürzen</label>\n"
    append html "        <label class=\"option-row auto-chat-refresh\"><input id=\"auto-chat-refresh\" type=\"checkbox\"> Auto-Chat Refresh <input id=\"auto-chat-refresh-minutes\" type=\"number\" min=\"1\" max=\"60\" step=\"1\" value=\"5\" inputmode=\"numeric\" aria-label=\"Auto-Chat-Refresh in Minuten\"><span>min.</span></label>\n"
    append html "        <label class=\"option-row\"><input id=\"game-mode\" type=\"checkbox\"> Game-Mode</label>\n"
    append html "        <label class=\"option-row\"><input id=\"filter-external-speech-triggers\" type=\"checkbox\"> Trigger externer Sprachdienste filtern</label>\n"
    append html "      </section>\n"
    append html "    </div>\n\n"
    
    # Chat history modal
    append html "    <div id=\"chat-history-modal\" class=\"modal-backdrop\" hidden>\n"
    append html "      <section class=\"modal\" role=\"dialog\" aria-modal=\"true\" aria-labelledby=\"chat-history-heading\">\n"
    append html "        <div class=\"section-title\">\n"
    append html "          <h2 id=\"chat-history-heading\">Gesammelte Chatnachrichten</h2>\n"
    append html "          <button id=\"close-chat-history\" class=\"secondary compact\" aria-label=\"Chatzeilen schließen\">Schließen</button>\n"
    append html "        </div>\n"
    append html "        <p id=\"chat-history-limit\" class=\"inline-status\"></p>\n"
    append html "        <div id=\"chat-history-list\" class=\"chat-history-list\"></div>\n"
    append html "      </section>\n"
    append html "    </div>\n\n"
    
    # Recommendation modal
    append html "    <div id=\"recommendation-modal\" class=\"modal-backdrop\" hidden>\n"
    append html "      <section class=\"modal\" role=\"dialog\" aria-modal=\"true\" aria-labelledby=\"recommendation-modal-heading\">\n"
    append html "        <div class=\"section-title\">\n"
    append html "          <h2 id=\"recommendation-modal-heading\">Gescannte LIVE-Empfehlungen</h2>\n"
    append html "          <button id=\"close-recommendations\" class=\"secondary compact\" aria-label=\"Empfehlungen schließen\">Schließen</button>\n"
    append html "        </div>\n"
    append html "        <div id=\"recommendation-modal-list\" class=\"recommendation-list\"></div>\n"
    append html "      </section>\n"
    append html "    </div>\n\n"
    
    # Notice
    append html "    <p id=\"notice\" role=\"alert\" class=\"notice\"></p>\n"
    append html "  </main>\n"
    
    # Connection settings modal
    append html "  <div id=\"connection-settings-modal\" class=\"modal-backdrop\" hidden>\n"
    append html "    <section class=\"modal\" role=\"dialog\" aria-modal=\"true\" aria-labelledby=\"connection-settings-heading\">\n"
    append html "      <div class=\"section-title\"><h2 id=\"connection-settings-heading\">Connection-Einstellungen</h2><button id=\"close-connection-settings\" class=\"secondary compact\">Schließen</button></div>\n"
    append html "      <label class=\"option-row quick-recover-setting\"><input id=\"hook-reconnect\" type=\"checkbox\"> Hook-Reconnect <input id=\"hook-reconnect-seconds\" type=\"number\" min=\"1\" max=\"59\" step=\"1\" value=\"3\" inputmode=\"numeric\" aria-label=\"Hook-Reconnect-Wartezeit in Sekunden\"><span>Sek.</span></label>\n"
    append html "      <label class=\"option-row quick-recover-setting\"><input id=\"quick-recover\" type=\"checkbox\"> Player-Recovery <input id=\"quick-recover-seconds\" type=\"number\" min=\"1\" max=\"59\" step=\"1\" value=\"3\" inputmode=\"numeric\" aria-label=\"Player-Recovery-Bestätigungszeit in Sekunden\"><span>Sek.</span></label>\n"
    append html "    </section>\n"
    append html "  </div>\n\n"
    
    append html "  <script src=\"content-core.js\"></script>\n"
    append html "  <script src=\"sidepanel.js\"></script>\n"
    append html "</body>\n"
    append html "</html>\n"
    
    return $html
}

# Main execution
if {$argc != 1} {
    puts "Usage: $argv0 <output_file>"
    exit 1
}

set output_file [lindex $argv 0]
set html_content [generateSidePanel]

if {[catch {open $output_file w} file_handle]} {
    puts "Error: Could not open file $output_file for writing"
    exit 1
}

puts $file_handle $html_content
close $file_handle

puts "HTML file generated successfully: $output_file"
