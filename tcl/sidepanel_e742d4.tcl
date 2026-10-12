#!/usr/bin/env tclsh
# sidepanel.html — portiert nach tcl
# Quelle: html, Projects@codex/0pe-177-peak-protection:plugin-source/browser-extension/sidepanel.html
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

# Generate sidepanel.html from Tcl script
# Usage: tclsh generate_sidepanel.tcl > sidepanel.html

proc generate_html {} {
    puts {<!doctype html>}
    puts {<html lang="de">}
    puts {<head>}
    puts {  <meta charset="utf-8">}
    puts {  <meta name="viewport" content="width=device-width, initial-scale=1">}
    puts {  <title>TikTok LIVE Companion</title>}
    puts {  <link rel="stylesheet" href="sidepanel.css">}
    puts {</head>}
    puts {<body>}
    puts {  <header>}
    puts {    <p id="page-title" class="muted">Kein TikTok-Tab ausgewählt</p>}
    puts {  </header>}
    puts {}
    puts {  <main>}
    puts {    <section aria-labelledby="chat-heading">}
    puts {      <div class="section-title">}
    puts {        <h2 id="chat-heading">Chat</h2>}
    puts {        <div class="title-actions">}
    puts {          <span id="chat-led" class="status-led off" role="status" aria-label="Chat inaktiv" title="Chat inaktiv"></span>}
    puts {          <button id="chat-count" class="count count-button" type="button" aria-haspopup="dialog" title="Gesammelte Chatzeilen öffnen">0</button>}
    puts {          <button id="refresh-chat" class="secondary compact" title="Chatanzeige leeren">Refresh</button>}
    puts {          <button id="toggle-speech" class="secondary compact" aria-pressed="false" aria-label="Vorlesen">On</button>}
    puts {          <span id="speech-led" class="status-led off" role="status" aria-label="Vorlesen inaktiv" title="Vorlesen inaktiv"></span>}
    puts {        </div>}
    puts {      </div>}
    puts {      <div id="chat-list" class="chat-list empty" role="log" aria-live="polite" aria-relevant="additions" aria-label="Die letzten fünf bereinigten Chatnachrichten">Noch keine Chatnachrichten erkannt.</div>}
    puts {      <p id="speech-status" role="status" class="inline-status">Vorlesen ist ausgeschaltet.</p>}
    puts {      <div class="control-label"><label for="speech-volume">Vorleselautstärke</label><output id="speech-volume-output" for="speech-volume">100%</output></div>}
    puts {      <input id="speech-volume" type="range" min="0" max="100" step="5" value="50">}
    puts {      <div class="button-row">}
    puts {        <button id="service-action" class="secondary">Sprachdienst</button>}
    puts {        <button id="sherpa-action" class="secondary">Sherpa</button>}
    puts {        <button id="open-speech-settings" class="secondary compact settings-button" type="button" aria-label="Sprach- und Chat Einstellungen öffnen" aria-haspopup="dialog" title="Einstellungen">⚙</button>}
    puts {      </div>}
    puts {      <p id="service-status" class="inline-status">Lokaler Sprachdienst noch nicht geprüft.</p>}
    puts {      <div id="service-setup" class="inline-status" hidden>}
    puts {        <button id="copy-service-setup" class="secondary compact">Installation abschließen!</button>}
    puts {      </div>}
    puts {      <label class="option-row"><input id="keep-speech-active" type="checkbox"> Permanent aktiv</label>}
    puts {    </section>}
    puts {}
    puts {    <section aria-labelledby="top-chatters-heading">}
    puts {      <div class="section-title">}
    puts {        <h2 id="top-chatters-heading">Top-Chatter</h2>}
    puts {        <button id="open-audience" class="secondary compact">Zuschauer*innen</button>}
    puts {      </div>}
    puts {      <p id="team-tag-status" class="inline-status">Teamkürzel: noch nicht erkannt.</p>}
    puts {      <div id="top-chatters" class="top-chatters empty">Noch keine Personen im Chat beobachtet.</div>}
    puts {      <div id="top-chatters-actions" class="top-chatters-actions" hidden>}
    puts {        <button id="top-chatters-reset" class="top-chatter-link" type="button" hidden>Reset</button>}
    puts {        <button id="top-chatters-more" class="top-chatter-link" type="button">mehr…</button>}
    puts {      </div>}
    puts {    </section>}
    puts {}
    puts {    <section id="page-info-section" aria-labelledby="page-info-heading">}
    puts {      <div class="section-title">}
    puts {        <h2 id="page-info-heading">PROFIL-Information</h2>}
    puts {        <div class="title-actions">}
    puts {          <span id="page-info-source" class="live-indicator">Metadaten</span>}
    puts {          <button id="refresh-page-info" class="secondary compact">Refresh</button>}
    puts {          <button id="force-page-info" class="secondary compact danger-outline">Force</button>}
    puts {        </div>}
    puts {      </div>}
    puts {      <div id="profile-info" class="profile-info" hidden></div>}
    puts {      <div id="summary-info" class="summary-info"></div>}
    puts {    </section>}
    puts {}
    puts {    <section aria-labelledby="stats-heading">}
    puts {      <div class="section-title">}
    puts {        <h2 id="stats-heading">LIVE-Information</h2>}
    puts {        <span id="stats-live" class="live-indicator">warte</span>}
    puts {      </div>}
    puts {      <div id="live-stats" class="status-grid stats-grid"></div>}
    puts {      <p id="stats-status" class="inline-status"></p>}
    puts {    </section>}
    puts {}
    puts {    <section aria-labelledby="hook-heading">}
    puts {      <div class="section-title">}
    puts {        <h2 id="hook-heading">Connection</h2>}
    puts {        <span id="hook-led" class="status-led off" role="status" aria-label="Hook inaktiv" title="Hook inaktiv"></span>}
    puts {      </div>}
    puts {      <div class="button-row">}
    puts {        <button id="toggle-hook" class="primary" aria-label="Connection" aria-pressed="false">On</button>}
    puts {        <button id="reset-tab" class="secondary danger-outline">Refresh</button>}
    puts {        <button id="open-embed-live" class="secondary">Embed</button>}
    puts {        <button id="open-normal-live" class="secondary">Browser</button>}
    puts {        <button id="player-vlc-frame" class="secondary compact">Player</button>}
    puts {        <button id="open-connection-settings" class="secondary compact settings-button" type="button" aria-label="Connection-Einstellungen öffnen" aria-haspopup="dialog">⚙</button>}
    puts {      </div>}
    puts {      <p id="hook-status" class="inline-status"></p>}
    puts {      <p id="embed-startup-status" class="inline-status" role="status" aria-live="polite" hidden></p>}
    puts {      <button id="cancel-embed-startup" class="secondary" hidden>Embed-Start abbrechen</button>}
    puts {      <label class="option-row"><input id="hook-autostart" type="checkbox"> Permanent Hook</label>}
    puts {      <p id="hook-reconnect-status" class="inline-status" role="status">Hook-Reconnect: aus</p>}
    puts {      <p id="player-recovery-status" class="inline-status" role="status">Player-Recovery: aus</p>}
    puts {    </section>}
    puts {}
    puts {    <section id="recommendations-section" aria-labelledby="recommendations-heading">}
    puts {      <div class="section-title">}
    puts {        <h2 id="recommendations-heading">LIVE-Empfehlungen</h2>}
    puts {        <span id="recommendation-status" class="live-indicator">bereit</span>}
    puts {      </div>}
    puts {      <div class="recommendation-controls">}
    puts {        <label><span>Anzahl</span><input id="recommendation-limit" type="number" min="1" max="50" step="1" value="20" inputmode="numeric"></label>}
    puts {        <label><span>Sortierung</span><select id="recommendation-sort"><option value="tiktok">TikTok-Reihenfolge</option><option value="viewers">Zuschauer*innen</option></select></label>}
    puts {      </div>}
    puts {      <div class="button-row">}
    puts {        <button id="scan-recommendations" class="primary">Empfehlungen scannen</button>}
    puts {        <button id="cancel-recommendations" class="secondary" hidden>Abbrechen</button>}
    puts {      </div>}
    puts {      <p id="recommendation-progress" class="inline-status" aria-live="polite">Noch kein Scan gestartet.</p>}
    puts {      <div id="recommendation-list" class="recommendation-list empty">Noch keine Empfehlungen erfasst.</div>}
    puts {      <div id="recommendation-actions" class="top-chatters-actions" hidden>}
    puts {        <button id="recommendation-more" class="top-chatter-link" type="button">mehr…</button>}
    puts {      </div>}
    puts {    </section>}
    puts {}
    puts {    <section aria-labelledby="caption-heading">}
    puts {      <div class="section-title">}
    puts {        <h2 id="caption-heading">Titel</h2>}
    puts {        <button id="scan" class="secondary">Seite prüfen</button>}
    puts {      </div>}
    puts {      <div id="caption-status" class="status-grid"></div>}
    puts {      <button id="enable-captions" class="primary">Untertitel aktivieren</button>}
    puts {      <p id="caption-action-status" role="status" class="inline-status action-status"></p>}
    puts {    </section>}
    puts {}
    puts {    <section aria-labelledby="player-heading">}
    puts {      <div class="section-title">}
    puts {        <h2 id="player-heading">Player</h2>}
    puts {        <span id="player-time" class="player-time">–</span>}
    puts {      </div>}
    puts {      <div class="player-controls" role="group" aria-label="TikTok-Player steuern">}
    puts {        <button id="player-play" class="secondary compact">Pause</button>}
    puts {        <button id="player-replay" class="secondary compact">Neu laden</button>}
    puts {        <button id="player-mute" class="secondary compact">Stumm</button>}
    puts {        <button id="player-pip" class="secondary compact">Bild-in-Bild</button>}
    puts {        <button id="player-fullscreen" class="secondary compact">Vollbild</button>}
    puts {        <button id="player-report" class="secondary compact danger-outline">Melden öffnen</button>}
    puts {      </div>}
    puts {      <div class="audio-controls">}
    puts {        <div class="control-label"><label for="player-volume">Lautstärke</label><output id="player-volume-output" for="player-volume">–</output></div>}
    puts {        <input id="player-volume" type="range" min="0" max="100" step="1" value="100">}
    puts {        <div class="audio-meter-row"><span>Spitzenpegel</span><strong id="player-peak">–</strong></div>}
    puts {        <label class="option-row"><input id="limiter-enabled" type="checkbox"> Pegelschutz aktivieren</label>}
    puts {        <div class="control-label"><label for="limiter-strength">Schutzstärke</label><output id="limiter-strength-output" for="limiter-strength">30</output></div>}
    puts {        <input id="limiter-strength" type="range" min="0" max="100" step="1" value="30">}
    puts {      </div>}
    puts {      <p id="multi-guest-status" class="inline-status">Verbundene Streams: noch nicht erkannt.</p>}
    puts {      <p id="player-status" role="status" class="inline-status">Warte auf den TikTok-Player.</p>}
    puts {    </section>}
    puts {}
    puts {    <section aria-labelledby="song-heading">}
    puts {      <div class="section-title">}
    puts {        <h2 id="song-heading">Songs</h2>}
    puts {        <span id="song-led" class="status-led off" role="status" aria-label="Songerkennung inaktiv"></span>}
    puts {      </div>}
    puts {      <label class="option-row"><input id="song-enabled" type="checkbox"> Songerkennung aktivieren</label>}
    puts {      <button id="recognize-song" class="primary" disabled>Jetzt erkennen</button>}
    puts {      <p id="song-status" class="inline-status"></p>}
    puts {      <div id="song-result" class="song-result" hidden></div>}
    puts {    </section>}
    puts {}
    puts {    <section aria-labelledby="links-heading">}
    puts {      <div class="section-title">}
    puts {        <h2 id="links-heading">HAR-Logs</h2>}
    puts {        <span id="media-count" class="count">0</span>}
    puts {      </div>}
    puts {      <div id="media-list" class="list empty">Noch keine FLV-/HLS-Links erkannt.</div>}
    puts {      <p class="hint">Extern gestarteter VLC liegt außerhalb des Companion-Pegelschutzes.</p>}
    puts {    </section>}
    puts {}
    puts {    <section aria-labelledby="log-heading">}
    puts {      <div class="section-title">}
    puts {        <h2 id="log-heading">LIVE-Logs</h2>}
    puts {        <span id="caption-count" class="count">0</span>}
    puts {      </div>}
    puts {      <div class="button-row">}
    puts {        <button id="export-log" class="secondary">JSON-L-Export</button>}
    puts {        <button id="export-caption-raw" class="secondary">RAW-JSON-Export</button>}
    puts {        <button id="clear" class="ghost">Anzeige leeren</button>}
    puts {      </div>}
    puts {      <div id="caption-list" class="list empty">Noch keine CaptionMessages empfangen.</div>}
    puts {    </section>}
    puts {}
    puts {    <section aria-labelledby="debug-heading">}
    puts {      <div class="section-title">}
    puts {        <h2 id="debug-heading">Debugmodus</h2>}
    puts {        <span id="debug-count" class="count">0</span>}
    puts {      </div>}
    puts {      <label class="option-row"><input id="debug-enabled" type="checkbox"> Diagnoseereignisse für diesen Tab protokollieren</label>}
    puts {      <div class="button-row">}
    puts {        <button id="export-debug" class="secondary">Debug exportieren</button>}
    puts {        <button id="clear-debug" class="ghost">Debug leeren</button>}
    puts {      </div>}
    puts {      <p class="muted small"></p>}
    puts {    </section>}
    puts {}
    puts {    <div id="audience-modal" class="modal-backdrop" hidden>}
    puts {      <section class="modal" role="dialog" aria-modal="true" aria-labelledby="audience-heading">}
    puts {        <div class="section-title">}
    puts {          <h2 id="audience-heading">Im Chat beobachtete Personen</h2>}
    puts {          <button id="close-audience" class="secondary compact" aria-label="Übersicht schließen">Schließen</button>}
    puts {        </div>}
    puts {        <p id="audience-limit" class="inline-status"></p>}
    puts {        <div id="audience-list" class="audience-list"></div>}
    puts {      </section>}
    puts {    </div>}
    puts {}
    puts {    <div id="speech-settings-modal" class="modal-backdrop" hidden>}
    puts {      <section class="modal" role="dialog" aria-modal="true" aria-labelledby="speech-settings-heading">}
    puts {        <div class="section-title">}
    puts {          <h2 id="speech-settings-heading">Sprach- und Chat Einstellungen</h2>}
    puts {          <button id="close-speech-settings" class="secondary compact" aria-label="Einstellungen schließen">Schließen</button>}
    puts {        </div>}
    puts {        <div class="settings-grid speech-integration-settings">}
    puts {          <label><span>Sprache</span><select id="speech-language"><option value="auto">Auto</option><option value="de-DE">Deutsch</option><option value="en-US">Englisch</option><option value="ru-RU">Russisch</option><option value="uk-UA">Ukrainisch</option><option value="bg-BG">Bulgarisch</option><option value="sr-RS">Serbisch</option><option value="kk-KZ">Kasachisch</option><option value="zh-CN">Chinesisch</option><option value="ja-JP">Japanisch</option><option value="ko-KR">Koreanisch</option><option value="ar-JO">Arabisch</option><option value="fa-IR">Persisch</option><option value="ur-PK">Urdu</option><option value="hi-IN">Hindi</option><option value="ne-NP">Nepali</option><option value="ml-IN">Malayalam</option></select></label>}
    puts {          <label><span>Stimme</span><select id="speech-voice"><option value="">Standard</option></select></label>}
    puts {          <label id="audd-token-setting"><span id="audd-token-label">AudD API-Token (optional - <a href="https://audd.io/" target="_blank" rel="noopener noreferrer">https://AudD.io</a> Trial/Paid)</span><input id="audd-token" type="password" autocomplete="off" spellcheck="false"></label>}
    puts {          <label id="pairing-code-setting"><span>Pairing-Code</span><input id="pairing-code" type="password" autocomplete="off" spellcheck="false"></label>}
    puts {          <label><span>Universal API-Key für Untertitel</span><input id="universal-caption-api-key" type="password" autocomplete="off" spellcheck="false"></label>}
    puts {        </div>}
    puts {        <label class="option-row"><input id="speak-names" type="checkbox" checked> Chatnamen sprechen</label>}
    puts {        <label class="option-row"><input id="shorten-names" type="checkbox"> Chatnamen kürzen</label>}
    puts {        <label class="option-row auto-chat-refresh"><input id="auto-chat-refresh" type="checkbox"> Auto-Chat Refresh <input id="auto-chat-refresh-minutes" type="number" min="1" max="60" step="1" value="5" inputmode="numeric" aria-label="Auto-Chat-Refresh in Minuten"><span>min.</span></label>}
    puts {        <label class="option-row"><input id="game-mode" type="checkbox"> Game-Mode</label>}
    puts {        <label class="option-row"><input id="filter-external-speech-triggers" type="checkbox"> Trigger externer Sprachdienste filtern</label>}
    puts {      </section>}
    puts {    </div>}
    puts {}
    puts {    <div id="chat-history-modal" class="modal-backdrop" hidden>}
    puts {      <section class="modal" role="dialog" aria-modal="true" aria-labelledby="chat-history-heading">}
    puts {        <div class="section-title">}
    puts {          <h2 id="chat-history-heading">Gesammelte Chatnachrichten</h2>}
    puts {          <button id="close-chat-history" class="secondary compact" aria-label="Chatzeilen schließen">Schließen</button>}
    puts {        </div>}
    puts {        <p id="chat-history-limit" class="inline-status"></p>}
    puts {        <div id="chat-history-list" class="chat-history-list"></div>}
    puts {      </section>}
    puts {    </div>}
    puts {}
    puts {    <div id="recommendation-modal" class="modal-backdrop" hidden>}
    puts {      <section class="modal" role="dialog" aria-modal="true" aria-labelledby="recommendation-modal-heading">}
    puts {        <div class="section-title">}
    puts {          <h2 id="recommendation-modal-heading">Gescannte LIVE-Empfehlungen</h2>}
    puts {          <button id="close-recommendations" class="secondary compact" aria-label="Empfehlungen schließen">Schließen</button>}
    puts {        </div>}
    puts {        <div id="recommendation-modal-list" class="recommendation-list"></div>}
    puts {      </section>}
    puts {    </div>}
    puts {}
    puts {    <p id="notice" role="alert" class="notice"></p>}
    puts {  </main>}
    puts {  <div id="connection-settings-modal" class="modal-backdrop" hidden>}
    puts {    <section class="modal" role="dialog" aria-modal="true" aria-labelledby="connection-settings-heading">}
    puts {      <div class="section-title"><h2 id="connection-settings-heading">Connection-Einstellungen</h2><button id="close-connection-settings" class="secondary compact">Schließen</button></div>}
    puts {      <label class="option-row quick-recover-setting"><input id="hook-reconnect" type="checkbox"> Hook-Reconnect <input id="hook-reconnect-seconds" type="number" min="1" max="59" step="1" value="3" inputmode="numeric" aria-label="Hook-Reconnect-Wartezeit in Sekunden"><span>Sek.</span></label>}
    puts {      <label class="option-row quick-recover-setting"><input id="quick-recover" type="checkbox"> Player-Recovery <input id="quick-recover-seconds" type="number" min="1" max="59" step="1" value="3" inputmode="numeric" aria-label="Player-Recovery-Bestätigungszeit in Sekunden"><span>Sek.</span></label>}
    puts {    </section>}
    puts {  </div>}
    puts {}
    puts {}
    puts {  <script src="content-core.js"></script>}
    puts {  <script src="sidepanel.js"></script>}
    puts {</body>}
    puts {</html>}
}

# Main execution
if {[info exists argv] && [llength $argv] == 1} {
    set filename [lindex $argv 0]
    set fh [open $filename w]
    puts $fh [generate_html]
    close $fh
} else {
    generate_html
}
