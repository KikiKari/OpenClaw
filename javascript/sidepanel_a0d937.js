#!/usr/bin/env node
// sidepanel.html — portiert nach javascript
// Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/sidepanel.html
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/sidepanel.html
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/sidepanel.html
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');

function createHTMLElement(tag, attributes = {}, children = []) {
  const element = { tag, attributes, children };
  return element;
}

function createTextNode(text) {
  return { text };
}

function generateHTML() {
  const doctype = '<!doctype html>';
  
  const html = createHTMLElement('html', { lang: 'de' }, [
    createHTMLElement('head', {}, [
      createHTMLElement('meta', { charset: 'utf-8' }),
      createHTMLElement('meta', { name: 'viewport', content: 'width=device-width, initial-scale=1' }),
      createHTMLElement('title', {}, [createTextNode('TikTok LIVE Companion')]),
      createHTMLElement('link', { rel: 'stylesheet', href: 'sidepanel.css' })
    ]),
    createHTMLElement('body', {}, [
      createHTMLElement('header', {}, [
        createHTMLElement('p', { id: 'page-title', class: 'muted' }, [createTextNode('Kein TikTok-Tab ausgewählt')])
      ]),
      createHTMLElement('main', {}, [
        createHTMLElement('section', { 'aria-labelledby': 'chat-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'chat-heading' }, [createTextNode('Chatzeilen')]),
            createHTMLElement('div', { class: 'title-actions' }, [
              createHTMLElement('span', { id: 'chat-led', class: 'status-led off', role: 'status', 'aria-label': 'Chat inaktiv', title: 'Chat inaktiv' }),
              createHTMLElement('button', { id: 'chat-count', class: 'count count-button', type: 'button', 'aria-haspopup': 'dialog', title: 'Gesammelte Chatzeilen öffnen' }, [createTextNode('0')]),
              createHTMLElement('button', { id: 'refresh-chat', class: 'secondary compact', title: 'Chatanzeige leeren' }, [createTextNode('Refresh')]),
              createHTMLElement('button', { id: 'toggle-speech', class: 'secondary compact', 'aria-pressed': 'false' }, [createTextNode('Vorlesen')]),
              createHTMLElement('span', { id: 'speech-led', class: 'status-led off', role: 'status', 'aria-label': 'Vorlesen inaktiv', title: 'Vorlesen inaktiv' })
            ])
          ]),
          createHTMLElement('div', { id: 'chat-list', class: 'chat-list empty', role: 'log', 'aria-live': 'polite', 'aria-relevant': 'additions', 'aria-label': 'Die letzten fünf bereinigten Chatnachrichten' }, [createTextNode('Noch keine Chatnachrichten erkannt.')]),
          createHTMLElement('p', { id: 'speech-status', role: 'status', class: 'inline-status' }, [createTextNode('Vorlesen ist ausgeschaltet.')]),
          createHTMLElement('div', { class: 'control-label' }, [
            createHTMLElement('label', { for: 'speech-volume' }, [createTextNode('Vorleselautstärke')]),
            createHTMLElement('output', { id: 'speech-volume-output', for: 'speech-volume' }, [createTextNode('100%')])
          ]),
          createHTMLElement('input', { id: 'speech-volume', type: 'range', min: '0', max: '100', step: '5', value: '50' }),
          createHTMLElement('div', { class: 'button-row' }, [
            createHTMLElement('button', { id: 'service-action', class: 'secondary' }, [createTextNode('Sprachdienst')]),
            createHTMLElement('button', { id: 'sherpa-action', class: 'secondary' }, [createTextNode('Sherpa')]),
            createHTMLElement('button', { id: 'open-speech-settings', class: 'secondary compact settings-button', type: 'button', 'aria-label': 'Sprach- und Chat-Einstellungen öffnen', 'aria-haspopup': 'dialog', title: 'Einstellungen' }, [createTextNode('⚙')])
          ]),
          createHTMLElement('p', { id: 'service-status', class: 'inline-status' }, [createTextNode('Lokaler Sprachdienst noch nicht geprüft.')]),
          createHTMLElement('div', { id: 'service-setup', class: 'inline-status', hidden: '' }, [
            createHTMLElement('button', { id: 'copy-service-setup', class: 'secondary compact' }, [createTextNode('Installation abschließen!')])
          ]),
          createHTMLElement('label', { class: 'option-row auto-chat-refresh' }, [
            createHTMLElement('input', { id: 'auto-chat-refresh', type: 'checkbox' }),
            createTextNode(' Auto-Chat Refresh '),
            createHTMLElement('input', { id: 'auto-chat-refresh-minutes', type: 'number', min: '1', max: '60', step: '1', value: '5', inputmode: 'numeric', 'aria-label': 'Auto-Chat-Refresh in Minuten' }),
            createHTMLElement('span', {}, [createTextNode('min.')])
          ]),
          createHTMLElement('label', { class: 'option-row' }, [
            createHTMLElement('input', { id: 'keep-speech-active', type: 'checkbox' }),
            createTextNode(' Permanent aktiv')
          ])
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'top-chatters-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'top-chatters-heading' }, [createTextNode('Top-Chatter')]),
            createHTMLElement('button', { id: 'open-audience', class: 'secondary compact' }, [createTextNode('Zuschauer*innen')])
          ]),
          createHTMLElement('p', { id: 'team-tag-status', class: 'inline-status' }, [createTextNode('Teamkürzel: noch nicht erkannt.')]),
          createHTMLElement('div', { id: 'top-chatters', class: 'top-chatters empty' }, [createTextNode('Noch keine Personen im Chat beobachtet.')]),
          createHTMLElement('div', { id: 'top-chatters-actions', class: 'top-chatters-actions', hidden: '' }, [
            createHTMLElement('button', { id: 'top-chatters-reset', class: 'top-chatter-link', type: 'button', hidden: '' }, [createTextNode('Reset')]),
            createHTMLElement('button', { id: 'top-chatters-more', class: 'top-chatter-link', type: 'button' }, [createTextNode('mehr…')])
          ])
        ]),
        createHTMLElement('section', { id: 'page-info-section', 'aria-labelledby': 'page-info-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'page-info-heading' }, [createTextNode('Seiteninformationen')]),
            createHTMLElement('div', { class: 'title-actions' }, [
              createHTMLElement('span', { id: 'page-info-source', class: 'live-indicator' }, [createTextNode('Metadaten')]),
              createHTMLElement('button', { id: 'refresh-page-info', class: 'secondary compact' }, [createTextNode('Refresh')]),
              createHTMLElement('button', { id: 'force-page-info', class: 'secondary compact danger-outline' }, [createTextNode('Force')])
            ])
          ]),
          createHTMLElement('div', { id: 'profile-info', class: 'profile-info', hidden: '' }),
          createHTMLElement('div', { id: 'summary-info', class: 'summary-info' })
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'stats-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'stats-heading' }, [createTextNode('LIVE-Informationen')]),
            createHTMLElement('span', { id: 'stats-live', class: 'live-indicator' }, [createTextNode('warte')])
          ]),
          createHTMLElement('div', { id: 'live-stats', class: 'status-grid stats-grid' }),
          createHTMLElement('p', { id: 'stats-status', class: 'inline-status' })
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'hook-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'hook-heading' }, [createTextNode('WebSocket-Hook')]),
            createHTMLElement('span', { id: 'hook-led', class: 'status-led off', role: 'status', 'aria-label': 'Hook inaktiv', title: 'Hook inaktiv' })
          ]),
          createHTMLElement('div', { class: 'button-row' }, [
            createHTMLElement('button', { id: 'enable-hook', class: 'primary' }, [createTextNode('Hook setzen')]),
            createHTMLElement('button', { id: 'disable-hook', class: 'secondary' }, [createTextNode('Hook deaktivieren')]),
            createHTMLElement('button', { id: 'reset-tab', class: 'secondary danger-outline' }, [createTextNode('Refresh')]),
            createHTMLElement('button', { id: 'open-embed-live', class: 'secondary' }, [createTextNode('Embed')]),
            createHTMLElement('button', { id: 'open-normal-live', class: 'secondary' }, [createTextNode('Normal')]),
            createHTMLElement('button', { id: 'player-vlc-frame', class: 'secondary compact' }, [createTextNode('VLC Ersatz')])
          ]),
          createHTMLElement('p', { id: 'hook-status', class: 'inline-status' }),
          createHTMLElement('label', { class: 'option-row' }, [
            createHTMLElement('input', { id: 'hook-autostart', type: 'checkbox' }),
            createTextNode(' Permanent Hook')
          ]),
          createHTMLElement('label', { class: 'option-row quick-recover-setting' }, [
            createHTMLElement('input', { id: 'quick-recover', type: 'checkbox' }),
            createTextNode(' Auto-Reconnect '),
            createHTMLElement('input', { id: 'quick-recover-seconds', type: 'number', min: '1', max: '59', step: '1', value: '3', inputmode: 'numeric', 'aria-label': 'Auto-Reconnect-Wartezeit in Sekunden' }),
            createHTMLElement('span', {}, [createTextNode('Sek.')])
          ])
        ]),
        createHTMLElement('section', { id: 'recommendations-section', 'aria-labelledby': 'recommendations-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'recommendations-heading' }, [createTextNode('LIVE-Empfehlungen')]),
            createHTMLElement('span', { id: 'recommendation-status', class: 'live-indicator' }, [createTextNode('bereit')])
          ]),
          createHTMLElement('div', { class: 'recommendation-controls' }, [
            createHTMLElement('label', {}, [
              createHTMLElement('span', {}, [createTextNode('Anzahl')]),
              createHTMLElement('input', { id: 'recommendation-limit', type: 'number', min: '1', max: '50', step: '1', value: '20', inputmode: 'numeric' })
            ]),
            createHTMLElement('label', {}, [
              createHTMLElement('span', {}, [createTextNode('Sortierung')]),
              createHTMLElement('select', { id: 'recommendation-sort' }, [
                createHTMLElement('option', { value: 'tiktok' }, [createTextNode('TikTok-Reihenfolge')]),
                createHTMLElement('option', { value: 'viewers' }, [createTextNode('Zuschauer*innen')])
              ])
            ])
          ]),
          createHTMLElement('div', { class: 'button-row' }, [
            createHTMLElement('button', { id: 'scan-recommendations', class: 'primary' }, [createTextNode('Empfehlungen scannen')]),
            createHTMLElement('button', { id: 'cancel-recommendations', class: 'secondary', hidden: '' }, [createTextNode('Abbrechen')])
          ]),
          createHTMLElement('p', { id: 'recommendation-progress', class: 'inline-status', 'aria-live': 'polite' }, [createTextNode('Noch kein Scan gestartet.')]),
          createHTMLElement('div', { id: 'recommendation-list', class: 'recommendation-list empty' }, [createTextNode('Noch keine Empfehlungen erfasst.')]),
          createHTMLElement('div', { id: 'recommendation-actions', class: 'top-chatters-actions', hidden: '' }, [
            createHTMLElement('button', { id: 'recommendation-more', class: 'top-chatter-link', type: 'button' }, [createTextNode('mehr…')])
          ])
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'caption-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'caption-heading' }, [createTextNode('Untertitel')]),
            createHTMLElement('button', { id: 'scan', class: 'secondary' }, [createTextNode('Seite prüfen')])
          ]),
          createHTMLElement('div', { id: 'caption-status', class: 'status-grid' }),
          createHTMLElement('button', { id: 'enable-captions', class: 'primary' }, [createTextNode('Untertitel aktivieren')]),
          createHTMLElement('p', { id: 'caption-action-status', role: 'status', class: 'inline-status action-status' })
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'player-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'player-heading' }, [createTextNode('Playersteuerung')]),
            createHTMLElement('span', { id: 'player-time', class: 'player-time' }, [createTextNode('–')])
          ]),
          createHTMLElement('div', { class: 'player-controls', role: 'group', 'aria-label': 'TikTok-Player steuern' }, [
            createHTMLElement('button', { id: 'player-play', class: 'secondary compact' }, [createTextNode('Pause')]),
            createHTMLElement('button', { id: 'player-replay', class: 'secondary compact' }, [createTextNode('Neu laden')]),
            createHTMLElement('button', { id: 'player-mute', class: 'secondary compact' }, [createTextNode('Stumm')]),
            createHTMLElement('button', { id: 'player-pip', class: 'secondary compact' }, [createTextNode('Bild-in-Bild')]),
            createHTMLElement('button', { id: 'player-fullscreen', class: 'secondary compact' }, [createTextNode('Vollbild')]),
            createHTMLElement('button', { id: 'player-report', class: 'secondary compact danger-outline' }, [createTextNode('Melden öffnen')])
          ]),
          createHTMLElement('div', { class: 'audio-controls' }, [
            createHTMLElement('div', { class: 'control-label' }, [
              createHTMLElement('label', { for: 'player-volume' }, [createTextNode('Lautstärke')]),
              createHTMLElement('output', { id: 'player-volume-output', for: 'player-volume' }, [createTextNode('–')])
            ]),
            createHTMLElement('input', { id: 'player-volume', type: 'range', min: '0', max: '100', step: '1', value: '100' }),
            createHTMLElement('div', { class: 'audio-meter-row' }, [
              createHTMLElement('span', {}, [createTextNode('Spitzenpegel')]),
              createHTMLElement('strong', { id: 'player-peak' }, [createTextNode('–')])
            ]),
            createHTMLElement('label', { class: 'option-row' }, [
              createHTMLElement('input', { id: 'limiter-enabled', type: 'checkbox' }),
              createTextNode(' Pegelschutz aktivieren')
            ]),
            createHTMLElement('div', { class: 'control-label' }, [
              createHTMLElement('label', { for: 'limiter-strength' }, [createTextNode('Schutzstärke')]),
              createHTMLElement('output', { id: 'limiter-strength-output', for: 'limiter-strength' }, [createTextNode('30')])
            ]),
            createHTMLElement('input', { id: 'limiter-strength', type: 'range', min: '0', max: '100', step: '1', value: '30' })
          ]),
          createHTMLElement('p', { id: 'multi-guest-status', class: 'inline-status' }, [createTextNode('Verbundene Streams: noch nicht erkannt.')]),
          createHTMLElement('p', { id: 'player-status', role: 'status', class: 'inline-status' }, [createTextNode('Warte auf den TikTok-Player.')])
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'song-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'song-heading' }, [createTextNode('Songerkennung')]),
            createHTMLElement('span', { id: 'song-led', class: 'status-led off', role: 'status', 'aria-label': 'Songerkennung inaktiv' })
          ]),
          createHTMLElement('label', { class: 'option-row' }, [
            createHTMLElement('input', { id: 'song-enabled', type: 'checkbox' }),
            createTextNode(' Songerkennung aktivieren')
          ]),
          createHTMLElement('button', { id: 'recognize-song', class: 'primary', disabled: '' }, [createTextNode('Jetzt erkennen')]),
          createHTMLElement('p', { id: 'song-status', class: 'inline-status' }),
          createHTMLElement('div', { id: 'song-result', class: 'song-result', hidden: '' })
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'links-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'links-heading' }, [createTextNode('VLC-Links')]),
            createHTMLElement('span', { id: 'media-count', class: 'count' }, [createTextNode('0')])
          ]),
          createHTMLElement('div', { id: 'media-list', class: 'list empty' }, [createTextNode('Noch keine FLV-/HLS-Links erkannt.')])
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'log-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'log-heading' }, [createTextNode('Caption-Protokoll')]),
            createHTMLElement('span', { id: 'caption-count', class: 'count' }, [createTextNode('0')])
          ]),
          createHTMLElement('div', { class: 'button-row' }, [
            createHTMLElement('button', { id: 'export-log', class: 'secondary' }, [createTextNode('JSON-L-Export')]),
            createHTMLElement('button', { id: 'export-caption-raw', class: 'secondary' }, [createTextNode('RAW-JSON-Export')]),
            createHTMLElement('button', { id: 'clear', class: 'ghost' }, [createTextNode('Anzeige leeren')])
          ]),
          createHTMLElement('div', { id: 'caption-list', class: 'list empty' }, [createTextNode('Noch keine CaptionMessages empfangen.')])
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'debug-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'debug-heading' }, [createTextNode('Debugmodus')]),
            createHTMLElement('span', { id: 'debug-count', class: 'count' }, [createTextNode('0')])
          ]),
          createHTMLElement('label', { class: 'option-row' }, [
            createHTMLElement('input', { id: 'debug-enabled', type: 'checkbox' }),
            createTextNode(' Diagnoseereignisse für diesen Tab protokollieren')
          ]),
          createHTMLElement('div', { class: 'button-row' }, [
            createHTMLElement('button', { id: 'export-debug', class: 'secondary' }, [createTextNode('Debug exportieren')]),
            createHTMLElement('button', { id: 'clear-debug', class: 'ghost' }, [createTextNode('Debug leeren')])
          ]),
          createHTMLElement('p', { class: 'muted small' })
        ]),
        createHTMLElement('div', { id: 'audience-modal', class: 'modal-backdrop', hidden: '' }, [
          createHTMLElement('section', { class: 'modal', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'audience-heading' }, [
            createHTMLElement('div', { class: 'section-title' }, [
              createHTMLElement('h2', { id: 'audience-heading' }, [createTextNode('Im Chat beobachtete Personen')]),
              createHTMLElement('button', { id: 'close-audience', class: 'secondary compact', 'aria-label': 'Übersicht schließen' }, [createTextNode('Schließen')])
            ]),
            createHTMLElement('p', { id: 'audience-limit', class: 'inline-status' }),
            createHTMLElement('div', { id: 'audience-list', class: 'audience-list' })
          ])
        ]),
        createHTMLElement('div', { id: 'speech-settings-modal', class: 'modal-backdrop', hidden: '' }, [
          createHTMLElement('section', { class: 'modal', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'speech-settings-heading' }, [
            createHTMLElement('div', { class: 'section-title' }, [
              createHTMLElement('h2', { id: 'speech-settings-heading' }, [createTextNode('Sprach- und Chat-Einstellungen')]),
              createHTMLElement('button', { id: 'close-speech-settings', class: 'secondary compact', 'aria-label': 'Einstellungen schließen' }, [createTextNode('Schließen')])
            ]),
            createHTMLElement('div', { class: 'settings-grid speech-integration-settings' }, [
              createHTMLElement('label', {}, [
                createHTMLElement('span', {}, [createTextNode('Sprache')]),
                createHTMLElement('select', { id: 'speech-language' }, [
                  createHTMLElement('option', { value: 'auto' }, [createTextNode('Auto')]),
                  createHTMLElement('option', { value: 'de-DE' }, [createTextNode('Deutsch')]),
                  createHTMLElement('option', { value: 'en-US' }, [createTextNode('Englisch')]),
                  createHTMLElement('option', { value: 'ru-RU' }, [createTextNode('Russisch')]),
                  createHTMLElement('option', { value: 'uk-UA' }, [createTextNode('Ukrainisch')]),
                  createHTMLElement('option', { value: 'bg-BG' }, [createTextNode('Bulgarisch')]),
                  createHTMLElement('option', { value: 'sr-RS' }, [createTextNode('Serbisch')]),
                  createHTMLElement('option', { value: 'kk-KZ' }, [createTextNode('Kasachisch')]),
                  createHTMLElement('option', { value: 'zh-CN' }, [createTextNode('Chinesisch')]),
                  createHTMLElement('option', { value: 'ja-JP' }, [createTextNode('Japanisch')]),
                  createHTMLElement('option', { value: 'ko-KR' }, [createTextNode('Koreanisch')]),
                  createHTMLElement('option', { value: 'ar-JO' }, [createTextNode('Arabisch')]),
                  createHTMLElement('option', { value: 'fa-IR' }, [createTextNode('Persisch')]),
                  createHTMLElement('option', { value: 'ur-PK' }, [createTextNode('Urdu')]),
                  createHTMLElement('option', { value: 'hi-IN' }, [createTextNode('Hindi')]),
                  createHTMLElement('option', { value: 'ne-NP' }, [createTextNode('Nepali')]),
                  createHTMLElement('option', { value: 'ml-IN' }, [createTextNode('Malayalam')])
                ])
              ]),
              createHTMLElement('label', {}, [
                createHTMLElement('span', {}, [createTextNode('Stimme')]),
                createHTMLElement('select', { id: 'speech-voice' }, [
                  createHTMLElement('option', { value: '' }, [createTextNode('Standard')])
                ])
              ]),
              createHTMLElement('label', { id: 'audd-token-setting' }, [
                createHTMLElement('span', { id: 'audd-token-label' }, [createTextNode('AudD API-Token (optional - '), createHTMLElement('a', { href: 'https://audd.io/', target: '_blank', rel: 'noopener noreferrer' }, [createTextNode('https://AudD.io')]), createTextNode(' Trial/Paid)')]),
                createHTMLElement('input', { id: 'audd-token', type: 'password', autocomplete: 'off', spellcheck: 'false' })
              ]),
              createHTMLElement('label', { id: 'pairing-code-setting' }, [
                createHTMLElement('span', {}, [createTextNode('Pairing-Code')]),
                createHTMLElement('input', { id: 'pairing-code', type: 'password', autocomplete: 'off', spellcheck: 'false' })
              ]),
              createHTMLElement('label', {}, [
                createHTMLElement('span', {}, [createTextNode('Universal API-Key für Untertitel')]),
                createHTMLElement('input', { id: 'universal-caption-api-key', type: 'password', autocomplete: 'off', spellcheck: 'false' })
              ])
            ]),
            createHTMLElement('label', { class: 'option-row' }, [
              createHTMLElement('input', { id: 'speak-names', type: 'checkbox', checked: '' }),
              createTextNode(' Chatnamen sprechen')
            ]),
            createHTMLElement('label', { class: 'option-row' }, [
              createHTMLElement('input', { id: 'shorten-names', type: 'checkbox' }),
              createTextNode(' Chatnamen kürzen')
            ]),
            createHTMLElement('label', { class: 'option-row' }, [
              createHTMLElement('input', { id: 'game-mode', type: 'checkbox' }),
              createTextNode(' Game-Mode')
            ])
          ])
        ]),
        createHTMLElement('div', { id: 'chat-history-modal', class: 'modal-backdrop', hidden: '' }, [
          createHTMLElement('section', { class: 'modal', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'chat-history-heading' }, [
            createHTMLElement('div', { class: 'section-title' }, [
              createHTMLElement('h2', { id: 'chat-history-heading' }, [createTextNode('Gesammelte Chatzeilen')]),
              createHTMLElement('button', { id: 'close-chat-history', class: 'secondary compact', 'aria-label': 'Chatzeilen schließen' }, [createTextNode('Schließen')])
            ]),
            createHTMLElement('p', { id: 'chat-history-limit', class: 'inline-status' }),
            createHTMLElement('div', { id: 'chat-history-list', class: 'chat-history-list' })
          ])
        ]),
        createHTMLElement('div', { id: 'recommendation-modal', class: 'modal-backdrop', hidden: '' }, [
          createHTMLElement('section', { class: 'modal', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'recommendation-modal-heading' }, [
            createHTMLElement('div', { class: 'section-title' }, [
              createHTMLElement('h2', { id: 'recommendation-modal-heading' }, [createTextNode('Gescannte LIVE-Empfehlungen')]),
              createHTMLElement('button', { id: 'close-recommendations', class: 'secondary compact', 'aria-label': 'Empfehlungen schließen' }, [createTextNode('Schließen')])
            ]),
            createHTMLElement('div', { id: 'recommendation-modal-list', class: 'recommendation-list' })
          ])
        ]),
        createHTMLElement('p', { id: 'notice', role: 'alert', class: 'notice' })
      ]),
      createHTMLElement('script', { src: 'content-core.js' }),
      createHTMLElement('script', { src: 'sidepanel.js' })
    ])
  ]);

  function renderElement(element) {
    if (element.text !== undefined) {
      return element.text;
    }
    
    const tag = element.tag;
    const attributes = element.attributes || {};
    const children = element.children || [];
    
    let attrString = '';
    for (const [key, value] of Object.entries(attributes)) {
      if (value === '') {
        attrString += ` ${key}`;
      } else {
        attrString += ` ${key}="${value}"`;
      }
    }
    
    if (children.length === 0) {
      return `<${tag}${attrString}>`;
    }
    
    let childrenString = '';
    for (const child of children) {
      childrenString += renderElement(child);
    }
    
    return `<${tag}${attrString}>${childrenString}</${tag}>`;
  }

  return doctype + '\n' + renderElement(html);
}

function main() {
  if (process.argv.length !== 3) {
    console.error('Usage: node ' + path.basename(__filename) + ' <output-file>');
    process.exit(1);
  }

  const outputFile = process.argv[2];
  const htmlContent = generateHTML();
  
  try {
    fs.writeFileSync(outputFile, htmlContent, 'utf8');
    console.log('HTML file generated successfully: ' + outputFile);
  } catch (error) {
    console.error('Error writing file:', error.message);
    process.exit(1);
  }
}

main();
