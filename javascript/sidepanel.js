#!/usr/bin/env node
// sidepanel.html — portiert nach javascript
// Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/sidepanel.html
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/sidepanel.html
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/sidepanel.html
// Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

// Helper function to create elements with attributes and content
function createElement(tag, attrs = {}, children = []) {
  const element = { tag, attrs, children };
  return element;
}

// Helper function to create text nodes
function createText(text) {
  return { type: 'text', content: text };
}

// Generate the complete HTML structure
function generateHTML() {
  // Create the document structure
  const docType = '<!doctype html>';
  
  const html = createElement('html', { lang: 'de' }, [
    createElement('head', {}, [
      createElement('meta', { charset: 'utf-8' }),
      createElement('meta', { name: 'viewport', content: 'width=device-width, initial-scale=1' }),
      createElement('title', {}, [createText('TikTok LIVE Companion')]),
      createElement('link', { rel: 'stylesheet', href: 'sidepanel.css' })
    ]),
    createElement('body', {}, [
      createElement('header', {}, [
        createElement('p', { id: 'page-title', class: 'muted' }, [createText('Kein TikTok-Tab ausgewählt')])
      ]),
      
      createElement('main', {}, [
        // Chat section
        createElement('section', { 'aria-labelledby': 'chat-heading' }, [
          createElement('div', { class: 'section-title' }, [
            createElement('h2', { id: 'chat-heading' }, [createText('Chat')]),
            createElement('div', { class: 'title-actions' }, [
              createElement('span', { id: 'chat-led', class: 'status-led off', role: 'status', 'aria-label': 'Chat inaktiv', title: 'Chat inaktiv' }),
              createElement('button', { id: 'chat-count', class: 'count count-button', type: 'button', 'aria-haspopup': 'dialog', title: 'Gesammelte Chatzeilen öffnen' }, [createText('0')]),
              createElement('button', { id: 'refresh-chat', class: 'secondary compact', title: 'Chatanzeige leeren' }, [createText('Refresh')]),
              createElement('button', { id: 'toggle-speech', class: 'secondary compact', 'aria-pressed': 'false', 'aria-label': 'Vorlesen' }, [createText('On')]),
              createElement('span', { id: 'speech-led', class: 'status-led off', role: 'status', 'aria-label': 'Vorlesen inaktiv', title: 'Vorlesen inaktiv' })
            ])
          ]),
          createElement('div', { id: 'chat-list', class: 'chat-list empty', role: 'log', 'aria-live': 'polite', 'aria-relevant': 'additions', 'aria-label': 'Die letzten fünf bereinigten Chatnachrichten' }, [createText('Noch keine Chatnachrichten erkannt.')]),
          createElement('p', { id: 'speech-status', role: 'status', class: 'inline-status' }, [createText('Vorlesen ist ausgeschaltet.')]),
          createElement('div', { class: 'control-label' }, [
            createElement('label', { for: 'speech-volume' }, [createText('Vorleselautstärke')]),
            createElement('output', { id: 'speech-volume-output', for: 'speech-volume' }, [createText('100%')])
          ]),
          createElement('input', { id: 'speech-volume', type: 'range', min: '0', max: '100', step: '5', value: '50' }),
          createElement('div', { class: 'button-row' }, [
            createElement('button', { id: 'service-action', class: 'secondary' }, [createText('Sprachdienst')]),
            createElement('button', { id: 'sherpa-action', class: 'secondary' }, [createText('Sherpa')]),
            createElement('button', { id: 'open-speech-settings', class: 'secondary compact settings-button', type: 'button', 'aria-label': 'Erweiterte Einstellungen öffnen', 'aria-haspopup': 'dialog', title: 'Einstellungen' }, [createText('⚙')])
          ]),
          createElement('p', { id: 'service-status', class: 'inline-status' }, [createText('Lokaler Sprachdienst noch nicht geprüft.')]),
          createElement('div', { id: 'service-setup', class: 'inline-status', hidden: '' }, [
            createElement('button', { id: 'copy-service-setup', class: 'secondary compact' }, [createText('Installation abschließen!')])
          ]),
          createElement('label', { class: 'option-row' }, [
            createElement('input', { id: 'keep-speech-active', type: 'checkbox' }),
            createText(' Permanent aktiv')
          ])
        ]),
        
        // Top Chatters section
        createElement('section', { 'aria-labelledby': 'top-chatters-heading' }, [
          createElement('div', { class: 'section-title' }, [
            createElement('h2', { id: 'top-chatters-heading' }, [createText('Top-Chatter')]),
            createElement('button', { id: 'open-audience', class: 'secondary compact' }, [createText('Zuschauer*innen')])
          ]),
          createElement('p', { id: 'team-tag-status', class: 'inline-status' }, [createText('Teamkürzel: noch nicht erkannt.')]),
          createElement('div', { id: 'top-chatters', class: 'top-chatters empty' }, [createText('Noch keine Personen im Chat beobachtet.')]),
          createElement('div', { id: 'top-chatters-actions', class: 'top-chatters-actions', hidden: '' }, [
            createElement('button', { id: 'top-chatters-reset', class: 'top-chatter-link', type: 'button', hidden: '' }, [createText('Reset')]),
            createElement('button', { id: 'top-chatters-more', class: 'top-chatter-link', type: 'button' }, [createText('mehr…')])
          ])
        ]),
        
        // Page Info section
        createElement('section', { id: 'page-info-section', 'aria-labelledby': 'page-info-heading' }, [
          createElement('div', { class: 'section-title' }, [
            createElement('h2', { id: 'page-info-heading' }, [createText('PROFIL-Information')]),
            createElement('div', { class: 'title-actions' }, [
              createElement('span', { id: 'page-info-source', class: 'live-indicator' }, [createText('Metadaten')]),
              createElement('button', { id: 'refresh-page-info', class: 'secondary compact' }, [createText('Refresh')]),
              createElement('button', { id: 'force-page-info', class: 'secondary compact danger-outline' }, [createText('Force')])
            ])
          ]),
          createElement('div', { id: 'profile-info', class: 'profile-info', hidden: '' }),
          createElement('div', { id: 'summary-info', class: 'summary-info' })
        ]),
        
        // Stats section
        createElement('section', { 'aria-labelledby': 'stats-heading' }, [
          createElement('div', { class: 'section-title' }, [
            createElement('h2', { id: 'stats-heading' }, [createText('LIVE-Information')]),
            createElement('span', { id: 'stats-live', class: 'live-indicator' }, [createText('warte')])
          ]),
          createElement('div', { id: 'live-stats', class: 'status-grid stats-grid' }),
          createElement('p', { id: 'stats-status', class: 'inline-status' })
        ]),
        
        // Hook section
        createElement('section', { 'aria-labelledby': 'hook-heading' }, [
          createElement('div', { class: 'section-title' }, [
            createElement('h2', { id: 'hook-heading' }, [createText('Connection')]),
            createElement('span', { id: 'hook-led', class: 'status-led off', role: 'status', 'aria-label': 'Hook inaktiv', title: 'Hook inaktiv' })
          ]),
          createElement('div', { class: 'button-row' }, [
            createElement('button', { id: 'toggle-hook', class: 'primary', 'aria-label': 'Connection', 'aria-pressed': 'false' }, [createText('On')]),
            createElement('button', { id: 'reset-tab', class: 'secondary danger-outline' }, [createText('Refresh')]),
            createElement('button', { id: 'open-embed-live', class: 'secondary' }, [createText('Embed')]),
            createElement('button', { id: 'open-normal-live', class: 'secondary' }, [createText('Browser')]),
            createElement('button', { id: 'player-vlc-frame', class: 'secondary compact' }, [createText('Player')]),
            createElement('button', { id: 'open-connection-settings', class: 'secondary compact settings-button', type: 'button', 'aria-label': 'Connection-Einstellungen öffnen', 'aria-haspopup': 'dialog' }, [createText('⚙')])
          ]),
          createElement('p', { id: 'hook-status', class: 'inline-status' }),
          createElement('p', { id: 'embed-startup-status', class: 'inline-status', role: 'status', 'aria-live': 'polite', hidden: '' }),
          createElement('button', { id: 'cancel-embed-startup', class: 'secondary', hidden: '' }, [createText('Embed-Start abbrechen')]),
          createElement('label', { class: 'option-row' }, [
            createElement('input', { id: 'hook-autostart', type: 'checkbox' }),
            createText(' Permanent Hook')
          ]),
          createElement('p', { id: 'hook-reconnect-status', class: 'inline-status', role: 'status' }, [createText('Hook-Reconnect: aus')]),
          createElement('p', { id: 'player-recovery-status', class: 'inline-status', role: 'status' }, [createText('Player-Recovery: aus')])
        ]),
        
        // Recommendations section
        createElement('section', { id: 'recommendations-section', 'aria-labelledby': 'recommendations-heading' }, [
          createElement('div', { class: 'section-title' }, [
            createElement('h2', { id: 'recommendations-heading' }, [createText('LIVE-Empfehlungen')]),
            createElement('span', { id: 'recommendation-status', class: 'live-indicator' }, [createText('bereit')])
          ]),
          createElement('div', { class: 'recommendation-controls' }, [
            createElement('label', {}, [
              createElement('span', {}, [createText('Anzahl')]),
              createElement('input', { id: 'recommendation-limit', type: 'number', min: '1', max: '50', step: '1', value: '20', inputmode: 'numeric' })
            ]),
            createElement('label', {}, [
              createElement('span', {}, [createText('Sortierung')]),
              createElement('select', { id: 'recommendation-sort' }, [
                createElement('option', { value: 'tiktok' }, [createText('TikTok-Reihenfolge')]),
                createElement('option', { value: 'viewers' }, [createText('Zuschauer*innen')])
              ])
            ])
          ]),
          createElement('div', { class: 'button-row' }, [
            createElement('button', { id: 'scan-recommendations', class: 'primary' }, [createText('Empfehlungen scannen')]),
            createElement('button', { id: 'cancel-recommendations', class: 'secondary', hidden: '' }, [createText('Abbrechen')])
          ]),
          createElement('p', { id: 'recommendation-progress', class: 'inline-status', 'aria-live': 'polite' }, [createText('Noch kein Scan gestartet.')]),
          createElement('div', { id: 'recommendation-list', class: 'recommendation-list empty' }, [createText('Noch keine Empfehlungen erfasst.')]),
          createElement('div', { id: 'recommendation-actions', class: 'top-chatters-actions', hidden: '' }, [
            createElement('button', { id: 'recommendation-more', class: 'top-chatter-link', type: 'button' }, [createText('mehr…')])
          ])
        ]),
        
        // Caption section
        createElement('section', { 'aria-labelledby': 'caption-heading' }, [
          createElement('div', { class: 'section-title' }, [
            createElement('h2', { id: 'caption-heading' }, [createText('Titel')]),
            createElement('button', { id: 'scan', class: 'secondary' }, [createText('Seite prüfen')])
          ]),
          createElement('div', { id: 'caption-status', class: 'status-grid' }),
          createElement('button', { id: 'enable-captions', class: 'primary' }, [createText('Untertitel aktivieren')]),
          createElement('p', { id: 'caption-action-status', role: 'status', class: 'inline-status action-status' })
        ]),
        
        // Player section
        createElement('section', { 'aria-labelledby': 'player-heading' }, [
          createElement('div', { class: 'section-title' }, [
            createElement('h2', { id: 'player-heading' }, [createText('Player')]),
            createElement('span', { id: 'player-time', class: 'player-time' }, [createText('–')])
          ]),
          createElement('div', { class: 'player-controls', role: 'group', 'aria-label': 'TikTok-Player steuern' }, [
            createElement('button', { id: 'player-play', class: 'secondary compact' }, [createText('Pause')]),
            createElement('button', { id: 'player-replay', class: 'secondary compact' }, [createText('Neu laden')]),
            createElement('button', { id: 'player-mute', class: 'secondary compact' }, [createText('Stumm')]),
            createElement('button', { id: 'player-pip', class: 'secondary compact' }, [createText('Bild-in-Bild')]),
            createElement('button', { id: 'player-fullscreen', class: 'secondary compact' }, [createText('Vollbild')]),
            createElement('button', { id: 'player-report', class: 'secondary compact danger-outline' }, [createText('Melden öffnen')])
          ]),
          createElement('div', { class: 'audio-controls' }, [
            createElement('div', { class: 'control-label' }, [
              createElement('label', { for: 'player-volume' }, [createText('Lautstärke')]),
              createElement('output', { id: 'player-volume-output', for: 'player-volume' }, [createText('–')])
            ]),
            createElement('input', { id: 'player-volume', type: 'range', min: '0', max: '100', step: '1', value: '100' }),
            createElement('div', { class: 'audio-meter-row' }, [
              createElement('span', {}, [createText('Spitzenpegel')]),
              createElement('strong', { id: 'player-peak' }, [createText('–')])
            ]),
            createElement('label', { class: 'option-row' }, [
              createElement('input', { id: 'limiter-enabled', type: 'checkbox' }),
              createText(' Pegelschutz aktivieren')
            ]),
            createElement('div', { class: 'control-label' }, [
              createElement('label', { for: 'limiter-strength' }, [createText('Schutzstärke')]),
              createElement('output', { id: 'limiter-strength-output', for: 'limiter-strength' }, [createText('30')])
            ]),
            createElement('input', { id: 'limiter-strength', type: 'range', min: '0', max: '100', step: '1', value: '30' })
          ]),
          createElement('p', { id: 'multi-guest-status', class: 'inline-status' }, [createText('Verbundene Streams: noch nicht erkannt.')]),
          createElement('p', { id: 'player-status', role: 'status', class: 'inline-status' }, [createText('Warte auf den TikTok-Player.')])
        ]),
        
        // Song section
        createElement('section', { 'aria-labelledby': 'song-heading' }, [
          createElement('div', { class: 'section-title' }, [
            createElement('h2', { id: 'song-heading' }, [createText('Songs')]),
            createElement('span', { id: 'song-led', class: 'status-led off', role: 'status', 'aria-label': 'Songerkennung inaktiv' })
          ]),
          createElement('label', { class: 'option-row' }, [
            createElement('input', { id: 'song-enabled', type: 'checkbox' }),
            createText(' Songerkennung aktivieren')
          ]),
          createElement('button', { id: 'recognize-song', class: 'primary', disabled: '' }, [createText('Jetzt erkennen')]),
          createElement('p', { id: 'song-status', class: 'inline-status' }),
          createElement('div', { id: 'song-result', class: 'song-result', hidden: '' })
        ]),
        
        // Links section
        createElement('section', { 'aria-labelledby': 'links-heading' }, [
          createElement('div', { class: 'section-title' }, [
            createElement('h2', { id: 'links-heading' }, [createText('HAR-Logs')]),
            createElement('span', { id: 'media-count', class: 'count' }, [createText('0')])
          ]),
          createElement('div', { id: 'media-list', class: 'list empty' }, [createText('Noch keine FLV-/HLS-Links erkannt.')]),
          createElement('p', { class: 'hint' }, [createText('Extern gestarteter VLC liegt außerhalb des Companion-Pegelschutzes.')])
        ]),
        
        // Log section
        createElement('section', { 'aria-labelledby': 'log-heading' }, [
          createElement('div', { class: 'section-title' }, [
            createElement('h2', { id: 'log-heading' }, [createText('LIVE-Logs')]),
            createElement('span', { id: 'caption-count', class: 'count' }, [createText('0')])
          ]),
          createElement('div', { class: 'button-row' }, [
            createElement('button', { id: 'export-log', class: 'secondary' }, [createText('JSON-L-Export')]),
            createElement('button', { id: 'export-caption-raw', class: 'secondary' }, [createText('RAW-JSON-Export')]),
            createElement('button', { id: 'clear', class: 'ghost' }, [createText('Anzeige leeren')])
          ]),
          createElement('div', { id: 'caption-list', class: 'list empty' }, [createText('Noch keine CaptionMessages empfangen.')])
        ]),
        
        // Debug section
        createElement('section', { 'aria-labelledby': 'debug-heading' }, [
          createElement('div', { class: 'section-title' }, [
            createElement('h2', { id: 'debug-heading' }, [createText('Debugmodus')]),
            createElement('span', { id: 'debug-count', class: 'count' }, [createText('0')])
          ]),
          createElement('label', { class: 'option-row' }, [
            createElement('input', { id: 'debug-enabled', type: 'checkbox' }),
            createText(' Diagnoseereignisse für diesen Tab protokollieren')
          ]),
          createElement('div', { class: 'button-row' }, [
            createElement('button', { id: 'export-debug', class: 'secondary' }, [createText('Debug exportieren')]),
            createElement('button', { id: 'clear-debug', class: 'ghost' }, [createText('Debug leeren')])
          ]),
          createElement('p', { class: 'muted small' })
        ]),
        
        // Audience modal
        createElement('div', { id: 'audience-modal', class: 'modal-backdrop', hidden: '' }, [
          createElement('section', { class: 'modal', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'audience-heading' }, [
            createElement('div', { class: 'section-title' }, [
              createElement('h2', { id: 'audience-heading' }, [createText('Im Chat beobachtete Personen')]),
              createElement('button', { id: 'close-audience', class: 'secondary compact', 'aria-label': 'Übersicht schließen' }, [createText('Schließen')])
            ]),
            createElement('p', { id: 'audience-limit', class: 'inline-status' }),
            createElement('div', { id: 'audience-list', class: 'audience-list' })
          ])
        ]),
        
        // Speech settings modal
        createElement('div', { id: 'speech-settings-modal', class: 'modal-backdrop', hidden: '' }, [
          createElement('section', { class: 'modal', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'speech-settings-heading' }, [
            createElement('div', { class: 'section-title' }, [
              createElement('h2', { id: 'speech-settings-heading' }, [createText('Erweiterte Einstellungen')]),
              createElement('button', { id: 'close-speech-settings', class: 'secondary compact', 'aria-label': 'Einstellungen schließen' }, [createText('Schließen')])
            ]),
            createElement('div', { class: 'settings-grid speech-integration-settings' }, [
              createElement('label', {}, [
                createElement('span', {}, [createText('Sprache')]),
                createElement('select', { id: 'speech-language' }, [
                  createElement('option', { value: 'auto' }, [createText('Auto')]),
                  createElement('option', { value: 'de-DE' }, [createText('Deutsch')]),
                  createElement('option', { value: 'en-US' }, [createText('Englisch')]),
                  createElement('option', { value: 'ru-RU' }, [createText('Russisch')]),
                  createElement('option', { value: 'uk-UA' }, [createText('Ukrainisch')]),
                  createElement('option', { value: 'bg-BG' }, [createText('Bulgarisch')]),
                  createElement('option', { value: 'sr-RS' }, [createText('Serbisch')]),
                  createElement('option', { value: 'kk-KZ' }, [createText('Kasachisch')]),
                  createElement('option', { value: 'zh-CN' }, [createText('Chinesisch')]),
                  createElement('option', { value: 'ja-JP' }, [createText('Japanisch')]),
                  createElement('option', { value: 'ko-KR' }, [createText('Koreanisch')]),
                  createElement('option', { value: 'ar-JO' }, [createText('Arabisch')]),
                  createElement('option', { value: 'fa-IR' }, [createText('Persisch')]),
                  createElement('option', { value: 'ur-PK' }, [createText('Urdu')]),
                  createElement('option', { value: 'hi-IN' }, [createText('Hindi')]),
                  createElement('option', { value: 'ne-NP' }, [createText('Nepali')]),
                  createElement('option', { value: 'ml-IN' }, [createText('Malayalam')])
                ])
              ]),
              createElement('label', {}, [
                createElement('span', {}, [createText('Stimme')]),
                createElement('select', { id: 'speech-voice' }, [
                  createElement('option', { value: '' }, [createText('Standard')])
                ])
              ]),
              createElement('label', { id: 'audd-token-setting' }, [
                createElement('span', { id: 'audd-token-label' }, [createText('AudD API-Token (optional - '), createElement('a', { href: 'https://audd.io/', target: '_blank', rel: 'noopener noreferrer' }, [createText('https://AudD.io')]), createText(' Trial/Paid)')]),
                createElement('input', { id: 'audd-token', type: 'password', autocomplete: 'off', spellcheck: 'false' })
              ]),
              createElement('label', { id: 'pairing-code-setting' }, [
                createElement('span', {}, [createText('Pairing-Code')]),
                createElement('input', { id: 'pairing-code', type: 'password', autocomplete: 'off', spellcheck: 'false' })
              ]),
              createElement('label', {}, [
                createElement('span', {}, [createText('Universal API-Key')]),
                createElement('input', { id: 'universal-caption-api-key', type: 'password', autocomplete: 'off', spellcheck: 'false' })
              ])
            ]),
            createElement('label', { class: 'option-row' }, [
              createElement('input', { id: 'speak-names', type: 'checkbox', checked: '' }),
              createText(' Chatnamen sprechen')
            ]),
            createElement('label', { class: 'option-row' }, [
              createElement('input', { id: 'shorten-names', type: 'checkbox' }),
              createText(' Chatnamen kürzen')
            ]),
            createElement('label', { class: 'option-row auto-chat-refresh' }, [
              createElement('input', { id: 'auto-chat-refresh', type: 'checkbox' }),
              createText(' Auto-Chat Refresh '),
              createElement('input', { id: 'auto-chat-refresh-minutes', type: 'number', min: '1', max: '60', step: '1', value: '5', inputmode: 'numeric', 'aria-label': 'Auto-Chat-Refresh in Minuten' }),
              createElement('span', {}, [createText('min.')])
            ]),
            createElement('label', { class: 'option-row' }, [
              createElement('input', { id: 'game-mode', type: 'checkbox' }),
              createText(' Game-Mode')
            ]),
            createElement('label', { class: 'option-row' }, [
              createElement('input', { id: 'filter-external-speech-triggers', type: 'checkbox' }),
              createText(' Trigger externer Sprachdienste filtern')
            ])
          ])
        ]),
        
        // Chat history modal
        createElement('div', { id: 'chat-history-modal', class: 'modal-backdrop', hidden: '' }, [
          createElement('section', { class: 'modal', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'chat-history-heading' }, [
            createElement('div', { class: 'section-title' }, [
              createElement('h2', { id: 'chat-history-heading' }, [createText('Gesammelte Chatnachrichten')]),
              createElement('button', { id: 'close-chat-history', class: 'secondary compact', 'aria-label': 'Chatzeilen schließen' }, [createText('Schließen')])
            ]),
            createElement('p', { id: 'chat-history-limit', class: 'inline-status' }),
            createElement('div', { id: 'chat-history-list', class: 'chat-history-list' })
          ])
        ]),
        
        // Recommendation modal
        createElement('div', { id: 'recommendation-modal', class: 'modal-backdrop', hidden: '' }, [
          createElement('section', { class: 'modal', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'recommendation-modal-heading' }, [
            createElement('div', { class: 'section-title' }, [
              createElement('h2', { id: 'recommendation-modal-heading' }, [createText('Gescannte LIVE-Empfehlungen')]),
              createElement('button', { id: 'close-recommendations', class: 'secondary compact', 'aria-label': 'Empfehlungen schließen' }, [createText('Schließen')])
            ]),
            createElement('div', { id: 'recommendation-modal-list', class: 'recommendation-list' })
          ])
        ]),
        
        // Notice
        createElement('p', { id: 'notice', role: 'alert', class: 'notice' })
      ]),
      
      // Connection settings modal
      createElement('div', { id: 'connection-settings-modal', class: 'modal-backdrop', hidden: '' }, [
        createElement('section', { class: 'modal', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'connection-settings-heading' }, [
          createElement('div', { class: 'section-title' }, [
            createElement('h2', { id: 'connection-settings-heading' }, [createText('Connection-Einstellungen')]),
            createElement('button', { id: 'close-connection-settings', class: 'secondary compact' }, [createText('Schließen')])
          ]),
          createElement('label', { class: 'option-row quick-recover-setting' }, [
            createElement('input', { id: 'hook-reconnect', type: 'checkbox' }),
            createText(' Hook-Reconnect '),
            createElement('input', { id: 'hook-reconnect-seconds', type: 'number', min: '1', max: '59', step: '1', value: '3', inputmode: 'numeric', 'aria-label': 'Hook-Reconnect-Wartezeit in Sekunden' }),
            createElement('span', {}, [createText('Sek.')])
          ]),
          createElement('label', { class: 'option-row quick-recover-setting' }, [
            createElement('input', { id: 'quick-recover', type: 'checkbox' }),
            createText(' Player-Recovery '),
            createElement('input', { id: 'quick-recover-seconds', type: 'number', min: '1', max: '59', step: '1', value: '3', inputmode: 'numeric', 'aria-label': 'Player-Recovery-Bestätigungszeit in Sekunden' }),
            createElement('span', {}, [createText('Sek.')])
          ])
        ])
      ]),
      
      // Scripts
      createElement('script', { src: 'content-core.js' }),
      createElement('script', { src: 'sidepanel.js' })
    ])
  ]);
  
  return { docType, html };
}

// Function to convert element tree to HTML string
function elementToString(element, indent = '') {
  if (element.type === 'text') {
    return element.content;
  }
  
  const tag = element.tag;
  const attrs = element.attrs || {};
  const children = element.children || [];
  
  let attrString = '';
  for (const [key, value] of Object.entries(attrs)) {
    if (value === '') {
      attrString += ` ${key}`;
    } else {
      attrString += ` ${key}="${value}"`;
    }
  }
  
  if (children.length === 0) {
    return `${indent}<${tag}${attrString}>`;
  }
  
  let result = `${indent}<${tag}${attrString}>`;
  
  if (children.length === 1 && children[0].type === 'text') {
    result += children[0].content;
    result += `</${tag}>`;
    return result;
  }
  
  result += '\n';
  const childIndent = indent + '  ';
  for (const child of children) {
    result += elementToString(child, childIndent) + '\n';
  }
  result += `${indent}</${tag}>`;
  
  return result;
}

// Function to render complete HTML document
function renderHTML(docType, htmlElement) {
  let result = docType + '\n';
  result += elementToString(htmlElement);
  return result;
}

// Main execution
function main() {
  const args = process.argv.slice(2);
  
  if (args.length !== 1) {
    console.error('Usage: node script.js <output-file>');
    process.exit(1);
  }
  
  const outputFile = args[0];
  const { docType, html } = generateHTML();
  const htmlString = renderHTML(docType, html);
  
  try {
    writeFileSync(outputFile, htmlString, 'utf8');
    console.log(`HTML file generated successfully: ${outputFile}`);
  } catch (error) {
    console.error('Error writing file:', error.message);
    process.exit(1);
  }
}

main();
