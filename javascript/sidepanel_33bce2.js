#!/usr/bin/env node
// sidepanel.html — portiert nach javascript
// Quelle: html, Projects@TikTok-Live-Companion:release/0.6.0/tiktok-live-companion-extension-0.6.0/sidepanel.html
// auch in: Projects@TikTok-Live-Companion:release/0.7.0/tiktok-live-companion-extension-0.7.0/sidepanel.html
// auch in: Projects@TikTok-Live-Companion-Android:release/0.6.0/tiktok-live-companion-extension-0.6.0/sidepanel.html
// auch in: Projects@TikTok-Live-Companion-Android:release/0.7.0/tiktok-live-companion-extension-0.7.0/sidepanel.html
// auch in: 2 weiteren Fundstellen
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');

function createSidePanel() {
  const doc = {
    doctype: 'html',
    html: {
      attributes: { lang: 'de' },
      head: {
        children: [
          { tag: 'meta', attributes: { charset: 'utf-8' } },
          { tag: 'meta', attributes: { name: 'viewport', content: 'width=device-width, initial-scale=1' } },
          { tag: 'title', text: 'TikTok LIVE Companion' },
          { tag: 'link', attributes: { rel: 'stylesheet', href: 'sidepanel.css' } }
        ]
      },
      body: {
        children: [
          {
            tag: 'header',
            children: [
              { tag: 'p', attributes: { id: 'page-title', class: 'muted' }, text: 'Kein TikTok-Tab ausgewählt' }
            ]
          },
          {
            tag: 'main',
            children: [
              // Chat section
              {
                tag: 'section',
                attributes: { 'aria-labelledby': 'chat-heading' },
                children: [
                  {
                    tag: 'div',
                    attributes: { class: 'section-title' },
                    children: [
                      { tag: 'h2', attributes: { id: 'chat-heading' }, text: 'Chatzeilen' },
                      {
                        tag: 'div',
                        attributes: { class: 'title-actions' },
                        children: [
                          { tag: 'span', attributes: { id: 'chat-led', class: 'status-led off', role: 'status', 'aria-label': 'Chat inaktiv', title: 'Chat inaktiv' } },
                          { tag: 'span', attributes: { id: 'chat-count', class: 'count' }, text: '0' },
                          { tag: 'button', attributes: { id: 'refresh-chat', class: 'secondary compact', title: 'Chatanzeige leeren' }, text: 'Refresh' },
                          { tag: 'button', attributes: { id: 'toggle-speech', class: 'secondary compact', 'aria-pressed': 'false' }, text: 'Vorlesen an' },
                          { tag: 'span', attributes: { id: 'speech-led', class: 'status-led off', role: 'status', 'aria-label': 'Vorlesen inaktiv', title: 'Vorlesen inaktiv' } }
                        ]
                      }
                    ]
                  },
                  { tag: 'div', attributes: { id: 'chat-list', class: 'chat-list empty', role: 'log', 'aria-live': 'polite', 'aria-relevant': 'additions', 'aria-label': 'Die letzten fünf bereinigten Chatnachrichten' }, text: 'Noch keine Chatnachrichten erkannt.' },
                  { tag: 'p', attributes: { id: 'speech-status', role: 'status', class: 'inline-status' }, text: 'Vorlesen ist ausgeschaltet.' },
                  { tag: 'div', attributes: { class: 'control-label' }, children: [
                    { tag: 'label', attributes: { for: 'speech-volume' }, text: 'Vorleselautstärke' },
                    { tag: 'output', attributes: { id: 'speech-volume-output', for: 'speech-volume' }, text: '100%' }
                  ]},
                  { tag: 'input', attributes: { id: 'speech-volume', type: 'range', min: '0', max: '100', step: '5', value: '50' } },
                  {
                    tag: 'div',
                    attributes: { class: 'settings-grid speech-settings' },
                    children: [
                      { tag: 'label', children: [
                        { tag: 'span', text: 'Sprache' },
                        { tag: 'select', attributes: { id: 'speech-language' }, children: [
                          { tag: 'option', attributes: { value: 'auto' }, text: 'Auto' },
                          { tag: 'option', attributes: { value: 'de-DE' }, text: 'Deutsch' },
                          { tag: 'option', attributes: { value: 'en-US' }, text: 'Englisch' }
                        ]}
                      ]},
                      { tag: 'label', children: [
                        { tag: 'span', text: 'Dienstadresse' },
                        { tag: 'input', attributes: { id: 'service-url', type: 'url', value: 'http://127.0.0.1:43117', spellcheck: 'false' } }
                      ]},
                      { tag: 'label', children: [
                        { tag: 'span', text: 'Pairing-Code' },
                        { tag: 'input', attributes: { id: 'pairing-code', type: 'password', autocomplete: 'off' } }
                      ]}
                    ]
                  },
                  { tag: 'p', attributes: { id: 'service-status', class: 'inline-status' }, text: 'Lokaler Sprachdienst noch nicht geprüft.' },
                  { tag: 'label', attributes: { class: 'option-row' }, children: [
                    { tag: 'input', attributes: { id: 'speak-names', type: 'checkbox', checked: true } },
                    { tag: 'span', text: ' Chatnamen vorlesen' }
                  ]},
                  { tag: 'label', attributes: { class: 'option-row' }, children: [
                    { tag: 'input', attributes: { id: 'shorten-names', type: 'checkbox' } },
                    { tag: 'span', text: ' Geeignete lange Namen kürzen' }
                  ]},
                  { tag: 'label', attributes: { class: 'option-row' }, children: [
                    { tag: 'input', attributes: { id: 'keep-speech-active', type: 'checkbox' } },
                    { tag: 'span', text: ' Vorlesen bei Tabwechsel oder Minimieren aktiv lassen' }
                  ]}
                ]
              },

              // Top chatters section
              {
                tag: 'section',
                attributes: { 'aria-labelledby': 'top-chatters-heading' },
                children: [
                  {
                    tag: 'div',
                    attributes: { class: 'section-title' },
                    children: [
                      { tag: 'h2', attributes: { id: 'top-chatters-heading' }, text: 'Top-Chatter' },
                      { tag: 'button', attributes: { id: 'open-audience', class: 'secondary compact' }, text: 'Zuschauer*innen' }
                    ]
                  },
                  { tag: 'p', attributes: { id: 'team-tag-status', class: 'inline-status' }, text: 'Teamkürzel: noch nicht erkannt.' },
                  { tag: 'div', attributes: { id: 'top-chatters', class: 'top-chatters empty' }, text: 'Noch keine Personen im Chat beobachtet.' }
                ]
              },

              // Song recognition section
              {
                tag: 'section',
                attributes: { 'aria-labelledby': 'song-heading' },
                children: [
                  {
                    tag: 'div',
                    attributes: { class: 'section-title' },
                    children: [
                      { tag: 'h2', attributes: { id: 'song-heading' }, text: 'Songerkennung' },
                      { tag: 'span', attributes: { id: 'song-led', class: 'status-led off', role: 'status', 'aria-label': 'Songerkennung inaktiv' } }
                    ]
                  },
                  { tag: 'label', attributes: { class: 'option-row' }, children: [
                    { tag: 'input', attributes: { id: 'song-enabled', type: 'checkbox' } },
                    { tag: 'span', text: ' Songerkennung aktivieren' }
                  ]},
                  { tag: 'button', attributes: { id: 'recognize-song', class: 'primary', disabled: true }, text: 'Jetzt erkennen' },
                  { tag: 'p', attributes: { id: 'song-status', class: 'inline-status' }, text: 'Es wird nichts aufgenommen oder übertragen.' },
                  { tag: 'div', attributes: { id: 'song-result', class: 'song-result', hidden: true } },
                  { tag: 'p', attributes: { class: 'muted small' }, text: 'Nach einem Klick werden etwa 12 Sekunden Tab-Audio über den lokalen Dienst an AudD übertragen. Anbietergebühren können anfallen.' }
                ]
              },

              // Captions section
              {
                tag: 'section',
                attributes: { 'aria-labelledby': 'caption-heading' },
                children: [
                  {
                    tag: 'div',
                    attributes: { class: 'section-title' },
                    children: [
                      { tag: 'h2', attributes: { id: 'caption-heading' }, text: 'Untertitel' },
                      { tag: 'button', attributes: { id: 'scan', class: 'secondary' }, text: 'Seite prüfen' }
                    ]
                  },
                  { tag: 'div', attributes: { id: 'caption-status', class: 'status-grid' } },
                  { tag: 'button', attributes: { id: 'enable-captions', class: 'primary' }, text: 'Untertitel aktivieren' },
                  { tag: 'p', attributes: { id: 'caption-action-status', role: 'status', class: 'inline-status action-status' }, text: 'Noch keine manuelle Prüfung ausgeführt.' }
                ]
              },

              // WebSocket hook section
              {
                tag: 'section',
                attributes: { 'aria-labelledby': 'hook-heading' },
                children: [
                  {
                    tag: 'div',
                    attributes: { class: 'section-title' },
                    children: [
                      { tag: 'h2', attributes: { id: 'hook-heading' }, text: 'WebSocket-Hook' },
                      { tag: 'span', attributes: { id: 'hook-led', class: 'status-led off', role: 'status', 'aria-label': 'Hook inaktiv', title: 'Hook inaktiv' } }
                    ]
                  },
                  { tag: 'p', attributes: { class: 'muted small' }, text: 'Der Hook wird vor dem Player-Code gesetzt. Der aktuelle Tab wird danach neu geladen.' },
                  {
                    tag: 'div',
                    attributes: { class: 'button-row' },
                    children: [
                      { tag: 'button', attributes: { id: 'enable-hook', class: 'primary' }, text: 'Hook setzen' },
                      { tag: 'button', attributes: { id: 'disable-hook', class: 'secondary' }, text: 'Hook deaktivieren' },
                      { tag: 'button', attributes: { id: 'reset-tab', class: 'secondary danger-outline' }, text: 'Refresh' }
                    ]
                  },
                  { tag: 'p', attributes: { id: 'hook-status', class: 'inline-status' } },
                  { tag: 'label', attributes: { class: 'option-row' }, children: [
                    { tag: 'input', attributes: { id: 'hook-autostart', type: 'checkbox' } },
                    { tag: 'span', text: ' Hook beim Öffnen von TikTok automatisch starten' }
                  ]},
                  { tag: 'p', attributes: { class: 'muted small reset-note' }, text: 'Refresh leert nur die flüchtigen Daten dieses Tabs, aktiviert den Hook erneut und lädt TikTok ohne Seitencache. cookies bleiben unverändert.' }
                ]
              },

              // Stats section
              {
                tag: 'section',
                attributes: { 'aria-labelledby': 'stats-heading' },
                children: [
                  {
                    tag: 'div',
                    attributes: { class: 'section-title' },
                    children: [
                      { tag: 'h2', attributes: { id: 'stats-heading' }, text: 'LIVE-Informationen' },
                      { tag: 'span', attributes: { id: 'stats-live', class: 'live-indicator' }, text: 'warte' }
                    ]
                  },
                  { tag: 'div', attributes: { id: 'live-stats', class: 'status-grid stats-grid' } },
                  { tag: 'p', attributes: { id: 'stats-status', class: 'inline-status' }, text: 'Der WebSocket-Hook liefert die Werte nach dem Neuladen des Streams.' }
                ]
              },

              // Player control section
              {
                tag: 'section',
                attributes: { 'aria-labelledby': 'player-heading' },
                children: [
                  {
                    tag: 'div',
                    attributes: { class: 'section-title' },
                    children: [
                      { tag: 'h2', attributes: { id: 'player-heading' }, text: 'Playersteuerung' },
                      { tag: 'span', attributes: { id: 'player-time', class: 'player-time' }, text: '–' }
                    ]
                  },
                  {
                    tag: 'div',
                    attributes: { class: 'player-controls', role: 'group', 'aria-label': 'TikTok-Player steuern' },
                    children: [
                      { tag: 'button', attributes: { id: 'player-play', class: 'secondary compact' }, text: 'Pause' },
                      { tag: 'button', attributes: { id: 'player-replay', class: 'secondary compact' }, text: 'Neu laden' },
                      { tag: 'button', attributes: { id: 'player-mute', class: 'secondary compact' }, text: 'Stumm' },
                      { tag: 'button', attributes: { id: 'player-pip', class: 'secondary compact' }, text: 'Bild-in-Bild' },
                      { tag: 'button', attributes: { id: 'player-fullscreen', class: 'secondary compact' }, text: 'Vollbild' },
                      { tag: 'button', attributes: { id: 'player-report', class: 'secondary compact danger-outline' }, text: 'Melden öffnen' }
                    ]
                  },
                  {
                    tag: 'div',
                    attributes: { class: 'audio-controls' },
                    children: [
                      { tag: 'div', attributes: { class: 'control-label' }, children: [
                        { tag: 'label', attributes: { for: 'player-volume' }, text: 'Lautstärke' },
                        { tag: 'output', attributes: { id: 'player-volume-output', for: 'player-volume' }, text: '–' }
                      ]},
                      { tag: 'input', attributes: { id: 'player-volume', type: 'range', min: '0', max: '100', step: '1', value: '100' } },
                      { tag: 'div', attributes: { class: 'audio-meter-row' }, children: [
                        { tag: 'span', text: 'Digitaler Spitzenpegel' },
                        { tag: 'strong', attributes: { id: 'player-peak' }, text: '– dBFS' }
                      ]},
                      { tag: 'label', attributes: { class: 'option-row' }, children: [
                        { tag: 'input', attributes: { id: 'limiter-enabled', type: 'checkbox' } },
                        { tag: 'span', text: ' Digitalen Pegelschutz aktivieren' }
                      ]},
                      { tag: 'div', attributes: { class: 'control-label' }, children: [
                        { tag: 'label', attributes: { for: 'limiter-threshold' }, text: 'Grenzwert' },
                        { tag: 'output', attributes: { id: 'limiter-threshold-output', for: 'limiter-threshold' }, text: '−6 dBFS' }
                      ]},
                      { tag: 'input', attributes: { id: 'limiter-threshold', type: 'range', min: '-30', max: '-1', step: '1', value: '-6' } },
                      { tag: 'p', attributes: { class: 'muted small audio-note' }, text: 'dBFS ist ein digitaler Signalpegel, kein am Ohr messbarer dB-SPL-Wert. Der Schutz komprimiert Spitzen oberhalb des Grenzwerts lokal im Browser.' }
                    ]
                  },
                  { tag: 'p', attributes: { id: 'multi-guest-status', class: 'inline-status' }, text: 'Verbundene Streams: noch nicht erkannt.' },
                  { tag: 'p', attributes: { id: 'player-status', role: 'status', class: 'inline-status' }, text: 'Warte auf den TikTok-Player.' }
                ]
              },

              // Page info section
              {
                tag: 'section',
                attributes: { id: 'page-info-section', 'aria-labelledby': 'page-info-heading' },
                children: [
                  {
                    tag: 'div',
                    attributes: { class: 'section-title' },
                    children: [
                      { tag: 'h2', attributes: { id: 'page-info-heading' }, text: 'Seiteninformationen' },
                      {
                        tag: 'div',
                        attributes: { class: 'title-actions' },
                        children: [
                          { tag: 'span', attributes: { id: 'page-info-source', class: 'live-indicator' }, text: 'Metadaten' },
                          { tag: 'button', attributes: { id: 'refresh-page-info', class: 'secondary compact' }, text: 'Refresh' },
                          { tag: 'button', attributes: { id: 'force-page-info', class: 'secondary compact danger-outline' }, text: 'Force' }
                        ]
                      }
                    ]
                  },
                  { tag: 'div', attributes: { id: 'profile-info', class: 'profile-info', hidden: true } },
                  { tag: 'div', attributes: { id: 'summary-info', class: 'summary-info' } }
                ]
              },

              // Quality section
              {
                tag: 'section',
                attributes: { 'aria-labelledby': 'quality-heading' },
                children: [
                  {
                    tag: 'div',
                    attributes: { class: 'section-title' },
                    children: [
                      { tag: 'h2', attributes: { id: 'quality-heading' }, text: 'Verfügbare Bildqualitäten' },
                      { tag: 'span', attributes: { id: 'quality-count', class: 'count' }, text: '0' }
                    ]
                  },
                  { tag: 'div', attributes: { id: 'quality-list', class: 'list empty' }, text: 'Noch keine Qualitätsstufen aus den Stream-Metadaten erkannt.' },
                  { tag: 'p', attributes: { id: 'quality-action-status', role: 'status', class: 'inline-status' } }
                ]
              },

              // VLC links section
              {
                tag: 'section',
                attributes: { 'aria-labelledby': 'links-heading' },
                children: [
                  {
                    tag: 'div',
                    attributes: { class: 'section-title' },
                    children: [
                      { tag: 'h2', attributes: { id: 'links-heading' }, text: 'VLC-Links' },
                      { tag: 'span', attributes: { id: 'media-count', class: 'count' }, text: '0' }
                    ]
                  },
                  { tag: 'div', attributes: { id: 'media-list', class: 'list empty' }, text: 'Noch keine FLV-/HLS-Links erkannt.' }
                ]
              },

              // Caption log section
              {
                tag: 'section',
                attributes: { 'aria-labelledby': 'log-heading' },
                children: [
                  {
                    tag: 'div',
                    attributes: { class: 'section-title' },
                    children: [
                      { tag: 'h2', attributes: { id: 'log-heading' }, text: 'Caption-Protokoll' },
                      { tag: 'span', attributes: { id: 'caption-count', class: 'count' }, text: '0' }
                    ]
                  },
                  {
                    tag: 'div',
                    attributes: { class: 'button-row' },
                    children: [
                      { tag: 'button', attributes: { id: 'export-log', class: 'secondary' }, text: 'JSONL exportieren' },
                      { tag: 'button', attributes: { id: 'clear', class: 'ghost' }, text: 'Anzeige leeren' }
                    ]
                  },
                  { tag: 'div', attributes: { id: 'caption-list', class: 'list empty' }, text: 'Noch keine CaptionMessages empfangen.' }
                ]
              },

              // Debug section
              {
                tag: 'section',
                attributes: { 'aria-labelledby': 'debug-heading' },
                children: [
                  {
                    tag: 'div',
                    attributes: { class: 'section-title' },
                    children: [
                      { tag: 'h2', attributes: { id: 'debug-heading' }, text: 'Debugmodus' },
                      { tag: 'span', attributes: { id: 'debug-count', class: 'count' }, text: '0' }
                    ]
                  },
                  { tag: 'label', attributes: { class: 'option-row' }, children: [
                    { tag: 'input', attributes: { id: 'debug-enabled', type: 'checkbox' } },
                    { tag: 'span', text: ' Diagnoseereignisse für diesen Tab protokollieren' }
                  ]},
                  {
                    tag: 'div',
                    attributes: { class: 'button-row' },
                    children: [
                      { tag: 'button', attributes: { id: 'export-debug', class: 'secondary' }, text: 'Debug exportieren' },
                      { tag: 'button', attributes: { id: 'clear-debug', class: 'ghost' }, text: 'Debug leeren' }
                    ]
                  },
                  { tag: 'p', attributes: { class: 'muted small' }, text: 'Der Export entfernt Werte signierter URL-Parameter und enthält keine cookies oder API-Keys.' }
                ]
              },

              // Audience modal
              {
                tag: 'div',
                attributes: { id: 'audience-modal', class: 'modal-backdrop', hidden: true },
                children: [
                  {
                    tag: 'section',
                    attributes: { class: 'modal', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'audience-heading' },
                    children: [
                      {
                        tag: 'div',
                        attributes: { class: 'section-title' },
                        children: [
                          { tag: 'h2', attributes: { id: 'audience-heading' }, text: 'Im Chat beobachtete Personen' },
                          { tag: 'button', attributes: { id: 'close-audience', class: 'secondary compact', 'aria-label': 'Übersicht schließen' }, text: 'Schließen' }
                        ]
                      },
                      { tag: 'p', attributes: { id: 'audience-limit', class: 'inline-status' } },
                      { tag: 'div', attributes: { id: 'audience-list', class: 'audience-list' } }
                    ]
                  }
                ]
              },

              // Notice
              { tag: 'p', attributes: { id: 'notice', role: 'alert', class: 'notice' } }
            ]
          },

          // Scripts
          { tag: 'script', attributes: { src: 'content-core.js' } },
          { tag: 'script', attributes: { src: 'sidepanel.js' } }
        ]
      }
    }
  };

  return doc;
}

function renderElement(element) {
  if (typeof element === 'string') {
    return element;
  }

  if (element.text && !element.children) {
    return element.text;
  }

  if (!element.tag) {
    return '';
  }

  let html = `<${element.tag}`;
  
  if (element.attributes) {
    for (const [key, value] of Object.entries(element.attributes)) {
      if (value === true) {
        html += ` ${key}`;
      } else if (value !== false && value !== undefined) {
        html += ` ${key}="${value}"`;
      }
    }
  }
  
  if (element.children || element.text) {
    html += '>';
    
    if (element.text) {
      html += element.text;
    }
    
    if (element.children) {
      for (const child of element.children) {
        html += renderElement(child);
      }
    }
    
    html += `</${element.tag}>`;
  } else {
    html += '>';
  }
  
  return html;
}

function renderDocument(doc) {
  let html = '<!DOCTYPE html>\n';
  html += renderElement(doc.html);
  return html;
}

// Main execution
if (require.main === module) {
  const outputPath = process.argv[2];
  
  if (!outputPath) {
    console.error('Bitte geben Sie einen Ausgabepfad an.');
    process.exit(1);
  }
  
  const document = createSidePanel();
  const htmlString = renderDocument(document);
  
  fs.writeFileSync(outputPath, htmlString, 'utf8');
  console.log(`HTML file created at: ${outputPath}`);
}

module.exports = { createSidePanel, renderDocument };
