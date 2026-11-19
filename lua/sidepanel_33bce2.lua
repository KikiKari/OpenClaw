#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "a0c1896a91984a91931126b381cf1d472b80675453ee1c31e5f6b8610e91cfc9", "source_sha256": "33bce2f5c12f5d03ec1a284c7b5c469f5d342e51ea8090b34282ef29b144aa44", "target_language": "lua"}
-- sidepanel.html — portiert nach lua
-- Quelle: html, Projects@TikTok-Live-Companion:release/0.6.0/tiktok-live-companion-extension-0.6.0/sidepanel.html
-- auch in: Projects@TikTok-Live-Companion:release/0.7.0/tiktok-live-companion-extension-0.7.0/sidepanel.html
-- auch in: Projects@TikTok-Live-Companion-Android:release/0.6.0/tiktok-live-companion-extension-0.6.0/sidepanel.html
-- auch in: Projects@TikTok-Live-Companion-Android:release/0.7.0/tiktok-live-companion-extension-0.7.0/sidepanel.html
-- auch in: 2 weiteren Fundstellen
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local function create_sidepanel_html()
    local html = {}

    -- Start with DOCTYPE and html tag
    table.insert(html, "<!doctype html>")
    table.insert(html, "<html lang=\"de\">")
    
    -- Head section
    table.insert(html, "<head>")
    table.insert(html, "  <meta charset=\"utf-8\">")
    table.insert(html, "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">")
    table.insert(html, "  <title>TikTok LIVE Companion</title>")
    table.insert(html, "  <link rel=\"stylesheet\" href=\"sidepanel.css\">")
    table.insert(html, "</head>")
    
    -- Body start
    table.insert(html, "<body>")
    
    -- Header
    table.insert(html, "  <header>")
    table.insert(html, "    <p id=\"page-title\" class=\"muted\">Kein TikTok-Tab ausgewählt</p>")
    table.insert(html, "  </header>")
    
    -- Main content
    table.insert(html, "  <main>")
    
    -- Chat section
    table.insert(html, "    <section aria-labelledby=\"chat-heading\">")
    table.insert(html, "      <div class=\"section-title\">")
    table.insert(html, "        <h2 id=\"chat-heading\">Chatzeilen</h2>")
    table.insert(html, "        <div class=\"title-actions\">")
    table.insert(html, "          <span id=\"chat-led\" class=\"status-led off\" role=\"status\" aria-label=\"Chat inaktiv\" title=\"Chat inaktiv\"></span>")
    table.insert(html, "          <span id=\"chat-count\" class=\"count\">0</span>")
    table.insert(html, "          <button id=\"refresh-chat\" class=\"secondary compact\" title=\"Chatanzeige leeren\">Refresh</button>")
    table.insert(html, "          <button id=\"toggle-speech\" class=\"secondary compact\" aria-pressed=\"false\">Vorlesen an</button>")
    table.insert(html, "          <span id=\"speech-led\" class=\"status-led off\" role=\"status\" aria-label=\"Vorlesen inaktiv\" title=\"Vorlesen inaktiv\"></span>")
    table.insert(html, "        </div>")
    table.insert(html, "      </div>")
    table.insert(html, "      <div id=\"chat-list\" class=\"chat-list empty\" role=\"log\" aria-live=\"polite\" aria-relevant=\"additions\" aria-label=\"Die letzten fünf bereinigten Chatnachrichten\">Noch keine Chatnachrichten erkannt.</div>")
    table.insert(html, "      <p id=\"speech-status\" role=\"status\" class=\"inline-status\">Vorlesen ist ausgeschaltet.</p>")
    table.insert(html, "      <div class=\"control-label\"><label for=\"speech-volume\">Vorleselautstärke</label><output id=\"speech-volume-output\" for=\"speech-volume\">100%</output></div>")
    table.insert(html, "      <input id=\"speech-volume\" type=\"range\" min=\"0\" max=\"100\" step=\"5\" value=\"50\">")
    table.insert(html, "      <div class=\"settings-grid speech-settings\">")
    table.insert(html, "        <label><span>Sprache</span><select id=\"speech-language\"><option value=\"auto\">Auto</option><option value=\"de-DE\">Deutsch</option><option value=\"en-US\">Englisch</option></select></label>")
    table.insert(html, "        <label><span>Dienstadresse</span><input id=\"service-url\" type=\"url\" value=\"http://127.0.0.1:43117\" spellcheck=\"false\"></label>")
    table.insert(html, "        <label><span>Pairing-Code</span><input id=\"pairing-code\" type=\"password\" autocomplete=\"off\"></label>")
    table.insert(html, "      </div>")
    table.insert(html, "      <p id=\"service-status\" class=\"inline-status\">Lokaler Sprachdienst noch nicht geprüft.</p>")
    table.insert(html, "      <label class=\"option-row\"><input id=\"speak-names\" type=\"checkbox\" checked> Chatnamen vorlesen</label>")
    table.insert(html, "      <label class=\"option-row\"><input id=\"shorten-names\" type=\"checkbox\"> Geeignete lange Namen kürzen</label>")
    table.insert(html, "      <label class=\"option-row\"><input id=\"keep-speech-active\" type=\"checkbox\"> Vorlesen bei Tabwechsel oder Minimieren aktiv lassen</label>")
    table.insert(html, "    </section>")
    
    -- Top chatters section
    table.insert(html, "    <section aria-labelledby=\"top-chatters-heading\">")
    table.insert(html, "      <div class=\"section-title\">")
    table.insert(html, "        <h2 id=\"top-chatters-heading\">Top-Chatter</h2>")
    table.insert(html, "        <button id=\"open-audience\" class=\"secondary compact\">Zuschauer*innen</button>")
    table.insert(html, "      </div>")
    table.insert(html, "      <p id=\"team-tag-status\" class=\"inline-status\">Teamkürzel: noch nicht erkannt.</p>")
    table.insert(html, "      <div id=\"top-chatters\" class=\"top-chatters empty\">Noch keine Personen im Chat beobachtet.</div>")
    table.insert(html, "    </section>")
    
    -- Song recognition section
    table.insert(html, "    <section aria-labelledby=\"song-heading\">")
    table.insert(html, "      <div class=\"section-title\">")
    table.insert(html, "        <h2 id=\"song-heading\">Songerkennung</h2>")
    table.insert(html, "        <span id=\"song-led\" class=\"status-led off\" role=\"status\" aria-label=\"Songerkennung inaktiv\"></span>")
    table.insert(html, "      </div>")
    table.insert(html, "      <label class=\"option-row\"><input id=\"song-enabled\" type=\"checkbox\"> Songerkennung aktivieren</label>")
    table.insert(html, "      <button id=\"recognize-song\" class=\"primary\" disabled>Jetzt erkennen</button>")
    table.insert(html, "      <p id=\"song-status\" class=\"inline-status\">Es wird nichts aufgenommen oder übertragen.</p>")
    table.insert(html, "      <div id=\"song-result\" class=\"song-result\" hidden></div>")
    table.insert(html, "      <p class=\"muted small\">Nach einem Klick werden etwa 12 Sekunden Tab-Audio über den lokalen Dienst an AudD übertragen. Anbietergebühren können anfallen.</p>")
    table.insert(html, "    </section>")
    
    -- Captions section
    table.insert(html, "    <section aria-labelledby=\"caption-heading\">")
    table.insert(html, "      <div class=\"section-title\">")
    table.insert(html, "        <h2 id=\"caption-heading\">Untertitel</h2>")
    table.insert(html, "        <button id=\"scan\" class=\"secondary\">Seite prüfen</button>")
    table.insert(html, "      </div>")
    table.insert(html, "      <div id=\"caption-status\" class=\"status-grid\"></div>")
    table.insert(html, "      <button id=\"enable-captions\" class=\"primary\">Untertitel aktivieren</button>")
    table.insert(html, "      <p id=\"caption-action-status\" role=\"status\" class=\"inline-status action-status\">Noch keine manuelle Prüfung ausgeführt.</p>")
    table.insert(html, "    </section>")
    
    -- WebSocket hook section
    table.insert(html, "    <section aria-labelledby=\"hook-heading\">")
    table.insert(html, "      <div class=\"section-title\">")
    table.insert(html, "        <h2 id=\"hook-heading\">WebSocket-Hook</h2>")
    table.insert(html, "        <span id=\"hook-led\" class=\"status-led off\" role=\"status\" aria-label=\"Hook inaktiv\" title=\"Hook inaktiv\"></span>")
    table.insert(html, "      </div>")
    table.insert(html, "      <p class=\"muted small\">Der Hook wird vor dem Player-Code gesetzt. Der aktuelle Tab wird danach neu geladen.</p>")
    table.insert(html, "      <div class=\"button-row\">")
    table.insert(html, "        <button id=\"enable-hook\" class=\"primary\">Hook setzen</button>")
    table.insert(html, "        <button id=\"disable-hook\" class=\"secondary\">Hook deaktivieren</button>")
    table.insert(html, "        <button id=\"reset-tab\" class=\"secondary danger-outline\">Refresh</button>")
    table.insert(html, "      </div>")
    table.insert(html, "      <p id=\"hook-status\" class=\"inline-status\"></p>")
    table.insert(html, "      <label class=\"option-row\"><input id=\"hook-autostart\" type=\"checkbox\"> Hook beim Öffnen von TikTok automatisch starten</label>")
    table.insert(html, "      <p class=\"muted small reset-note\">Refresh leert nur die flüchtigen Daten dieses Tabs, aktiviert den Hook erneut und lädt TikTok ohne Seitencache. cookies bleiben unverändert.</p>")
    table.insert(html, "    </section>")
    
    -- Live stats section
    table.insert(html, "    <section aria-labelledby=\"stats-heading\">")
    table.insert(html, "      <div class=\"section-title\">")
    table.insert(html, "        <h2 id=\"stats-heading\">LIVE-Informationen</h2>")
    table.insert(html, "        <span id=\"stats-live\" class=\"live-indicator\">warte</span>")
    table.insert(html, "      </div>")
    table.insert(html, "      <div id=\"live-stats\" class=\"status-grid stats-grid\"></div>")
    table.insert(html, "      <p id=\"stats-status\" class=\"inline-status\">Der WebSocket-Hook liefert die Werte nach dem Neuladen des Streams.</p>")
    table.insert(html, "    </section>")
    
    -- Player control section
    table.insert(html, "    <section aria-labelledby=\"player-heading\">")
    table.insert(html, "      <div class=\"section-title\">")
    table.insert(html, "        <h2 id=\"player-heading\">Playersteuerung</h2>")
    table.insert(html, "        <span id=\"player-time\" class=\"player-time\">–</span>")
    table.insert(html, "      </div>")
    table.insert(html, "      <div class=\"player-controls\" role=\"group\" aria-label=\"TikTok-Player steuern\">")
    table.insert(html, "        <button id=\"player-play\" class=\"secondary compact\">Pause</button>")
    table.insert(html, "        <button id=\"player-replay\" class=\"secondary compact\">Neu laden</button>")
    table.insert(html, "        <button id=\"player-mute\" class=\"secondary compact\">Stumm</button>")
    table.insert(html, "        <button id=\"player-pip\" class=\"secondary compact\">Bild-in-Bild</button>")
    table.insert(html, "        <button id=\"player-fullscreen\" class=\"secondary compact\">Vollbild</button>")
    table.insert(html, "        <button id=\"player-report\" class=\"secondary compact danger-outline\">Melden öffnen</button>")
    table.insert(html, "      </div>")
    table.insert(html, "      <div class=\"audio-controls\">")
    table.insert(html, "        <div class=\"control-label\"><label for=\"player-volume\">Lautstärke</label><output id=\"player-volume-output\" for=\"player-volume\">–</output></div>")
    table.insert(html, "        <input id=\"player-volume\" type=\"range\" min=\"0\" max=\"100\" step=\"1\" value=\"100\">")
    table.insert(html, "        <div class=\"audio-meter-row\"><span>Digitaler Spitzenpegel</span><strong id=\"player-peak\">– dBFS</strong></div>")
    table.insert(html, "        <label class=\"option-row\"><input id=\"limiter-enabled\" type=\"checkbox\"> Digitalen Pegelschutz aktivieren</label>")
    table.insert(html, "        <div class=\"control-label\"><label for=\"limiter-threshold\">Grenzwert</label><output id=\"limiter-threshold-output\" for=\"limiter-threshold\">−6 dBFS</output></div>")
    table.insert(html, "        <input id=\"limiter-threshold\" type=\"range\" min=\"-30\" max=\"-1\" step=\"1\" value=\"-6\">")
    table.insert(html, "        <p class=\"muted small audio-note\">dBFS ist ein digitaler Signalpegel, kein am Ohr messbarer dB-SPL-Wert. Der Schutz komprimiert Spitzen oberhalb des Grenzwerts lokal im Browser.</p>")
    table.insert(html, "      </div>")
    table.insert(html, "      <p id=\"multi-guest-status\" class=\"inline-status\">Verbundene Streams: noch nicht erkannt.</p>")
    table.insert(html, "      <p id=\"player-status\" role=\"status\" class=\"inline-status\">Warte auf den TikTok-Player.</p>")
    table.insert(html, "    </section>")
    
    -- Page info section
    table.insert(html, "    <section id=\"page-info-section\" aria-labelledby=\"page-info-heading\">")
    table.insert(html, "      <div class=\"section-title\">")
    table.insert(html, "        <h2 id=\"page-info-heading\">Seiteninformationen</h2>")
    table.insert(html, "        <div class=\"title-actions\">")
    table.insert(html, "          <span id=\"page-info-source\" class=\"live-indicator\">Metadaten</span>")
    table.insert(html, "          <button id=\"refresh-page-info\" class=\"secondary compact\">Refresh</button>")
    table.insert(html, "          <button id=\"force-page-info\" class=\"secondary compact danger-outline\">Force</button>")
    table.insert(html, "        </div>")
    table.insert(html, "      </div>")
    table.insert(html, "      <div id=\"profile-info\" class=\"profile-info\" hidden></div>")
    table.insert(html, "      <div id=\"summary-info\" class=\"summary-info\"></div>")
    table.insert(html, "    </section>")
    
    -- Quality section
    table.insert(html, "    <section aria-labelledby=\"quality-heading\">")
    table.insert(html, "      <div class=\"section-title\">")
    table.insert(html, "        <h2 id=\"quality-heading\">Verfügbare Bildqualitäten</h2>")
    table.insert(html, "        <span id=\"quality-count\" class=\"count\">0</span>")
    table.insert(html, "      </div>")
    table.insert(html, "      <div id=\"quality-list\" class=\"list empty\">Noch keine Qualitätsstufen aus den Stream-Metadaten erkannt.</div>")
    table.insert(html, "      <p id=\"quality-action-status\" role=\"status\" class=\"inline-status\"></p>")
    table.insert(html, "    </section>")
    
    -- VLC links section
    table.insert(html, "    <section aria-labelledby=\"links-heading\">")
    table.insert(html, "      <div class=\"section-title\">")
    table.insert(html, "        <h2 id=\"links-heading\">VLC-Links</h2>")
    table.insert(html, "        <span id=\"media-count\" class=\"count\">0</span>")
    table.insert(html, "      </div>")
    table.insert(html, "      <div id=\"media-list\" class=\"list empty\">Noch keine FLV-/HLS-Links erkannt.</div>")
    table.insert(html, "    </section>")
    
    -- Log section
    table.insert(html, "    <section aria-labelledby=\"log-heading\">")
    table.insert(html, "      <div class=\"section-title\">")
    table.insert(html, "        <h2 id=\"log-heading\">Caption-Protokoll</h2>")
    table.insert(html, "        <span id=\"caption-count\" class=\"count\">0</span>")
    table.insert(html, "      </div>")
    table.insert(html, "      <div class=\"button-row\">")
    table.insert(html, "        <button id=\"export-log\" class=\"secondary\">JSONL exportieren</button>")
    table.insert(html, "        <button id=\"clear\" class=\"ghost\">Anzeige leeren</button>")
    table.insert(html, "      </div>")
    table.insert(html, "      <div id=\"caption-list\" class=\"list empty\">Noch keine CaptionMessages empfangen.</div>")
    table.insert(html, "    </section>")
    
    -- Debug section
    table.insert(html, "    <section aria-labelledby=\"debug-heading\">")
    table.insert(html, "      <div class=\"section-title\">")
    table.insert(html, "        <h2 id=\"debug-heading\">Debugmodus</h2>")
    table.insert(html, "        <span id=\"debug-count\" class=\"count\">0</span>")
    table.insert(html, "      </div>")
    table.insert(html, "      <label class=\"option-row\"><input id=\"debug-enabled\" type=\"checkbox\"> Diagnoseereignisse für diesen Tab protokollieren</label>")
    table.insert(html, "      <div class=\"button-row\">")
    table.insert(html, "        <button id=\"export-debug\" class=\"secondary\">Debug exportieren</button>")
    table.insert(html, "        <button id=\"clear-debug\" class=\"ghost\">Debug leeren</button>")
    table.insert(html, "      </div>")
    table.insert(html, "      <p class=\"muted small\">Der Export entfernt Werte signierter URL-Parameter und enthält keine cookies oder API-Keys.</p>")
    table.insert(html, "    </section>")
    
    -- Audience modal
    table.insert(html, "    <div id=\"audience-modal\" class=\"modal-backdrop\" hidden>")
    table.insert(html, "      <section class=\"modal\" role=\"dialog\" aria-modal=\"true\" aria-labelledby=\"audience-heading\">")
    table.insert(html, "        <div class=\"section-title\">")
    table.insert(html, "          <h2 id=\"audience-heading\">Im Chat beobachtete Personen</h2>")
    table.insert(html, "          <button id=\"close-audience\" class=\"secondary compact\" aria-label=\"Übersicht schließen\">Schließen</button>")
    table.insert(html, "        </div>")
    table.insert(html, "        <p id=\"audience-limit\" class=\"inline-status\"></p>")
    table.insert(html, "        <div id=\"audience-list\" class=\"audience-list\"></div>")
    table.insert(html, "      </section>")
    table.insert(html, "    </div>")
    
    -- Notice
    table.insert(html, "    <p id=\"notice\" role=\"alert\" class=\"notice\"></p>")
    table.insert(html, "  </main>")
    
    -- Scripts
    table.insert(html, "  <script src=\"content-core.js\"></script>")
    table.insert(html, "  <script src=\"sidepanel.js\"></script>")
    table.insert(html, "</body>")
    table.insert(html, "</html>")
    
    return table.concat(html, "\n")
end

-- Main execution
local output_file = arg[1] or "sidepanel.html"
local file = io.open(output_file, "w")
if not file then
    print("Error: Could not open file " .. output_file .. " for writing")
    os.exit(1)
end

file:write(create_sidepanel_html())
file:close()

print("HTML file generated: " .. output_file)
