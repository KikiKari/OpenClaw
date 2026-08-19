#!/usr/bin/perl
# sidepanel.html — portiert nach perl5
# Quelle: html, Projects@TikTok-Live-Companion:release/0.6.0/tiktok-live-companion-extension-0.6.0/sidepanel.html
# auch in: Projects@TikTok-Live-Companion:release/0.7.0/tiktok-live-companion-extension-0.7.0/sidepanel.html
# auch in: Projects@TikTok-Live-Companion-Android:release/0.6.0/tiktok-live-companion-extension-0.6.0/sidepanel.html
# auch in: Projects@TikTok-Live-Companion-Android:release/0.7.0/tiktok-live-companion-extension-0.7.0/sidepanel.html
# auch in: 2 weiteren Fundstellen
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use HTML::Entities;

# Main function to generate the HTML document
sub generate_html {
    my $html = <<'HTML_HEADER';
<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>TikTok LIVE Companion</title>
  <link rel="stylesheet" href="sidepanel.css">
</head>
<body>
  <header>
    <p id="page-title" class="muted">Kein TikTok-Tab ausgewählt</p>
  </header>

  <main>
HTML_HEADER

    # Chat section
    $html .= generate_chat_section();

    # Top chatters section
    $html .= generate_top_chatters_section();

    # Song recognition section
    $html .= generate_song_recognition_section();

    # Captions section
    $html .= generate_captions_section();

    # WebSocket hook section
    $html .= generate_websocket_hook_section();

    # Live stats section
    $html .= generate_live_stats_section();

    # Player control section
    $html .= generate_player_control_section();

    # Page info section
    $html .= generate_page_info_section();

    # Quality section
    $html .= generate_quality_section();

    # VLC links section
    $html .= generate_vlc_links_section();

    # Caption log section
    $html .= generate_caption_log_section();

    # Debug section
    $html .= generate_debug_section();

    # Audience modal
    $html .= generate_audience_modal();

    # Notice element
    $html .= '    <p id="notice" role="alert" class="notice"></p>' . "\n";

    # Closing tags and scripts
    $html .= <<'HTML_FOOTER';
  </main>

  <script src="content-core.js"></script>
  <script src="sidepanel.js"></script>
</body>
</html>
HTML_FOOTER

    return $html;
}

# Generate chat section
sub generate_chat_section {
    my $section = <<'CHAT_SECTION_START';
    <section aria-labelledby="chat-heading">
      <div class="section-title">
        <h2 id="chat-heading">Chatzeilen</h2>
        <div class="title-actions">
          <span id="chat-led" class="status-led off" role="status" aria-label="Chat inaktiv" title="Chat inaktiv"></span>
          <span id="chat-count" class="count">0</span>
          <button id="refresh-chat" class="secondary compact" title="Chatanzeige leeren">Refresh</button>
          <button id="toggle-speech" class="secondary compact" aria-pressed="false">Vorlesen an</button>
          <span id="speech-led" class="status-led off" role="status" aria-label="Vorlesen inaktiv" title="Vorlesen inaktiv"></span>
        </div>
      </div>
      <div id="chat-list" class="chat-list empty" role="log" aria-live="polite" aria-relevant="additions" aria-label="Die letzten fünf bereinigten Chatnachrichten">Noch keine Chatnachrichten erkannt.</div>
      <p id="speech-status" role="status" class="inline-status">Vorlesen ist ausgeschaltet.</p>
      <div class="control-label"><label for="speech-volume">Vorleselautstärke</label><output id="speech-volume-output" for="speech-volume">100%</output></div>
      <input id="speech-volume" type="range" min="0" max="100" step="5" value="50">
      <div class="settings-grid speech-settings">
        <label><span>Sprache</span><select id="speech-language"><option value="auto">Auto</option><option value="de-DE">Deutsch</option><option value="en-US">Englisch</option></select></label>
        <label><span>Dienstadresse</span><input id="service-url" type="url" value="http://127.0.0.1:43117" spellcheck="false"></label>
        <label><span>Pairing-Code</span><input id="pairing-code" type="password" autocomplete="off"></label>
      </div>
      <p id="service-status" class="inline-status">Lokaler Sprachdienst noch nicht geprüft.</p>
      <label class="option-row"><input id="speak-names" type="checkbox" checked> Chatnamen vorlesen</label>
      <label class="option-row"><input id="shorten-names" type="checkbox"> Geeignete lange Namen kürzen</label>
      <label class="option-row"><input id="keep-speech-active" type="checkbox"> Vorlesen bei Tabwechsel oder Minimieren aktiv lassen</label>
    </section>
CHAT_SECTION_START

    return $section;
}

# Generate top chatters section
sub generate_top_chatters_section {
    my $section = <<'TOP_CHATTERS_SECTION';
    <section aria-labelledby="top-chatters-heading">
      <div class="section-title">
        <h2 id="top-chatters-heading">Top-Chatter</h2>
        <button id="open-audience" class="secondary compact">Zuschauer*innen</button>
      </div>
      <p id="team-tag-status" class="inline-status">Teamkürzel: noch nicht erkannt.</p>
      <div id="top-chatters" class="top-chatters empty">Noch keine Personen im Chat beobachtet.</div>
    </section>
TOP_CHATTERS_SECTION

    return $section;
}

# Generate song recognition section
sub generate_song_recognition_section {
    my $section = <<'SONG_RECOGNITION_SECTION';
    <section aria-labelledby="song-heading">
      <div class="section-title">
        <h2 id="song-heading">Songerkennung</h2>
        <span id="song-led" class="status-led off" role="status" aria-label="Songerkennung inaktiv"></span>
      </div>
      <label class="option-row"><input id="song-enabled" type="checkbox"> Songerkennung aktivieren</label>
      <button id="recognize-song" class="primary" disabled>Jetzt erkennen</button>
      <p id="song-status" class="inline-status">Es wird nichts aufgenommen oder übertragen.</p>
      <div id="song-result" class="song-result" hidden></div>
      <p class="muted small">Nach einem Klick werden etwa 12 Sekunden Tab-Audio über den lokalen Dienst an AudD übertragen. Anbietergebühren können anfallen.</p>
    </section>
SONG_RECOGNITION_SECTION

    return $section;
}

# Generate captions section
sub generate_captions_section {
    my $section = <<'CAPTIONS_SECTION';
    <section aria-labelledby="caption-heading">
      <div class="section-title">
        <h2 id="caption-heading">Untertitel</h2>
        <button id="scan" class="secondary">Seite prüfen</button>
      </div>
      <div id="caption-status" class="status-grid"></div>
      <button id="enable-captions" class="primary">Untertitel aktivieren</button>
      <p id="caption-action-status" role="status" class="inline-status action-status">Noch keine manuelle Prüfung ausgeführt.</p>
    </section>
CAPTIONS_SECTION

    return $section;
}

# Generate WebSocket hook section
sub generate_websocket_hook_section {
    my $section = <<'WEBSOCKET_HOOK_SECTION';
    <section aria-labelledby="hook-heading">
      <div class="section-title">
        <h2 id="hook-heading">WebSocket-Hook</h2>
        <span id="hook-led" class="status-led off" role="status" aria-label="Hook inaktiv" title="Hook inaktiv"></span>
      </div>
      <p class="muted small">Der Hook wird vor dem Player-Code gesetzt. Der aktuelle Tab wird danach neu geladen.</p>
      <div class="button-row">
        <button id="enable-hook" class="primary">Hook setzen</button>
        <button id="disable-hook" class="secondary">Hook deaktivieren</button>
        <button id="reset-tab" class="secondary danger-outline">Refresh</button>
      </div>
      <p id="hook-status" class="inline-status"></p>
      <label class="option-row"><input id="hook-autostart" type="checkbox"> Hook beim Öffnen von TikTok automatisch starten</label>
      <p class="muted small reset-note">Refresh leert nur die flüchtigen Daten dieses Tabs, aktiviert den Hook erneut und lädt TikTok ohne Seitencache. Cookies bleiben unverändert.</p>
    </section>
WEBSOCKET_HOOK_SECTION

    return $section;
}

# Generate live stats section
sub generate_live_stats_section {
    my $section = <<'LIVE_STATS_SECTION';
    <section aria-labelledby="stats-heading">
      <div class="section-title">
        <h2 id="stats-heading">LIVE-Informationen</h2>
        <span id="stats-live" class="live-indicator">warte</span>
      </div>
      <div id="live-stats" class="status-grid stats-grid"></div>
      <p id="stats-status" class="inline-status">Der WebSocket-Hook liefert die Werte nach dem Neuladen des Streams.</p>
    </section>
LIVE_STATS_SECTION

    return $section;
}

# Generate player control section
sub generate_player_control_section {
    my $section = <<'PLAYER_CONTROL_SECTION';
    <section aria-labelledby="player-heading">
      <div class="section-title">
        <h2 id="player-heading">Playersteuerung</h2>
        <span id="player-time" class="player-time">–</span>
      </div>
      <div class="player-controls" role="group" aria-label="TikTok-Player steuern">
        <button id="player-play" class="secondary compact">Pause</button>
        <button id="player-replay" class="secondary compact">Neu laden</button>
        <button id="player-mute" class="secondary compact">Stumm</button>
        <button id="player-pip" class="secondary compact">Bild-in-Bild</button>
        <button id="player-fullscreen" class="secondary compact">Vollbild</button>
        <button id="player-report" class="secondary compact danger-outline">Melden öffnen</button>
      </div>
      <div class="audio-controls">
        <div class="control-label"><label for="player-volume">Lautstärke</label><output id="player-volume-output" for="player-volume">–</output></div>
        <input id="player-volume" type="range" min="0" max="100" step="1" value="100">
        <div class="audio-meter-row"><span>Digitaler Spitzenpegel</span><strong id="player-peak">– dBFS</strong></div>
        <label class="option-row"><input id="limiter-enabled" type="checkbox"> Digitalen Pegelschutz aktivieren</label>
        <div class="control-label"><label for="limiter-threshold">Grenzwert</label><output id="limiter-threshold-output" for="limiter-threshold">−6 dBFS</output></div>
        <input id="limiter-threshold" type="range" min="-30" max="-1" step="1" value="-6">
        <p class="muted small audio-note">dBFS ist ein digitaler Signalpegel, kein am Ohr messbarer dB-SPL-Wert. Der Schutz komprimiert Spitzen oberhalb des Grenzwerts lokal im Browser.</p>
      </div>
      <p id="multi-guest-status" class="inline-status">Verbundene Streams: noch nicht erkannt.</p>
      <p id="player-status" role="status" class="inline-status">Warte auf den TikTok-Player.</p>
    </section>
PLAYER_CONTROL_SECTION

    return $section;
}

# Generate page info section
sub generate_page_info_section {
    my $section = <<'PAGE_INFO_SECTION';
    <section id="page-info-section" aria-labelledby="page-info-heading">
      <div class="section-title">
        <h2 id="page-info-heading">Seiteninformationen</h2>
        <div class="title-actions">
          <span id="page-info-source" class="live-indicator">Metadaten</span>
          <button id="refresh-page-info" class="secondary compact">Refresh</button>
          <button id="force-page-info" class="secondary compact danger-outline">Force</button>
        </div>
      </div>
      <div id="profile-info" class="profile-info" hidden></div>
      <div id="summary-info" class="summary-info"></div>
    </section>
PAGE_INFO_SECTION

    return $section;
}

# Generate quality section
sub generate_quality_section {
    my $section = <<'QUALITY_SECTION';
    <section aria-labelledby="quality-heading">
      <div class="section-title">
        <h2 id="quality-heading">Verfügbare Bildqualitäten</h2>
        <span id="quality-count" class="count">0</span>
      </div>
      <div id="quality-list" class="list empty">Noch keine Qualitätsstufen aus den Stream-Metadaten erkannt.</div>
      <p id="quality-action-status" role="status" class="inline-status"></p>
    </section>
QUALITY_SECTION

    return $section;
}

# Generate VLC links section
sub generate_vlc_links_section {
    my $section = <<'VLC_LINKS_SECTION';
    <section aria-labelledby="links-heading">
      <div class="section-title">
        <h2 id="links-heading">VLC-Links</h2>
        <span id="media-count" class="count">0</span>
      </div>
      <div id="media-list" class="list empty">Noch keine FLV-/HLS-Links erkannt.</div>
    </section>
VLC_LINKS_SECTION

    return $section;
}

# Generate caption log section
sub generate_caption_log_section {
    my $section = <<'CAPTION_LOG_SECTION';
    <section aria-labelledby="log-heading">
      <div class="section-title">
        <h2 id="log-heading">Caption-Protokoll</h2>
        <span id="caption-count" class="count">0</span>
      </div>
      <div class="button-row">
        <button id="export-log" class="secondary">JSONL exportieren</button>
        <button id="clear" class="ghost">Anzeige leeren</button>
      </div>
      <div id="caption-list" class="list empty">Noch keine CaptionMessages empfangen.</div>
    </section>
CAPTION_LOG_SECTION

    return $section;
}

# Generate debug section
sub generate_debug_section {
    my $section = <<'DEBUG_SECTION';
    <section aria-labelledby="debug-heading">
      <div class="section-title">
        <h2 id="debug-heading">Debugmodus</h2>
        <span id="debug-count" class="count">0</span>
      </div>
      <label class="option-row"><input id="debug-enabled" type="checkbox"> Diagnoseereignisse für diesen Tab protokollieren</label>
      <div class="button-row">
        <button id="export-debug" class="secondary">Debug exportieren</button>
        <button id="clear-debug" class="ghost">Debug leeren</button>
      </div>
      <p class="muted small">Der Export entfernt Werte signierter URL-Parameter und enthält keine Cookies oder API-Keys.</p>
    </section>
DEBUG_SECTION

    return $section;
}

# Generate audience modal
sub generate_audience_modal {
    my $modal = <<'AUDIENCE_MODAL';
    <div id="audience-modal" class="modal-backdrop" hidden>
      <section class="modal" role="dialog" aria-modal="true" aria-labelledby="audience-heading">
        <div class="section-title">
          <h2 id="audience-heading">Im Chat beobachtete Personen</h2>
          <button id="close-audience" class="secondary compact" aria-label="Übersicht schließen">Schließen</button>
        </div>
        <p id="audience-limit" class="inline-status"></p>
        <div id="audience-list" class="audience-list"></div>
      </section>
    </div>
AUDIENCE_MODAL

    return $modal;
}

# Main execution
sub main {
    my $filename = shift @ARGV || 'sidepanel.html';
    
    open(my $fh, '>', $filename) or die "Could not open file '$filename': $!";
    print $fh generate_html();
    close $fh;
    
    print "Generated $filename\n";
}

# Run main if script is executed directly
main() if caller eq 'main';
