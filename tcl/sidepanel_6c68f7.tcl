#!/usr/bin/env tclsh
# sidepanel.html — portiert nach tcl
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/sidepanel.html
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/sidepanel.html
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/sidepanel.html
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/sidepanel.html
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

# Tcl/Tk port of sidepanel.html
# Generates the HTML structure programmatically

package require Tk

proc generateHTML {} {
    set html {}
    
    # Doctype and html tag
    lappend html {<!doctype html>}
    lappend html {<html lang="de">}
    
    # Head section
    lappend html {<head>}
    lappend html {  <meta charset="utf-8">}
    lappend html {  <meta name="viewport" content="width=device-width, initial-scale=1">}
    lappend html {  <title>TikTok LIVE Companion</title>}
    lappend html {  <link rel="stylesheet" href="sidepanel.css">}
    lappend html {  <link rel="stylesheet" href="icon-controls.css">}
    lappend html {</head>}
    
    # Body start
    lappend html {<body>}
    
    # Header
    lappend html {  <header>}
    lappend html {    <p id="page-title" class="muted">Kein TikTok-Tab ausgewählt</p>}
    lappend html {  </header>}
    
    # Main content
    lappend html {  <main>}
    
    # Chat section
    lappend html {    <section aria-labelledby="chat-heading">}
    lappend html {      <div class="section-title">}
    lappend html {        <h2 id="chat-heading">Chat</h2>}
    lappend html {        <div class="title-actions">}
    lappend html {          <span id="chat-led" class="status-led off" role="status" aria-label="Chat inaktiv" title="Chat inaktiv"></span>}
    lappend html {          <button id="chat-count" class="count count-button" type="button" aria-haspopup="dialog" title="Gesammelte Chatzeilen öffnen">0</button>}
    lappend html {          <button id="refresh-chat" class="secondary compact" title="Chatanzeige leeren">Reset</button>}
    lappend html {          <button id="toggle-speech" class="secondary compact" aria-pressed="false" aria-label="Vorlesen">On</button>}
    lappend html {          <span id="speech-led" class="status-led off" role="status" aria-label="Vorlesen inaktiv" title="Vorlesen inaktiv"></span>}
    lappend html {        </div>}
    lappend html {      </div>}
    lappend html {      <div id="chat-list" class="chat-list empty" role="log" aria-live="polite" aria-relevant="additions" aria-label="Die letzten fünf bereinigten Chatnachrichten">Noch keine Chatnachrichten erkannt.</div>}
    lappend html {      <p id="speech-status" role="status" class="inline-status">Vorlesen ist ausgeschaltet.</p>}
    lappend html {      <div class="control-label"><label for="speech-volume">Vorleselautstärke</label><output id="speech-volume-output" for="speech-volume">100%</output></div>}
    lappend html {      <input id="speech-volume" type="range" min="0" max="100" step="5" value="50">}
    lappend html {      <div class="button-row">}
    lappend html {        <button id="service-action" class="secondary">Sprachdienst</button>}
    lappend html {        <button id="sherpa-action" class="secondary">Sherpa</button>}
    lappend html {        <button id="open-speech-settings" class="secondary compact settings-button" type="button" aria-label="Erweiterte Einstellungen öffnen" aria-haspopup="dialog" title="Einstellungen"></button>}
    lappend html {      </div>}
    lappend html {      <p id="service-status" class="inline-status">Lokaler Sprachdienst noch nicht geprüft.</p>}
    lappend html {      <div id="service-setup" class="inline-status" hidden>}
    lappend html {        <button id="copy-service-setup" class="secondary compact">Installation abschließen!</button>}
    lappend html {      </div>}
    lappend html {    </section>}
    
    # Stats section
    lappend html {    <section aria-labelledby="stats-heading">}
    lappend html {      <div class="section-title">}
    lappend html {        <h2 id="stats-heading">LIVE-Information</h2>}
    lappend html {        <span id="stats-live" class="live-indicator">warte</span>}
    lappend html {      </div>}
    lappend html {      <div id="live-stats" class="status-grid stats-grid"></div>}
    lappend html {      <p id="stats-status" class="inline-status"></p>}
    lappend html {    </section>}
    
    # Page info section
    lappend html {    <section id="page-info-section" aria-labelledby="page-info-heading">}
    lappend html {      <div class="section-title">}
    lappend html {        <h2 id="page-info-heading">PROFIL-Information</h2>}
    lappend html {        <div class="title-actions">}
    lappend html {          <span id="page-info-source" class="live-indicator">Metadaten</span>}
    lappend html {          <button id="refresh-page-info" class="secondary compact" title="Refresh">Refresh</button>}
    lappend html {          <button id="force-page-info" class="secondary compact danger-outline">Force</button>}
    lappend html {        </div>}
    lappend html {      </div>}
    lappend html {      <div id="profile-info" class="profile-info" hidden></div>}
    lappend html {      <div id="summary-info" class="summary-info"></div>}
    lappend html {    </section>}
    
    # Hook section
    lappend html {    <section aria-labelledby="hook-heading">}
    lappend html {      <div class="section-title header-controls">}
    lappend html {        <h2 id="hook-heading">Connection</h2>}
    lappend html {        <div class="title-actions">}
    lappend html {          <button id="reset-tab" class="secondary compact danger-outline" title="Reset">Reset</button>}
    lappend html {          <input id="hook-autostart" type="checkbox" aria-label="Hook dauerhaft" title="Hook dauerhaft: Off">}
    lappend html {          <span class="status-led off" data-switch-status="hook-autostart" role="status"></span>}
    lappend html {        </div>}
    lappend html {      </div>}
    lappend html {      <div class="button-row">}
    lappend html {        <button id="toggle-hook" class="primary" aria-label="Connection" aria-pressed="false">On</button>}
    lappend html {        <button id="open-connection-settings" class="secondary compact settings-button" type="button" aria-label="Connection-Einstellungen öffnen" aria-haspopup="dialog"></button>}
    lappend html {        <button id="open-embed-live" class="secondary">Embed</button>}
    lappend html {        <button id="open-normal-live" class="secondary">Browser</button>}
    lappend html {        <button id="player-vlc-frame" class="secondary compact">Player</button>}
    lappend html {      </div>}
    lappend html {      <div class="connection-status"><span id="hook-led" class="status-led off" role="status" aria-label="Hook inaktiv" title="Hook inaktiv"></span><p id="hook-status" class="inline-status"></p></div>}
    lappend html {      <p id="embed-startup-status" class="inline-status" role="status" aria-live="polite" hidden></p>}
    lappend html {      <button id="cancel-embed-startup" class="secondary" hidden>Embed-Start abbrechen</button>}
    lappend html {      <p id="hook-reconnect-status" class="inline-status" role="status">Hook-Reconnect: aus</p>}
    lappend html {      <p id="player-recovery-status" class="inline-status" role="status">Player-Recovery: aus</p>}
    lappend html {    </section>}
    
    # Player section
    lappend html {    <section aria-labelledby="player-heading">}
    lappend html {      <div class="section-title header-controls">}
    lappend html {        <h2 id="player-heading">Player</h2>}
    lappend html {        <div class="title-actions">}
    lappend html {          <button id="player-replay" class="secondary compact" title="Neu laden">Neu laden</button>}
    lappend html {          <input id="limiter-enabled" type="checkbox" aria-label="Pegelschutz" title="Pegelschutz: Off">}
    lappend html {          <span class="status-led off" data-switch-status="limiter-enabled" role="status"></span>}
    lappend html {        </div>}
    lappend html {      </div>}
    lappend html {      <div class="player-controls" role="group" aria-label="TikTok-Player steuern">}
    lappend html {        <button id="player-play" class="secondary compact">Play</button>}
    lappend html {        <button id="player-mute" class="secondary compact">Mute</button>}
    lappend html {        <button id="player-pip" class="secondary compact">Bild-in-Bild</button>}
    lappend html {        <button id="player-fullscreen" class="secondary compact">Vollbild</button>}
    lappend html {        <button id="player-report" class="secondary compact danger-outline">Meldung</button>}
    lappend html {      </div>}
    lappend html {      <div class="audio-controls">}
    lappend html {        <div class="control-label"><label for="player-volume">Lautstärke</label><output id="player-volume-output" for="player-volume">–</output></div>}
    lappend html {        <input id="player-volume" type="range" min="0" max="100" step="1" value="100">}
    lappend html {        <div class="audio-meter-row"><span>Spitzenpegel</span><strong id="player-peak">–</strong></div>}
    lappend html {        <div class="control-label"><label for="limiter-strength">Schutzstärke</label><output id="limiter-strength-output" for="limiter-strength">30</output></div>}
    lappend html {        <input id="limiter-strength" type="range" min="0" max="100" step="1" value="30">}
    lappend html {      </div>}
    lappend html {      <p id="multi-guest-status" class="inline-status">Verbundene Streams: noch nicht erkannt.</p>}
    lappend html {      <p id="player-status" role="status" class="inline-status">Warte auf den TikTok-Player.</p>}
    lappend html {      <span id="player-time" class="player-time" hidden>–</span>}
    lappend html {    </section>}
    
    # Top chatters section
    lappend html {    <section aria-labelledby="top-chatters-heading">}
    lappend html {      <div class="section-title">}
    lappend html {        <h2 id="top-chatters-heading">Top-Chatter</h2>}
    lappend html {        <button id="open-audience" class="secondary compact">Zuschauer*innen</button>}
    lappend html {      </div>}
    lappend html {      <p id="team-tag-status" class="inline-status">Teamkürzel: noch nicht erkannt.</p>}
    lappend html {      <div id="top-chatters" class="top-chatters empty">Noch keine Personen im Chat beobachtet.</div>}
    lappend html {      <div id="top-chatters-actions" class="top-chatters-actions" hidden>}
    lappend html {        <button id="top-chatters-reset" class="top-chatter-link" type="button" hidden>Reset</button>}
    lappend html {        <button id="top-chatters-more" class="top-chatter-link" type="button">mehr…</button>}
    lappend html {      </div>}
    lappend html {    </section>}
    
    # Recommendations section
    lappend html {    <section id="recommendations-section" aria-labelledby="recommendations-heading">}
    lappend html {      <div class="section-title">}
    lappend html {        <h2 id="recommendations-heading">LIVE-Empfehlungen</h2>}
    lappend html {        <span id="recommendation-status" class="live-indicator">bereit</span>}
    lappend html {      </div>}
    lappend html {      <div class="recommendation-controls">}
    lappend html {        <label><span>Anzahl</span><input id="recommendation-limit" type="number" min="1" max="300" step="1" value="20" inputmode="numeric"></label>}
    lappend html {        <label><span>Sortierung</span><select id="recommendation-sort"><option value="tiktok">TikTok-Reihenfolge</option><option value="viewers">Zuschauer*innen</option></select></label>}
    lappend html {      </div>}
    lappend html {      <div class="button-row">}
    lappend html {        <button id="scan-recommendations" class="primary">Empfehlungen scannen</button>}
    lappend html {        <button id="cancel-recommendations" class="secondary" hidden>Abbrechen</button>}
    lappend html {      </div>}
    lappend html {      <p id="recommendation-progress" class="inline-status" aria-live="polite">Noch kein Scan gestartet.</p>}
    lappend html {      <div id="recommendation-list" class="recommendation-list empty">Noch keine Empfehlungen erfasst.</div>}
    lappend html {      <div id="recommendation-actions" class="top-chatters-actions" hidden>}
    lappend html {        <button id="recommendation-more" class="top-chatter-link" type="button">mehr…</button>}
    lappend html {      </div>}
    lappend html {    </section>}
    
    # Caption section
    lappend html {    <section aria-labelledby="caption-heading">}
    lappend html {      <div class="section-title">}
    lappend html {        <h2 id="caption-heading">Titel</h2>}
    lappend html {        <button id="scan" class="secondary">Status</button>}
    lappend html {      </div>}
    lappend html {      <div id="caption-status" class="status-grid"></div>}
    lappend html {      <button id="enable-captions" class="primary">Untertitel</button>}
    lappend html {      <p id="caption-action-status" role="status" class="inline-status action-status"></p>}
    lappend html {    </section>}
    
    # Song section
    lappend html {    <section aria-labelledby="song-heading">}
    lappend html {      <div class="section-title header-controls">}
    lappend html {        <h2 id="song-heading">Songs</h2>}
    lappend html {        <div class="title-actions">}
    lappend html {          <input id="song-enabled" type="checkbox" aria-label="Songerkennung" title="Songerkennung: Off">}
    lappend html {          <span id="song-led" class="status-led off" data-switch-status="song-enabled" role="status" aria-label="Songerkennung inaktiv"></span>}
    lappend html {        </div>}
    lappend html {      </div>}
    lappend html {      <button id="recognize-song" class="primary" disabled>Jetzt erkennen</button>}
    lappend html {      <p id="song-status" class="inline-status"></p>}
    lappend html {      <div id="song-result" class="song-result" hidden></div>}
    lappend html {    </section>}
    
    # Links section
    lappend html {    <section aria-labelledby="links-heading">}
    lappend html {      <div class="section-title">}
    lappend html {        <h2 id="links-heading">HAR-Logs</h2>}
    lappend html {        <span id="media-count" class="count">0</span>}
    lappend html {      </div>}
    lappend html {      <div id="media-list" class="list empty">Noch keine FLV-/HLS-Links erkannt.</div>}
    lappend html {    </section>}
    
    # Log section
    lappend html {    <section aria-labelledby="log-heading">}
    lappend html {      <div class="section-title header-controls">}
    lappend html {        <h2 id="log-heading">LIVE-Logs</h2>}
    lappend html {        <div class="title-actions">}
    lappend html {          <span class="status-led off" data-counter-status="caption-count" role="status"></span>}
    lappend html {          <span id="caption-count" class="count">0</span>}
    lappend html {          <button id="clear" class="ghost compact" title="Reset">Reset</button>}
    lappend html {          <input id="live-logs-enabled" type="checkbox" aria-label="LIVE-Logs" title="LIVE-Logs: Off">}
    lappend html {          <span class="status-led off" data-switch-status="live-logs-enabled" role="status" aria-label="LIVE-Logs: deaktiviert"></span>}
    lappend html {        </div>}
    lappend html {      </div>}
    lappend html {      <div class="button-row">}
    lappend html {        <button id="export-log" class="secondary">JSON-L-Export</button>}
    lappend html {        <button id="export-caption-raw" class="secondary">RAW-JSON-Export</button>}
    lappend html {      </div>}
    lappend html {      <div id="caption-list" class="list empty">Noch keine CaptionMessages empfangen.</div>}
    lappend html {    </section>}
    
    # Debug section
    lappend html {    <section aria-labelledby="debug-heading">}
    lappend html {      <div class="section-title header-controls">}
    lappend html {        <h2 id="debug-heading">Debugmodus</h2>}
    lappend html {        <div class="title-actions">}
    lappend html {          <span class="status-led off" data-counter-status="debug-count" role="status"></span>}
    lappend html {          <span id="debug-count" class="count">0</span>}
    lappend html {          <button id="clear-debug" class="ghost compact" title="Reset">Reset</button>}
    lappend html {          <input id="debug-enabled" type="checkbox" aria-label="Diagnoseereignisse für diesen Tab protokollieren" title="Diagnoseereignisse für diesen Tab protokollieren: Off">}
    lappend html {          <span class="status-led off" data-switch-status="debug-enabled" role="status"></span>}
    lappend html {        </div>}
    lappend html {      </div>}
    lappend html {      <div class="button-row">}
    lappend html {        <button id="export-debug" class="secondary">Debug exportieren</button>}
    lappend html {      </div>}
    lappend html {      <p class="muted small"></p>}
    lappend html {    </section>}
    
    # Audience modal
    lappend html {    <div id="audience-modal" class="modal-backdrop" hidden>}
    lappend html {      <section class="modal" role="dialog" aria-modal="true" aria-labelledby="audience-heading">}
    lappend html {        <div class="section-title">}
    lappend html {          <h2 id="audience-heading">Im Chat beobachtete Personen</h2>}
    lappend html {          <button id="close-audience" class="secondary compact" aria-label="Übersicht schließen">Schließen</button>}
    lappend html {        </div>}
    lappend html {        <p id="audience-limit" class="inline-status"></p>}
    lappend html {        <div id="audience-list" class="audience-list"></div>}
    lappend html {      </section>}
    lappend html {    </div>}
    
    # Speech settings modal
    lappend html {    <div id="speech-settings-modal" class="modal-backdrop" hidden>}
    lappend html {      <section class="modal" role="dialog" aria-modal="true" aria-labelledby="speech-settings-heading">}
    lappend html {        <div class="section-title">}
    lappend html {          <h2 id="speech-settings-heading">Erweiterte Einstellungen</h2>}
    lappend html {          <button id="close-speech-settings" class="secondary compact" aria-label="Einstellungen schließen">Schließen</button>}
    lappend html {        </div>}
    lappend html {        <div class="settings-grid speech-integration-settings">}
    lappend html {<label class="icon-style-setting"><span>Icon-Stil</span><select id="icon-style"><option value="plastisch">3D / Plastisch</option><option value="glass">Glass / Realistisch</option><option value="linear">Minimal / Linear</option></select></label>}
    lappend html {          <label><span>Sprache</span><select id="speech-language"><option value="auto">Auto</option><option value="de-DE">Deutsch</option><option value="en-US">Englisch</option><option value="ru-RU">Russisch</option><option value="uk-UA">Ukrainisch</option><option value="bg-BG">Bulgarisch</option><option value="sr-RS">Serbisch</option><option value="kk-KZ">Kasachisch</option><option value="zh-CN">Chinesisch</option><option value="ja-JP">Japanisch</option><option value="ko-KR">Koreanisch</option><option value="ar-JO">Arabisch</option><option value="fa-IR">Persisch</option><option value="ur-PK">Urdu</option><option value="hi-IN">Hindi</option><option value="ne-NP">Nepali</option><option value="ml-IN">Malayalam</option></select></label>}
    lappend html {          <label><span>Stimme</span><select id="speech-voice"><option value="">Standard</option></select></label>}
    lappend html {          <label id="audd-token-setting"><span id="audd-token-label">AudD API-Token (optional - <a href="https://audd.io/" target="_blank" rel="noopener noreferrer">https://AudD.io</a> Trial/Paid)</span><input id="audd-token" type="password" autocomplete="off" spellcheck="false"></label>}
    lappend html {          <label id="pairing-code-setting"><span>Pairing-Code</span><input id="pairing-code" type="password" autocomplete="off" spellcheck="false"></label>}
    lappend html {          <label><span>Universal API-Key</span><input id="universal-caption-api-key" type="password" autocomplete="off" spellcheck="false"></label>}
    lappend html {        </div>}
    lappend html {        <label class="option-row"><input id="speak-names" type="checkbox" checked> Chatnamen sprechen</label>}
    lappend html {        <label class="option-row"><input id="shorten-names" type="checkbox"> Chatnamen kürzen</label>}
    lappend html {        <label class="option-row auto-chat-refresh"><input id="auto-chat-refresh" type="checkbox"> Auto-Chat Refresh <input id="auto-chat-refresh-minutes" type="number" min="1" max="60" step="1" value="5" inputmode="numeric" aria-label="Auto-Chat-Refresh in Minuten"><span>min.</span></label>}
    lappend html {        <label class="option-row"><input id="game-mode" type="checkbox"> Game-Mode (Spam-, Emoji, usw. Chatfilter)</label>}
    lappend html {        <div class="option-row external-speech-trigger-row"><label><input id="filter-external-speech-triggers" type="checkbox"> Trigger filtern (ext. Sprachdienste)</label><input id="external-speech-trigger-characters" type="text" value="." maxlength="10" aria-label="Triggerzeichen, maximal fünf Sonderzeichen" autocomplete="off" spellcheck="false"></div>}
    lappend html {        <label class="option-row"><input id="keep-speech-active" type="checkbox" aria-label="Vorlesen dauerhaft" title="Vorlesen dauerhaft: Off"> Vorlesen dauerhaft</label>}
    lappend html {      </section>}
    lappend html {    </div>}
    
    # Chat history modal
    lappend html {    <div id="chat-history-modal" class="modal-backdrop" hidden>}
    lappend html {      <section class="modal" role="dialog" aria-modal="true" aria-labelledby="chat-history-heading">}
    lappend html {        <div class="section-title">}
    lappend html {          <h2 id="chat-history-heading">Gesammelte Chatnachrichten</h2>}
    lappend html {          <button id="close-chat-history" class="secondary compact" aria-label="Chatzeilen schließen">Schließen</button>}
    lappend html {        </div>}
    lappend html {        <p id="chat-history-limit" class="inline-status"></p>}
    lappend html {        <div id="chat-history-list" class="chat-history-list"></div>}
    lappend html {      </section>}
    lappend html {    </div>}
    
    # Recommendation modal
    lappend html {    <div id="recommendation-modal" class="modal-backdrop" hidden>}
    lappend html {      <section class="modal" role="dialog" aria-modal="true" aria-labelledby="recommendation-modal-heading">}
    lappend html {        <div class="section-title">}
    lappend html {          <h2 id="recommendation-modal-heading">Gescannte LIVE-Empfehlungen</h2>}
    lappend html {          <button id="close-recommendations" class="secondary compact" aria-label="Empfehlungen schließen">Schließen</button>}
    lappend html {        </div>}
    lappend html {        <div id="recommendation-modal-list" class="recommendation-list"></div>}
    lappend html {      </section>}
    lappend html {    </div>}
    
    # Notice
    lappend html {    <p id="notice" role="alert" class="notice"></p>}
    lappend html {  </main>}
    
    # Connection settings modal
    lappend html {  <div id="connection-settings-modal" class="modal-backdrop" hidden>}
    lappend html {    <section class="modal" role="dialog" aria-modal="true" aria-labelledby="connection-settings-heading">}
    lappend html {      <div class="section-title"><h2 id="connection-settings-heading">Connection-Einstellungen</h2><button id="close-connection-settings" class="secondary compact">Schließen</button></div>}
    lappend html {      <label class="option-row quick-recover-setting"><input id="hook-reconnect" type="checkbox"> Hook-Reconnect <input id="hook-reconnect-seconds" type="number" min="1" max="59" step="1" value="3" inputmode="numeric" aria-label="Hook-Reconnect-Wartezeit in Sekunden"><span>Sek.</span></label>}
    lappend html {      <label class="option-row quick-recover-setting"><input id="quick-recover" type="checkbox"> Player-Recovery <input id="quick-recover-seconds" type="number" min="1" max="59" step="1" value="3" inputmode="numeric" aria-label="Player-Recovery-Bestätigungszeit in Sekunden"><span>Sek.</span></label>}
    lappend html {    </section>}
    lappend html {  </div>}
    
    # Scripts
    lappend html {  <script src="content-core.js"></script>}
    lappend html {  <script src="sidepanel.js"></script>}
    lappend html {  <script src="icon-controls.js"></script>}
    
    # Body end
    lappend html {</body>}
    lappend html {</html>}
    
    return [join $html "\n"]
}

# Main execution
if {$argc != 1} {
    puts stderr "Usage: $argv0 <output-file>"
    exit 1
}

set outputFile [lindex $argv 0]
set htmlContent [generateHTML]

if {[catch {set fileId [open $outputFile w]} errorMsg]} {
    puts stderr "Error opening file '$outputFile': $errorMsg"
    exit 1
}

if {[catch {puts $fileId $htmlContent; close $fileId} errorMsg]} {
    puts stderr "Error writing to file '$outputFile': $errorMsg"
    exit 1
}

puts "HTML file generated successfully: $outputFile"
