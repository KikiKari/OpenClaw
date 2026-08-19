#!/usr/bin/env node
// sidepanel.html — portiert nach javascript
// Quelle: html, Projects@TikTok-Live-Companion:release/0.7.1/tiktok-live-companion-extension-0.7.1/sidepanel.html
// auch in: Projects@TikTok-Live-Companion-Android:release/0.7.1/tiktok-live-companion-extension-0.7.1/sidepanel.html
// auch in: Projects@TikTok-Live-Companion-iOS:release/0.7.1/tiktok-live-companion-extension-0.7.1/sidepanel.html
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

function createHTMLElement(tag, attributes = {}, children = []) {
  const element = { tag, attributes, children };
  return element;
}

function createText(text) {
  return { text };
}

function generateHTML() {
  // Create the document structure
  const doctype = '<!doctype html>';
  
  const html = createHTMLElement('html', { lang: 'de' }, [
    createHTMLElement('head', {}, [
      createHTMLElement('meta', { charset: 'utf-8' }),
      createHTMLElement('meta', { name: 'viewport', content: 'width=device-width, initial-scale=1' }),
      createHTMLElement('title', {}, [createText('TikTok LIVE Companion')]),
      createHTMLElement('link', { rel: 'stylesheet', href: 'sidepanel.css' })
    ]),
    createHTMLElement('body', {}, [
      createHTMLElement('header', {}, [
        createHTMLElement('p', { id: 'page-title', class: 'muted' }, [createText('Kein TikTok-Tab ausgewählt')])
      ]),
      createHTMLElement('main', {}, [
        createHTMLElement('section', { 'aria-labelledby': 'chat-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'chat-heading' }, [createText('Chatzeilen')]),
            createHTMLElement('div', { class: 'title-actions' }, [
              createHTMLElement('span', { id: 'chat-led', class: 'status-led off', role: 'status', 'aria-label': 'Chat inaktiv', title: 'Chat inaktiv' }),
              createHTMLElement('button', { id: 'chat-count', class: 'count count-button', type: 'button', 'aria-haspopup': 'dialog', title: 'Gesammelte Chatzeilen öffnen' }, [createText('0')]),
              createHTMLElement('button', { id: 'refresh-chat', class: 'secondary compact', title: 'Chatanzeige leeren' }, [createText('Refresh')]),
              createHTMLElement('button', { id: 'toggle-speech', class: 'secondary compact', 'aria-pressed': 'false' }, [createText('Vorlesen an')]),
              createHTMLElement('span', { id: 'speech-led', class: 'status-led off', role: 'status', 'aria-label': 'Vorlesen inaktiv', title: 'Vorlesen inaktiv' })
            ])
          ]),
          createHTMLElement('div', { id: 'chat-list', class: 'chat-list empty', role: 'log', 'aria-live': 'polite', 'aria-relevant': 'additions', 'aria-label': 'Die letzten fünf bereinigten Chatnachrichten' }, [createText('Noch keine Chatnachrichten erkannt.')]),
          createHTMLElement('p', { id: 'speech-status', role: 'status', class: 'inline-status' }, [createText('Vorlesen ist ausgeschaltet.')]),
          createHTMLElement('div', { class: 'control-label' }, [
            createHTMLElement('label', { for: 'speech-volume' }, [createText('Vorleselautstärke')]),
            createHTMLElement('output', { id: 'speech-volume-output', for: 'speech-volume' }, [createText('100%')])
          ]),
          createHTMLElement('input', { id: 'speech-volume', type: 'range', min: '0', max: '100', step: '5', value: '50' }),
          createHTMLElement('div', { class: 'settings-grid speech-settings' }, [
            createHTMLElement('label', {}, [
              createHTMLElement('span', {}, [createText('Sprache')]),
              createHTMLElement('select', { id: 'speech-language' }, [
                createHTMLElement('option', { value: 'auto' }, [createText('Auto')]),
                createHTMLElement('option', { value: 'de-DE' }, [createText('Deutsch')]),
                createHTMLElement('option', { value: 'en-US' }, [createText('Englisch')]),
                createHTMLElement('option', { value: 'ru-RU' }, [createText('Russisch')]),
                createHTMLElement('option', { value: 'uk-UA' }, [createText('Ukrainisch')]),
                createHTMLElement('option', { value: 'bg-BG' }, [createText('Bulgarisch')]),
                createHTMLElement('option', { value: 'sr-RS' }, [createText('Serbisch')]),
                createHTMLElement('option', { value: 'kk-KZ' }, [createText('Kasachisch')]),
                createHTMLElement('option', { value: 'zh-CN' }, [createText('Chinesisch')]),
                createHTMLElement('option', { value: 'ja-JP' }, [createText('Japanisch')]),
                createHTMLElement('option', { value: 'ko-KR' }, [createText('Koreanisch')]),
                createHTMLElement('option', { value: 'ar-JO' }, [createText('Arabisch')]),
                createHTMLElement('option', { value: 'fa-IR' }, [createText('Persisch')]),
                createHTMLElement('option', { value: 'ur-PK' }, [createText('Urdu')]),
                createHTMLElement('option', { value: 'hi-IN' }, [createText('Hindi')]),
                createHTMLElement('option', { value: 'ne-NP' }, [createText('Nepali')]),
                createHTMLElement('option', { value: 'ml-IN' }, [createText('Malayalam')])
              ])
            ]),
            createHTMLElement('label', {}, [
              createHTMLElement('span', {}, [createText('Stimme')]),
              createHTMLElement('select', { id: 'speech-voice' }, [
                createHTMLElement('option', { value: '' }, [createText('Standard')])
              ])
            ]),
            createHTMLElement('label', { id: 'audd-token-setting' }, [
              createHTMLElement('span', { id: 'audd-token-label' }, [
                createText('AudD API-Token (optional - '),
                createHTMLElement('a', { href: 'https://audd.io/', target: '_blank', rel: 'noopener noreferrer' }, [createText('https://AudD.io')]),
                createText(' Trial/Paid )')
              ]),
              createHTMLElement('input', { id: 'audd-token', type: 'password', autocomplete: 'off', spellcheck: 'false' })
            ]),
            createHTMLElement('label', { id: 'pairing-code-setting' }, [
              createHTMLElement('span', {}, [createText('Pairing-Code')]),
              createHTMLElement('input', { id: 'pairing-code', type: 'password', autocomplete: 'off', spellcheck: 'false' })
            ])
          ]),
          createHTMLElement('div', { class: 'button-row' }, [
            createHTMLElement('button', { id: 'service-action', class: 'secondary' }, [createText('Sprachdienst installieren')]),
            createHTMLElement('button', { id: 'sherpa-action', class: 'secondary' }, [createText('Sherpa installieren')])
          ]),
          createHTMLElement('p', { id: 'service-status', class: 'inline-status' }, [createText('Lokaler Sprachdienst noch nicht geprüft.')]),
          createHTMLElement('div', { id: 'service-setup', class: 'inline-status', hidden: '' }, [
            createHTMLElement('button', { id: 'copy-service-setup', class: 'secondary compact' }, [createText('Installation abschließen!')])
          ]),
          createHTMLElement('label', { class: 'option-row' }, [
            createHTMLElement('input', { id: 'speak-names', type: 'checkbox', checked: '' }),
            createText(' Chatnamen sprechen')
          ]),
          createHTMLElement('label', { class: 'option-row' }, [
            createHTMLElement('input', { id: 'shorten-names', type: 'checkbox' }),
            createText(' Chatnamen kürzen')
          ]),
          createHTMLElement('label', { class: 'option-row' }, [
            createHTMLElement('input', { id: 'game-mode', type: 'checkbox' }),
            createText(' Game-Mode')
          ]),
          createHTMLElement('label', { class: 'option-row auto-chat-refresh' }, [
            createHTMLElement('input', { id: 'auto-chat-refresh', type: 'checkbox' }),
            createText(' Auto-Chat Refresh '),
            createHTMLElement('input', { id: 'auto-chat-refresh-minutes', type: 'number', min: '1', max: '60', step: '1', value: '5', inputmode: 'numeric', 'aria-label': 'Auto-Chat-Refresh in Minuten' }),
            createHTMLElement('span', {}, [createText('min.')])
          ]),
          createHTMLElement('label', { class: 'option-row' }, [
            createHTMLElement('input', { id: 'keep-speech-active', type: 'checkbox' }),
            createText(' Permanent aktiv')
          ])
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'top-chatters-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'top-chatters-heading' }, [createText('Top-Chatter')]),
            createHTMLElement('button', { id: 'open-audience', class: 'secondary compact' }, [createText('Zuschauer*innen')])
          ]),
          createHTMLElement('p', { id: 'team-tag-status', class: 'inline-status' }, [createText('Teamkürzel: noch nicht erkannt.')]),
          createHTMLElement('div', { id: 'top-chatters', class: 'top-chatters empty' }, [createText('Noch keine Personen im Chat beobachtet.')]),
          createHTMLElement('div', { id: 'top-chatters-actions', class: 'top-chatters-actions', hidden: '' }, [
            createHTMLElement('button', { id: 'top-chatters-reset', class: 'top-chatter-link', type: 'button', hidden: '' }, [createText('Reset')]),
            createHTMLElement('button', { id: 'top-chatters-more', class: 'top-chatter-link', type: 'button' }, [createText('mehr…')])
          ])
        ]),
        createHTMLElement('section', { id: 'page-info-section', 'aria-labelledby': 'page-info-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'page-info-heading' }, [createText('Seiteninformationen')]),
            createHTMLElement('div', { class: 'title-actions' }, [
              createHTMLElement('span', { id: 'page-info-source', class: 'live-indicator' }, [createText('Metadaten')]),
              createHTMLElement('button', { id: 'refresh-page-info', class: 'secondary compact' }, [createText('Refresh')]),
              createHTMLElement('button', { id: 'force-page-info', class: 'secondary compact danger-outline' }, [createText('Force')])
            ])
          ]),
          createHTMLElement('div', { id: 'profile-info', class: 'profile-info', hidden: '' }),
          createHTMLElement('div', { id: 'summary-info', class: 'summary-info' })
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'stats-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'stats-heading' }, [createText('LIVE-Informationen')]),
            createHTMLElement('span', { id: 'stats-live', class: 'live-indicator' }, [createText('warte')])
          ]),
          createHTMLElement('div', { id: 'live-stats', class: 'status-grid stats-grid' }),
          createHTMLElement('p', { id: 'stats-status', class: 'inline-status' })
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'hook-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'hook-heading' }, [createText('WebSocket-Hook')]),
            createHTMLElement('span', { id: 'hook-led', class: 'status-led off', role: 'status', 'aria-label': 'Hook inaktiv', title: 'Hook inaktiv' })
          ]),
          createHTMLElement('div', { class: 'button-row' }, [
            createHTMLElement('button', { id: 'enable-hook', class: 'primary' }, [createText('Hook setzen')]),
            createHTMLElement('button', { id: 'disable-hook', class: 'secondary' }, [createText('Hook deaktivieren')]),
            createHTMLElement('button', { id: 'reset-tab', class: 'secondary danger-outline' }, [createText('Refresh')]),
            createHTMLElement('button', { id: 'open-embed-live', class: 'secondary' }, [createText('Embed')]),
            createHTMLElement('button', { id: 'open-normal-live', class: 'secondary' }, [createText('Normal')]),
            createHTMLElement('button', { id: 'player-vlc-frame', class: 'secondary compact' }, [createText('VLC Ersatz')])
          ]),
          createHTMLElement('p', { id: 'hook-status', class: 'inline-status' }),
          createHTMLElement('label', { class: 'option-row' }, [
            createHTMLElement('input', { id: 'hook-autostart', type: 'checkbox' }),
            createText(' Permanent Hook')
          ]),
          createHTMLElement('label', { class: 'option-row' }, [
            createHTMLElement('input', { id: 'quick-recover', type: 'checkbox' }),
            createText(' Auto-Reconnect')
          ])
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'caption-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'caption-heading' }, [createText('Untertitel')]),
            createHTMLElement('button', { id: 'scan', class: 'secondary' }, [createText('Seite prüfen')])
          ]),
          createHTMLElement('div', { id: 'caption-status', class: 'status-grid' }),
          createHTMLElement('button', { id: 'enable-captions', class: 'primary' }, [createText('Untertitel aktivieren')]),
          createHTMLElement('p', { id: 'caption-action-status', role: 'status', class: 'inline-status action-status' })
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'player-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'player-heading' }, [createText('Playersteuerung')]),
            createHTMLElement('span', { id: 'player-time', class: 'player-time' }, [createText('–')])
          ]),
          createHTMLElement('div', { class: 'player-controls', role: 'group', 'aria-label': 'TikTok-Player steuern' }, [
            createHTMLElement('button', { id: 'player-play', class: 'secondary compact' }, [createText('Pause')]),
            createHTMLElement('button', { id: 'player-replay', class: 'secondary compact' }, [createText('Neu laden')]),
            createHTMLElement('button', { id: 'player-mute', class: 'secondary compact' }, [createText('Stumm')]),
            createHTMLElement('button', { id: 'player-pip', class: 'secondary compact' }, [createText('Bild-in-Bild')]),
            createHTMLElement('button', { id: 'player-fullscreen', class: 'secondary compact' }, [createText('Vollbild')]),
            createHTMLElement('button', { id: 'player-report', class: 'secondary compact danger-outline' }, [createText('Melden öffnen')])
          ]),
          createHTMLElement('div', { class: 'audio-controls' }, [
            createHTMLElement('div', { class: 'control-label' }, [
              createHTMLElement('label', { for: 'player-volume' }, [createText('Lautstärke')]),
              createHTMLElement('output', { id: 'player-volume-output', for: 'player-volume' }, [createText('–')])
            ]),
            createHTMLElement('input', { id: 'player-volume', type: 'range', min: '0', max: '100', step: '1', value: '100' }),
            createHTMLElement('div', { class: 'audio-meter-row' }, [
              createHTMLElement('span', {}, [createText('Spitzenpegel')]),
              createHTMLElement('strong', { id: 'player-peak' }, [createText('–')])
            ]),
            createHTMLElement('label', { class: 'option-row' }, [
              createHTMLElement('input', { id: 'limiter-enabled', type: 'checkbox' }),
              createText(' Pegelschutz aktivieren')
            ]),
            createHTMLElement('div', { class: 'control-label' }, [
              createHTMLElement('label', { for: 'limiter-strength' }, [createText('Schutzstärke')]),
              createHTMLElement('output', { id: 'limiter-strength-output', for: 'limiter-strength' }, [createText('30')])
            ]),
            createHTMLElement('input', { id: 'limiter-strength', type: 'range', min: '0', max: '100', step: '1', value: '30' })
          ]),
          createHTMLElement('p', { id: 'multi-guest-status', class: 'inline-status' }, [createText('Verbundene Streams: noch nicht erkannt.')]),
          createHTMLElement('p', { id: 'player-status', role: 'status', class: 'inline-status' }, [createText('Warte auf den TikTok-Player.')])
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'song-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'song-heading' }, [createText('Songerkennung')]),
            createHTMLElement('span', { id: 'song-led', class: 'status-led off', role: 'status', 'aria-label': 'Songerkennung inaktiv' })
          ]),
          createHTMLElement('label', { class: 'option-row' }, [
            createHTMLElement('input', { id: 'song-enabled', type: 'checkbox' }),
            createText(' Songerkennung aktivieren')
          ]),
          createHTMLElement('button', { id: 'recognize-song', class: 'primary', disabled: '' }, [createText('Jetzt erkennen')]),
          createHTMLElement('p', { id: 'song-status', class: 'inline-status' }),
          createHTMLElement('div', { id: 'song-result', class: 'song-result', hidden: '' })
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'links-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'links-heading' }, [createText('VLC-Links')]),
            createHTMLElement('span', { id: 'media-count', class: 'count' }, [createText('0')])
          ]),
          createHTMLElement('div', { id: 'media-list', class: 'list empty' }, [createText('Noch keine FLV-/HLS-Links erkannt.')])
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'log-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'log-heading' }, [createText('Caption-Protokoll')]),
            createHTMLElement('span', { id: 'caption-count', class: 'count' }, [createText('0')])
          ]),
          createHTMLElement('div', { class: 'button-row' }, [
            createHTMLElement('button', { id: 'export-log', class: 'secondary' }, [createText('JSONL exportieren')]),
            createHTMLElement('button', { id: 'clear', class: 'ghost' }, [createText('Anzeige leeren')])
          ]),
          createHTMLElement('div', { id: 'caption-list', class: 'list empty' }, [createText('Noch keine CaptionMessages empfangen.')])
        ]),
        createHTMLElement('section', { 'aria-labelledby': 'debug-heading' }, [
          createHTMLElement('div', { class: 'section-title' }, [
            createHTMLElement('h2', { id: 'debug-heading' }, [createText('Debugmodus')]),
            createHTMLElement('span', { id: 'debug-count', class: 'count' }, [createText('0')])
          ]),
          createHTMLElement('label', { class: 'option-row' }, [
            createHTMLElement('input', { id: 'debug-enabled', type: 'checkbox' }),
            createText(' Diagnoseereignisse für diesen Tab protokollieren')
          ]),
          createHTMLElement('div', { class: 'button-row' }, [
            createHTMLElement('button', { id: 'export-debug', class: 'secondary' }, [createText('Debug exportieren')]),
            createHTMLElement('button', { id: 'clear-debug', class: 'ghost' }, [createText('Debug leeren')])
          ]),
          createHTMLElement('p', { class: 'muted small' })
        ]),
        createHTMLElement('div', { id: 'audience-modal', class: 'modal-backdrop', hidden: '' }, [
          createHTMLElement('section', { class: 'modal', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'audience-heading' }, [
            createHTMLElement('div', { class: 'section-title' }, [
              createHTMLElement('h2', { id: 'audience-heading' }, [createText('Im Chat beobachtete Personen')]),
              createHTMLElement('button', { id: 'close-audience', class: 'secondary compact', 'aria-label': 'Übersicht schließen' }, [createText('Schließen')])
            ]),
            createHTMLElement('p', { id: 'audience-limit', class: 'inline-status' }),
            createHTMLElement('div', { id: 'audience-list', class: 'audience-list' })
          ])
        ]),
        createHTMLElement('div', { id: 'chat-history-modal', class: 'modal-backdrop', hidden: '' }, [
          createHTMLElement('section', { class: 'modal', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'chat-history-heading' }, [
            createHTMLElement('div', { class: 'section-title' }, [
              createHTMLElement('h2', { id: 'chat-history-heading' }, [createText('Gesammelte Chatzeilen')]),
              createHTMLElement('button', { id: 'close-chat-history', class: 'secondary compact', 'aria-label': 'Chatzeilen schließen' }, [createText('Schließen')])
            ]),
            createHTMLElement('p', { id: 'chat-history-limit', class: 'inline-status' }),
            createHTMLElement('div', { id: 'chat-history-list', class: 'chat-history-list' })
          ])
        ]),
        createHTMLElement('p', { id: 'notice', role: 'alert', class: 'notice' })
      ]),
      createHTMLElement('script', { src: 'content-core.js' }),
      createHTMLElement('script', { src: 'sidepanel.js' })
    ])
  ]);

  // Convert to HTML string
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
    
    const childStrings = children.map(renderElement);
    return `<${tag}${attrString}>${childStrings.join('')}</${tag}>`;
  }
  
  return doctype + renderElement(html);
}

// Main execution
if (process.argv.length < 3) {
  console.error('Usage: node sidepanel.js <output-file>');
  process.exit(1);
}

const outputFile = process.argv[2];
const htmlContent = generateHTML();

try {
  writeFileSync(outputFile, htmlContent, 'utf8');
  console.log(`HTML file generated successfully: ${outputFile}`);
} catch (error) {
  console.error('Error writing file:', error);
  process.exit(1);
}
