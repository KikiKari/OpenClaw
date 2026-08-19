#!/usr/bin/env tclsh
# sidepanel.html — portiert nach tcl
# Quelle: html, Projects@TikTok-Live-Companion:release/0.7.1/tiktok-live-companion-extension-0.7.1/sidepanel.html
# auch in: Projects@TikTok-Live-Companion-Android:release/0.7.1/tiktok-live-companion-extension-0.7.1/sidepanel.html
# auch in: Projects@TikTok-Live-Companion-iOS:release/0.7.1/tiktok-live-companion-extension-0.7.1/sidepanel.html
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 Script zur Erzeugung der sidepanel.html-Struktur
# Dieses Skript generiert dynamisch das HTML-Dokument basierend auf der gegebenen Struktur.

proc generate_sidepanel_html {} {
    set html {}

    # DOCTYPE und HTML-Start
    append html "<!doctype html>\n"
    append html "<html lang=\"de\">\n"

    # HEAD-Bereich
    append html "<head>\n"
    append html "  <meta charset=\"utf-8\">\n"
    append html "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
    append html "  <title>TikTok LIVE Companion</title>\n"
    append html "  <link rel=\"stylesheet\" href=\"sidepanel.css\">\n"
    append html "</head>\n"

    # BODY-Bereich
    append html "<body>\n"

    # Header
    append html "  <header>\n"
    append html "    <p id=\"page-title\" class=\"muted\">Kein TikTok-Tab ausgewählt</p>\n"
    append html "  </header>\n\n"

    # Main Content
    append html "  <main>\n"

    # Chat Section
    append html "    <section aria-labelledby=\"chat-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"chat-heading\">Chatzeilen</h2>\n"
    append html "        <div class=\"title-actions\">\n"
    append html "          <span id=\"chat-led\" class=\"status-led off\" role=\"status\" aria-label=\"Chat inaktiv\" title=\"Chat inaktiv\"></span>\n"
    append html "          <button id=\"chat-count\" class=\"count count-button\" type=\"button\" aria-haspopup=\"dialog\" title=\"Gesammelte Chatzeilen öffnen\">0</button>\n"
    append html "          <button id=\"refresh-chat\" class=\"secondary compact\" title=\"Chatanzeige leeren\">Refresh</button>\n"
    append html "          <button id=\"toggle-speech\" class=\"secondary compact\" aria-pressed=\"false\">Vorlesen an</button>\n"
    append html "          <span id=\"speech-led\" class=\"status-led off\" role=\"status\" aria-label=\"Vorlesen inaktiv\" title=\"Vorlesen inaktiv\"></span>\n"
    append html "        </div>\n"
    append html "      </div>\n"
    append html "      <div id=\"chat-list\" class=\"chat-list empty\" role=\"log\" aria-live=\"polite\" aria-relevant=\"additions\" aria-label=\"Die letzten fünf bereinigten Chatnachrichten\">Noch keine Chatnachrichten erkannt.</div>\n"
    append html "      <p id=\"speech-status\" role=\"status\" class=\"inline-status\">Vorlesen ist ausgeschaltet.</p>\n"
    append html "      <div class=\"control-label\"><label for=\"speech-volume\">Vorleselautstärke</label><output id=\"speech-volume-output\" for=\"speech-volume\">100%</output></div>\n"
    append html "      <input id=\"speech-volume\" type=\"range\" min=\"0\" max=\"100\" step=\"5\" value=\"50\">\n"
    append html "      <div class=\"settings-grid speech-settings\">\n"
    append html "        <label><span>Sprache</span><select id=\"speech-language\"><option value=\"auto\">Auto</option><option value=\"de-DE\">Deutsch</option><option value=\"en-US\">Englisch</option><option value=\"ru-RU\">Russisch</option><option value=\"uk-UA\">Ukrainisch</option><option value=\"bg-BG\">Bulgarisch</option><option value=\"sr-RS\">Serbisch</option><option value=\"kk-KZ\">Kasachisch</option><option value=\"zh-CN\">Chinesisch</option><option value=\"ja-JP\">Japanisch</option><option value=\"ko-KR\">Koreanisch</option><option value=\"ar-JO\">Arabisch</option><option value=\"fa-IR\">Persisch</option><option value=\"ur-PK\">Urdu</option><option value=\"hi-IN\">Hindi</option><option value=\"ne-NP\">Nepali</option><option value=\"ml-IN\">Malayalam</option></select></label>\n"
    append html "        <label><span>Stimme</span><select id=\"speech-voice\"><option value=\"\">Standard</option></select></label>\n"
    append html "        <label id=\"audd-token-setting\"><span id=\"audd-token-label\">AudD API-Token (optional - <a href=\"https://audd.io/\" target=\"_blank\" rel=\"noopener noreferrer\">https://AudD.io</a> Trial/Paid )</span><input id=\"audd-token\" type=\"password\" autocomplete=\"off\" spellcheck=\"false\"></label>\n"
    append html "        <label id=\"pairing-code-setting\"><span>Pairing-Code</span><input id=\"pairing-code\" type=\"password\" autocomplete=\"off\" spellcheck=\"false\"></label>\n"
    append html "      </div>\n"
    append html "      <div class=\"button-row\">\n"
    append html "        <button id=\"service-action\" class=\"secondary\">Sprachdienst installieren</button>\n"
    append html "        <button id=\"sherpa-action\" class=\"secondary\">Sherpa installieren</button>\n"
    append html "      </div>\n"
    append html "      <p id=\"service-status\" class=\"inline-status\">Lokaler Sprachdienst noch nicht geprüft.</p>\n"
    append html "      <div id=\"service-setup\" class=\"inline-status\" hidden>\n"
    append html "        <button id=\"copy-service-setup\" class=\"secondary compact\">Installation abschließen!</button>\n"
    append html "      </div>\n"
    append html "      <label class=\"option-row\"><input id=\"speak-names\" type=\"checkbox\" checked> Chatnamen sprechen</label>\n"
    append html "      <label class=\"option-row\"><input id=\"shorten-names\" type=\"checkbox\"> Chatnamen kürzen</label>\n"
    append html "      <label class=\"option-row\"><input id=\"game-mode\" type=\"checkbox\"> Game-Mode</label>\n"
    append html "      <label class=\"option-row auto-chat-refresh\"><input id=\"auto-chat-refresh\" type=\"checkbox\"> Auto-Chat Refresh <input id=\"auto-chat-refresh-minutes\" type=\"number\" min=\"1\" max=\"60\" step=\"1\" value=\"5\" inputmode=\"numeric\" aria-label=\"Auto-Chat-Refresh in Minuten\"><span>min.</span></label>\n"
    append html "      <label class=\"option-row\"><input id=\"keep-speech-active\" type=\"checkbox\"> Permanent aktiv</label>\n"
    append html "    </section>\n\n"

    # Top Chatters Section
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

    # Page Info Section
    append html "    <section id=\"page-info-section\" aria-labelledby=\"page-info-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"page-info-heading\">Seiteninformationen</h2>\n"
    append html "        <div class=\"title-actions\">\n"
    append html "          <span id=\"page-info-source\" class=\"live-indicator\">Metadaten</span>\n"
    append html "          <button id=\"refresh-page-info\" class=\"secondary compact\">Refresh</button>\n"
    append html "          <button id=\"force-page-info\" class=\"secondary compact danger-outline\">Force</button>\n"
    append html "        </div>\n"
    append html "      </div>\n"
    append html "      <div id=\"profile-info\" class=\"profile-info\" hidden></div>\n"
    append html "      <div id=\"summary-info\" class=\"summary-info\"></div>\n"
    append html "    </section>\n\n"

    # Stats Section
    append html "    <section aria-labelledby=\"stats-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"stats-heading\">LIVE-Informationen</h2>\n"
    append html "        <span id=\"stats-live\" class=\"live-indicator\">warte</span>\n"
    append html "      </div>\n"
    append html "      <div id=\"live-stats\" class=\"status-grid stats-grid\"></div>\n"
    append html "      <p id=\"stats-status\" class=\"inline-status\"></p>\n"
    append html "    </section>\n\n"

    # WebSocket Hook Section
    append html "    <section aria-labelledby=\"hook-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"hook-heading\">WebSocket-Hook</h2>\n"
    append html "        <span id=\"hook-led\" class=\"status-led off\" role=\"status\" aria-label=\"Hook inaktiv\" title=\"Hook inaktiv\"></span>\n"
    append html "      </div>\n"
    append html "      <div class=\"button-row\">\n"
    append html "        <button id=\"enable-hook\" class=\"primary\">Hook setzen</button>\n"
    append html "        <button id=\"disable-hook\" class=\"secondary\">Hook deaktivieren</button>\n"
    append html "        <button id=\"reset-tab\" class=\"secondary danger-outline\">Refresh</button>\n"
    append html "        <button id=\"open-embed-live\" class=\"secondary\">Embed</button>\n"
    append html "        <button id=\"open-normal-live\" class=\"secondary\">Normal</button>\n"
    append html "        <button id=\"player-vlc-frame\" class=\"secondary compact\">VLC Ersatz</button>\n"
    append html "      </div>\n"
    append html "      <p id=\"hook-status\" class=\"inline-status\"></p>\n"
    append html "      <label class=\"option-row\"><input id=\"hook-autostart\" type=\"checkbox\"> Permanent Hook</label>\n"
    append html "      <label class=\"option-row\"><input id=\"quick-recover\" type=\"checkbox\"> Auto-Reconnect</label>\n"
    append html "    </section>\n\n"

    # Captions Section
    append html "    <section aria-labelledby=\"caption-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"caption-heading\">Untertitel</h2>\n"
    append html "        <button id=\"scan\" class=\"secondary\">Seite prüfen</button>\n"
    append html "      </div>\n"
    append html "      <div id=\"caption-status\" class=\"status-grid\"></div>\n"
    append html "      <button id=\"enable-captions\" class=\"primary\">Untertitel aktivieren</button>\n"
    append html "      <p id=\"caption-action-status\" role=\"status\" class=\"inline-status action-status\"></p>\n"
    append html "    </section>\n\n"

    # Player Control Section
    append html "    <section aria-labelledby=\"player-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"player-heading\">Playersteuerung</h2>\n"
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

    # Song Recognition Section
    append html "    <section aria-labelledby=\"song-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"song-heading\">Songerkennung</h2>\n"
    append html "        <span id=\"song-led\" class=\"status-led off\" role=\"status\" aria-label=\"Songerkennung inaktiv\"></span>\n"
    append html "      </div>\n"
    append html "      <label class=\"option-row\"><input id=\"song-enabled\" type=\"checkbox\"> Songerkennung aktivieren</label>\n"
    append html "      <button id=\"recognize-song\" class=\"primary\" disabled>Jetzt erkennen</button>\n"
    append html "      <p id=\"song-status\" class=\"inline-status\"></p>\n"
    append html "      <div id=\"song-result\" class=\"song-result\" hidden></div>\n"
    append html "    </section>\n\n"

    # VLC Links Section
    append html "    <section aria-labelledby=\"links-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"links-heading\">VLC-Links</h2>\n"
    append html "        <span id=\"media-count\" class=\"count\">0</span>\n"
    append html "      </div>\n"
    append html "      <div id=\"media-list\" class=\"list empty\">Noch keine FLV-/HLS-Links erkannt.</div>\n"
    append html "    </section>\n\n"

    # Caption Log Section
    append html "    <section aria-labelledby=\"log-heading\">\n"
    append html "      <div class=\"section-title\">\n"
    append html "        <h2 id=\"log-heading\">Caption-Protokoll</h2>\n"
    append html "        <span id=\"caption-count\" class=\"count\">0</span>\n"
    append html "      </div>\n"
    append html "      <div class=\"button-row\">\n"
    append html "        <button id=\"export-log\" class=\"secondary\">JSONL exportieren</button>\n"
    append html "        <button id=\"clear\" class=\"ghost\">Anzeige leeren</button>\n"
    append html "      </div>\n"
    append html "      <div id=\"caption-list\" class=\"list empty\">Noch keine CaptionMessages empfangen.</div>\n"
    append html "    </section>\n\n"

    # Debug Section
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

    # Audience Modal
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

    # Chat History Modal
    append html "    <div id=\"chat-history-modal\" class=\"modal-backdrop\" hidden>\n"
    append html "      <section class=\"modal\" role=\"dialog\" aria-modal=\"true\" aria-labelledby=\"chat-history-heading\">\n"
    append html "        <div class=\"section-title\">\n"
    append html "          <h2 id=\"chat-history-heading\">Gesammelte Chatzeilen</h2>\n"
    append html "          <button id=\"close-chat-history\" class=\"secondary compact\" aria-label=\"Chatzeilen schließen\">Schließen</button>\n"
    append html "        </div>\n"
    append html "        <p id=\"chat-history-limit\" class=\"inline-status\"></p>\n"
    append html "        <div id=\"chat-history-list\" class=\"chat-history-list\"></div>\n"
    append html "      </section>\n"
    append html "    </div>\n\n"

    # Notice
    append html "    <p id=\"notice\" role=\"alert\" class=\"notice\"></p>\n"
    append html "  </main>\n\n"

    # Scripts
    append html "  <script src=\"content-core.js\"></script>\n"
    append html "  <script src=\"sidepanel.js\"></script>\n"

    # Closing tags
    append html "</body>\n"
    append html "</html>\n"

    return $html
}

# Hauptprogramm
if {$argc != 1} {
    puts stderr "Verwendung: $argv0 <ausgabedatei>"
    exit 1
}

set output_file [lindex $argv 0]
set html_content [generate_sidepanel_html]

# Schreiben in Datei
if {[catch {open $output_file w} fid]} {
    puts stderr "Fehler beim Öffnen der Datei '$output_file': $fid"
    exit 1
}

puts -nonewline $fid $html_content
close $fid

puts "HTML-Datei erfolgreich erstellt: $output_file"
