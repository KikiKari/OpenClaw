#!/usr/bin/env node
// sidepanel.css — portiert nach javascript
// Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/sidepanel.css
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/sidepanel.css
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/sidepanel.css
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/sidepanel.css
// Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');

function generateCSS() {
  const cssRules = [];

  // Root variables
  cssRules.push({
    selector: ':root',
    declarations: {
      'color-scheme': 'light dark',
      'font-family': 'Inter, "Segoe UI", system-ui, sans-serif',
      '--accent': '#fe2c55',
      '--accent-dark': '#d91f46',
      '--surface': 'color-mix(in srgb, Canvas 94%, CanvasText 6%)',
      '--border': 'color-mix(in srgb, CanvasText 18%, transparent)',
      '--muted': 'color-mix(in srgb, CanvasText 65%, transparent)',
      '--good': '#147d45',
      '--warn': '#a65f00',
      '--bad': '#b42318'
    }
  });

  // Universal selector
  cssRules.push({
    selector: '*',
    declarations: {
      'box-sizing': 'border-box'
    }
  });

  // Body
  cssRules.push({
    selector: 'body',
    declarations: {
      'margin': '0',
      'background': 'Canvas',
      'color': 'CanvasText',
      'min-width': '300px'
    }
  });

  // Header
  cssRules.push({
    selector: 'header',
    declarations: {
      'padding': '11px 18px',
      'background': 'linear-gradient(135deg, color-mix(in srgb, var(--accent) 18%, Canvas), Canvas)',
      'border-bottom': '1px solid var(--border)'
    }
  });

  // Headings
  cssRules.push({
    selector: 'h2',
    declarations: {
      'margin': '0',
      'font-size': '15px'
    }
  });

  // Main content
  cssRules.push({
    selector: 'main',
    declarations: {
      'padding': '14px',
      'display': 'grid',
      'grid-template-columns': 'minmax(0, 1fr)',
      'gap': '12px'
    }
  });

  // Sections
  cssRules.push({
    selector: 'section',
    declarations: {
      'min-width': '0',
      'padding': '14px',
      'background': 'var(--surface)',
      'border': '1px solid var(--border)',
      'border-radius': '13px',
      'box-shadow': '0 5px 20px color-mix(in srgb, CanvasText 6%, transparent)'
    }
  });

  // Section titles and button rows
  cssRules.push({
    selector: '.section-title, .button-row',
    declarations: {
      'display': 'flex',
      'align-items': 'center',
      'justify-content': 'space-between',
      'gap': '8px'
    }
  });

  cssRules.push({
    selector: '.section-title',
    declarations: {
      'min-width': '0',
      'flex-wrap': 'wrap'
    }
  });

  cssRules.push({
    selector: '.title-actions',
    declarations: {
      'display': 'flex',
      'min-width': '0',
      'max-width': '100%',
      'align-items': 'center',
      'justify-content': 'flex-end',
      'flex-wrap': 'wrap',
      'gap': '6px'
    }
  });

  // Status LED
  cssRules.push({
    selector: '.status-led',
    declarations: {
      'width': '11px',
      'height': '11px',
      'flex': '0 0 11px',
      'border-radius': '50%',
      'background': 'var(--bad)',
      'box-shadow': '0 0 0 3px color-mix(in srgb, var(--bad) 15%, transparent)'
    }
  });

  cssRules.push({
    selector: '.status-led.on',
    declarations: {
      'background': 'var(--good)',
      'box-shadow': '0 0 0 3px color-mix(in srgb, var(--good) 17%, transparent)'
    }
  });

  cssRules.push({
    selector: '.status-led.off',
    declarations: {
      'background': 'var(--bad)'
    }
  });

  // Button row
  cssRules.push({
    selector: '.button-row',
    declarations: {
      'justify-content': 'flex-start',
      'flex-wrap': 'wrap',
      'margin-top': '10px'
    }
  });

  // Buttons
  cssRules.push({
    selector: 'button',
    declarations: {
      'border': '0',
      'border-radius': '9px',
      'padding': '9px 11px',
      'font': 'inherit',
      'font-size': '12px',
      'font-weight': '700',
      'cursor': 'pointer'
    }
  });

  cssRules.push({
    selector: 'button:disabled',
    declarations: {
      'cursor': 'not-allowed',
      'opacity': '.55'
    }
  });

  cssRules.push({
    selector: '.compact',
    declarations: {
      'padding': '7px 9px'
    }
  });

  cssRules.push({
    selector: '.settings-button',
    declarations: {
      'min-width': '34px',
      'font-size': '17px',
      'line-height': '1'
    }
  });

  cssRules.push({
    selector: '.primary',
    declarations: {
      'color': 'white',
      'background': 'var(--accent)'
    }
  });

  cssRules.push({
    selector: '.primary:hover',
    declarations: {
      'background': 'var(--accent-dark)'
    }
  });

  cssRules.push({
    selector: '.secondary',
    declarations: {
      'color': 'CanvasText',
      'background': 'color-mix(in srgb, CanvasText 9%, Canvas)',
      'border': '1px solid var(--border)'
    }
  });

  cssRules.push({
    selector: '.ghost',
    declarations: {
      'color': 'var(--muted)',
      'background': 'transparent'
    }
  });

  cssRules.push({
    selector: '.danger-outline',
    declarations: {
      'color': 'var(--bad)',
      'border-color': 'color-mix(in srgb, var(--bad) 45%, transparent)'
    }
  });

  // Enable captions button
  cssRules.push({
    selector: '#enable-captions',
    declarations: {
      'width': '100%',
      'margin-top': '11px'
    }
  });

  // Text styles
  cssRules.push({
    selector: '.muted',
    declarations: {
      'color': 'var(--muted)'
    }
  });

  cssRules.push({
    selector: '.small',
    declarations: {
      'font-size': '12px',
      'line-height': '1.45'
    }
  });

  cssRules.push({
    selector: '#page-title',
    declarations: {
      'margin': '0',
      'font-size': '12px',
      'white-space': 'nowrap',
      'overflow': 'hidden',
      'text-overflow': 'ellipsis'
    }
  });

  // Status grid
  cssRules.push({
    selector: '.status-grid',
    declarations: {
      'display': 'grid',
      'grid-template-columns': '1fr 1fr',
      'gap': '7px',
      'margin-top': '11px'
    }
  });

  cssRules.push({
    selector: '.status',
    declarations: {
      'padding': '9px',
      'border': '1px solid var(--border)',
      'border-radius': '9px',
      'background': 'Canvas'
    }
  });

  cssRules.push({
    selector: '.status-label',
    declarations: {
      'display': 'block',
      'color': 'var(--muted)',
      'font-size': '10px',
      'text-transform': 'uppercase',
      'letter-spacing': '.06em'
    }
  });

  cssRules.push({
    selector: '.status-value',
    declarations: {
      'display': 'block',
      'margin-top': '3px',
      'font-size': '12px',
      'font-weight': '750'
    }
  });

  cssRules.push({
    selector: '.good .status-value',
    declarations: {
      'color': 'var(--good)'
    }
  });

  cssRules.push({
    selector: '.warn .status-value',
    declarations: {
      'color': 'var(--warn)'
    }
  });

  cssRules.push({
    selector: '.bad .status-value',
    declarations: {
      'color': 'var(--bad)'
    }
  });

  // Count elements
  cssRules.push({
    selector: '.count',
    declarations: {
      'min-width': '25px',
      'padding': '3px 7px',
      'border-radius': '999px',
      'background': 'color-mix(in srgb, var(--accent) 15%, Canvas)',
      'color': 'var(--accent)',
      'text-align': 'center',
      'font-size': '11px',
      'font-weight': '800'
    }
  });

  cssRules.push({
    selector: '.count-button',
    declarations: {
      'border': '1px solid color-mix(in srgb, var(--accent) 30%, transparent)',
      'cursor': 'pointer'
    }
  });

  cssRules.push({
    selector: '.count-button:hover, .count-button:focus-visible',
    declarations: {
      'background': 'color-mix(in srgb, var(--accent) 25%, Canvas)'
    }
  });

  // Live indicator
  cssRules.push({
    selector: '.live-indicator',
    declarations: {
      'padding': '3px 7px',
      'border-radius': '999px',
      'background': 'color-mix(in srgb, var(--muted) 15%, Canvas)',
      'color': 'var(--muted)',
      'font-size': '10px',
      'font-weight': '800',
      'text-transform': 'uppercase'
    }
  });

  cssRules.push({
    selector: '.live-indicator.active',
    declarations: {
      'background': 'color-mix(in srgb, var(--good) 16%, Canvas)',
      'color': 'var(--good)'
    }
  });

  // Stats grid
  cssRules.push({
    selector: '.stats-grid .status-value',
    declarations: {
      'font-size': '16px',
      'font-variant-numeric': 'tabular-nums'
    }
  });

  // Chat list
  cssRules.push({
    selector: '.chat-list',
    declarations: {
      'display': 'grid',
      'gap': '6px',
      'margin-top': '11px'
    }
  });

  cssRules.push({
    selector: '.chat-list.empty',
    declarations: {
      'color': 'var(--muted)',
      'font-size': '12px'
    }
  });

  cssRules.push({
    selector: '.chat-line',
    declarations: {
      'margin': '0',
      'padding': '7px 8px',
      'border-left': '3px solid color-mix(in srgb, var(--accent) 45%, var(--border))',
      'border-radius': '6px',
      'background': 'Canvas',
      'font-size': '12px',
      'line-height': '1.4',
      'overflow-wrap': 'anywhere'
    }
  });

  cssRules.push({
    selector: '.chat-author',
    declarations: {
      'font-weight': '800'
    }
  });

  // Player controls
  cssRules.push({
    selector: '.player-controls',
    declarations: {
      'display': 'grid',
      'grid-template-columns': 'repeat(2, minmax(0, 1fr))',
      'gap': '7px',
      'margin-top': '11px'
    }
  });

  cssRules.push({
    selector: '.player-controls button',
    declarations: {
      'width': '100%'
    }
  });

  cssRules.push({
    selector: '.player-time',
    declarations: {
      'font-size': '13px',
      'font-weight': '800',
      'font-variant-numeric': 'tabular-nums'
    }
  });

  // Audio controls
  cssRules.push({
    selector: '.audio-controls',
    declarations: {
      'display': 'grid',
      'gap': '7px',
      'margin-top': '12px',
      'padding-top': '11px',
      'border-top': '1px solid var(--border)'
    }
  });

  // Control labels
  cssRules.push({
    selector: '.control-label, .audio-meter-row',
    declarations: {
      'display': 'flex',
      'align-items': 'center',
      'justify-content': 'space-between',
      'gap': '8px',
      'font-size': '11px'
    }
  });

  cssRules.push({
    selector: '.control-label output, .audio-meter-row strong',
    declarations: {
      'font-variant-numeric': 'tabular-nums'
    }
  });

  // Range inputs
  cssRules.push({
    selector: 'input[type="range"]',
    declarations: {
      'width': '100%',
      'accent-color': 'var(--accent)'
    }
  });

  // Settings grid
  cssRules.push({
    selector: '.settings-grid',
    declarations: {
      'display': 'grid',
      'gap': '7px',
      'margin-top': '10px'
    }
  });

  cssRules.push({
    selector: '.settings-grid label',
    declarations: {
      'display': 'grid',
      'gap': '4px',
      'color': 'var(--muted)',
      'font-size': '10px'
    }
  });

  cssRules.push({
    selector: '.settings-grid label[hidden]',
    declarations: {
      'display': 'none'
    }
  });

  // Form inputs
  cssRules.push({
    selector: 'input[type="url"], input[type="text"], input[type="password"], input[type="number"], select',
    declarations: {
      'width': '100%',
      'min-width': '0',
      'padding': '7px 8px',
      'border': '1px solid var(--border)',
      'border-radius': '7px',
      'background': 'Canvas',
      'color': 'CanvasText',
      'font': 'inherit',
      'font-size': '11px'
    }
  });

  // Top chatters
  cssRules.push({
    selector: '.top-chatters',
    declarations: {
      'display': 'grid',
      'gap': '6px',
      'margin-top': '8px'
    }
  });

  cssRules.push({
    selector: '.top-chatters.empty',
    declarations: {
      'color': 'var(--muted)',
      'font-size': '12px'
    }
  });

  cssRules.push({
    selector: '.top-chatters-actions',
    declarations: {
      'display': 'flex',
      'justify-content': 'flex-end',
      'gap': '9px',
      'margin-top': '7px'
    }
  });

  cssRules.push({
    selector: '.top-chatters-actions[hidden]',
    declarations: {
      'display': 'none'
    }
  });

  // Top chatter link
  cssRules.push({
    selector: '.top-chatter-link',
    declarations: {
      'padding': '0',
      'color': 'var(--accent)',
      'background': 'transparent',
      'border': '0',
      'border-radius': '0',
      'font-weight': '700'
    }
  });

  cssRules.push({
    selector: '.top-chatter-link:hover',
    declarations: {
      'text-decoration': 'underline'
    }
  });

  // Chatter row
  cssRules.push({
    selector: '.chatter-row',
    declarations: {
      'display': 'grid',
      'grid-template-columns': 'minmax(0, 1fr) auto auto',
      'align-items': 'center',
      'gap': '7px',
      'padding': '7px 8px',
      'border': '1px solid var(--border)',
      'border-radius': '8px',
      'background': 'Canvas'
    }
  });

  cssRules.push({
    selector: '.chatter-name',
    declarations: {
      'min-width': '0',
      'overflow': 'hidden',
      'text-overflow': 'ellipsis',
      'white-space': 'nowrap',
      'font-size': '11px',
      'font-weight': '800'
    }
  });

  cssRules.push({
    selector: '.chatter-metrics',
    declarations: {
      'color': 'var(--muted)',
      'font-size': '10px',
      'white-space': 'nowrap'
    }
  });

  // Mute toggle
  cssRules.push({
    selector: '.mute-toggle',
    declarations: {
      'display': 'flex',
      'align-items': 'center',
      'gap': '4px',
      'color': 'var(--muted)',
      'font-size': '10px'
    }
  });

  // Recognize song
  cssRules.push({
    selector: '#recognize-song',
    declarations: {
      'width': '100%',
      'margin-top': '10px'
    }
  });

  cssRules.push({
    selector: '.song-result',
    declarations: {
      'margin-top': '9px',
      'padding': '9px',
      'border': '1px solid var(--border)',
      'border-radius': '9px',
      'background': 'Canvas',
      'font-size': '11px',
      'line-height': '1.45'
    }
  });

  cssRules.push({
    selector: '.song-result strong, .song-result span, .song-result a',
    declarations: {
      'display': 'block'
    }
  });

  cssRules.push({
    selector: '.song-result a',
    declarations: {
      'margin-top': '4px',
      'color': 'var(--accent)',
      'overflow-wrap': 'anywhere'
    }
  });

  // Modal backdrop
  cssRules.push({
    selector: '.modal-backdrop',
    declarations: {
      'position': 'fixed',
      'inset': '0',
      'z-index': '100',
      'padding': '14px',
      'background': 'color-mix(in srgb, CanvasText 42%, transparent)',
      'overflow': 'auto'
    }
  });

  cssRules.push({
    selector: '.modal',
    declarations: {
      'width': 'min(520px, 100%)',
      'max-height': 'calc(100vh - 28px)',
      'margin': '0 auto',
      'overflow': 'auto',
      'background': 'Canvas'
    }
  });

  // Audience list
  cssRules.push({
    selector: '.audience-list, .chat-history-list, .recommendation-list',
    declarations: {
      'display': 'grid',
      'gap': '7px',
      'margin-top': '9px'
    }
  });

  cssRules.push({
    selector: '.chat-history-row',
    declarations: {
      'padding': '8px 9px',
      'border': '1px solid var(--border)',
      'border-radius': '9px',
      'background': 'var(--surface)',
      'font-size': '11px',
      'line-height': '1.4',
      'overflow-wrap': 'anywhere'
    }
  });

  cssRules.push({
    selector: '.chat-history-meta',
    declarations: {
      'display': 'block',
      'margin-bottom': '3px',
      'color': 'var(--muted)',
      'font-size': '10px'
    }
  });

  // Audience row
  cssRules.push({
    selector: '.audience-row',
    declarations: {
      'display': 'grid',
      'gap': '6px',
      'padding': '9px',
      'border': '1px solid var(--border)',
      'border-radius': '9px',
      'background': 'var(--surface)'
    }
  });

  cssRules.push({
    selector: '.audience-row-head',
    declarations: {
      'display': 'flex',
      'align-items': 'center',
      'justify-content': 'space-between',
      'gap': '8px'
    }
  });

  cssRules.push({
    selector: '.audience-row select',
    declarations: {
      'width': 'auto',
      'max-width': '170px'
    }
  });

  cssRules.push({
    selector: '.audience-metrics',
    declarations: {
      'color': 'var(--muted)',
      'font-size': '10px',
      'line-height': '1.45'
    }
  });

  // Option row
  cssRules.push({
    selector: '.option-row',
    declarations: {
      'display': 'flex',
      'align-items': 'flex-start',
      'gap': '7px',
      'margin-top': '8px',
      'color': 'var(--muted)',
      'font-size': '11px',
      'line-height': '1.35'
    }
  });

  cssRules.push({
    selector: '.option-row input',
    declarations: {
      'margin': '1px 0 0',
      'accent-color': 'var(--accent)'
    }
  });

  // Auto chat refresh
  cssRules.push({
    selector: '.auto-chat-refresh',
    declarations: {
      'align-items': 'center'
    }
  });

  // External speech trigger row
  cssRules.push({
    selector: '.external-speech-trigger-row',
    declarations: {
      'align-items': 'center'
    }
  });

  cssRules.push({
    selector: '.external-speech-trigger-row label',
    declarations: {
      'display': 'flex',
      'align-items': 'center',
      'gap': '7px'
    }
  });

  cssRules.push({
    selector: '.external-speech-trigger-row input[type="text"]',
    declarations: {
      'width': '48px',
      'margin-left': '3px',
      'padding': '3px 4px',
      'border': '1px solid var(--border)',
      'border-radius': '6px',
      'background': 'Canvas',
      'color': 'CanvasText',
      'font': 'inherit',
      'font-size': '11px'
    }
  });

  cssRules.push({
    selector: '.auto-chat-refresh input[type="number"]',
    declarations: {
      'width': '48px',
      'margin-left': '3px',
      'padding': '3px 4px',
      'border': '1px solid var(--border)',
      'border-radius': '6px',
      'background': 'Canvas',
      'color': 'CanvasText',
      'font': 'inherit',
      'font-size': '11px'
    }
  });

  cssRules.push({
    selector: '.quick-recover-setting input[type="number"]',
    declarations: {
      'width': '48px',
      'margin-left': '3px',
      'padding': '3px 4px',
      'border': '1px solid var(--border)',
      'border-radius': '6px',
      'background': 'Canvas',
      'color': 'CanvasText',
      'font': 'inherit',
      'font-size': '11px'
    }
  });

  // Audio note
  cssRules.push({
    selector: '.audio-note',
    declarations: {
      'margin': '1px 0 0'
    }
  });

  // Profile info
  cssRules.push({
    selector: '.profile-info',
    declarations: {
      'display': 'grid',
      'gap': '8px',
      'margin-top': '11px'
    }
  });

  cssRules.push({
    selector: '.profile-heading',
    declarations: {
      'margin': '0',
      'font-size': '14px',
      'font-weight': '800'
    }
  });

  cssRules.push({
    selector: '.profile-handle, .profile-bio',
    declarations: {
      'margin': '0',
      'color': 'var(--muted)',
      'font-size': '11px',
      'line-height': '1.45',
      'white-space': 'pre-wrap'
    }
  });

  // Profile stats
  cssRules.push({
    selector: '.profile-stats',
    declarations: {
      'display': 'grid',
      'grid-template-columns': 'repeat(3, minmax(0, 1fr))',
      'gap': '6px'
    }
  });

  cssRules.push({
    selector: '.profile-stat',
    declarations: {
      'padding': '7px',
      'border': '1px solid var(--border)',
      'border-radius': '8px',
      'background': 'Canvas'
    }
  });

  cssRules.push({
    selector: '.profile-stat strong, .profile-stat span',
    declarations: {
      'display': 'block'
    }
  });

  cssRules.push({
    selector: '.profile-stat span',
    declarations: {
      'margin-top': '2px',
      'color': 'var(--muted)',
      'font-size': '9px',
      'text-transform': 'uppercase'
    }
  });

  // Summary info
  cssRules.push({
    selector: '.summary-info',
    declarations: {
      'margin-top': '10px',
      'padding-top': '9px',
      'border-top': '1px solid var(--border)',
      'font-size': '11px',
      'line-height': '1.45'
    }
  });

  cssRules.push({
    selector: '.summary-text',
    declarations: {
      'margin': '6px 0 0',
      'white-space': 'pre-wrap'
    }
  });

  // Recommendation controls
  cssRules.push({
    selector: '.recommendation-controls',
    declarations: {
      'display': 'grid',
      'grid-template-columns': 'minmax(70px, .7fr) minmax(150px, 1.3fr)',
      'gap': '8px',
      'margin-top': '10px'
    }
  });

  cssRules.push({
    selector: '.recommendation-controls label',
    declarations: {
      'display': 'grid',
      'gap': '4px',
      'color': 'var(--muted)',
      'font-size': '10px'
    }
  });

  cssRules.push({
    selector: '.recommendation-list.empty',
    declarations: {
      'display': 'block',
      'color': 'var(--muted)',
      'font-size': '12px'
    }
  });

  cssRules.push({
    selector: '.recommendation-row',
    declarations: {
      'padding': '9px',
      'border': '1px solid var(--border)',
      'border-radius': '9px',
      'background': 'Canvas'
    }
  });

  cssRules.push({
    selector: '.recommendation-head',
    declarations: {
      'display': 'flex',
      'align-items': 'flex-start',
      'justify-content': 'space-between',
      'gap': '8px'
    }
  });

  cssRules.push({
    selector: '.recommendation-name',
    declarations: {
      'min-width': '0',
      'margin': '0',
      'font-size': '11px',
      'font-weight': '800',
      'overflow-wrap': 'anywhere'
    }
  });

  cssRules.push({
    selector: '.recommendation-viewers',
    declarations: {
      'flex': '0 0 auto',
      'color': 'var(--muted)',
      'font-size': '10px',
      'font-variant-numeric': 'tabular-nums'
    }
  });

  cssRules.push({
    selector: '.recommendation-description',
    declarations: {
      'margin': '5px 0 0',
      'color': 'var(--muted)',
      'font-size': '10px',
      'line-height': '1.4',
      'overflow-wrap': 'anywhere'
    }
  });

  cssRules.push({
    selector: '.recommendation-link',
    declarations: {
      'display': 'inline-block',
      'margin-top': '6px',
      'color': 'var(--accent)',
      'font-size': '11px',
      'font-weight': '700'
    }
  });

  // List
  cssRules.push({
    selector: '.list',
    declarations: {
      'display': 'grid',
      'gap': '8px',
      'margin-top': '11px',
      'max-height': '300px',
      'overflow': 'auto'
    }
  });

  cssRules.push({
    selector: '.list.empty',
    declarations: {
      'display': 'block',
      'color': 'var(--muted)',
      'font-size': '12px'
    }
  });

  cssRules.push({
    selector: '.item',
    declarations: {
      'padding': '10px',
      'border': '1px solid var(--border)',
      'border-radius': '9px',
      'background': 'Canvas'
    }
  });

  cssRules.push({
    selector: '.item-head',
    declarations: {
      'display': 'flex',
      'align-items': 'center',
      'justify-content': 'space-between',
      'gap': '8px'
    }
  });

  cssRules.push({
    selector: '.item-title',
    declarations: {
      'font-size': '12px',
      'font-weight': '800'
    }
  });

  cssRules.push({
    selector: '.item-meta, .item-url, .caption-meta',
    declarations: {
      'color': 'var(--muted)',
      'font-size': '10px'
    }
  });

  cssRules.push({
    selector: '.item-url',
    declarations: {
      'margin-top': '6px',
      'overflow-wrap': 'anywhere',
      'max-height': '42px',
      'overflow': 'hidden'
    }
  });

  cssRules.push({
    selector: '.copy',
    declarations: {
      'flex': '0 0 auto',
      'padding': '6px 8px'
    }
  });

  cssRules.push({
    selector: '.caption-text',
    declarations: {
      'margin': '5px 0 0',
      'white-space': 'pre-wrap',
      'font-size': '12px',
      'line-height': '1.4'
    }
  });

  // Inline status and notice
  cssRules.push({
    selector: '.inline-status, .notice',
    declarations: {
      'min-height': '17px',
      'margin': '9px 0 0',
      'color': 'var(--muted)',
      'font-size': '11px'
    }
  });

  cssRules.push({
    selector: '.action-status',
    declarations: {
      'line-height': '1.4'
    }
  });

  cssRules.push({
    selector: '.reset-note',
    declarations: {
      'margin': '7px 0 0'
    }
  });

  cssRules.push({
    selector: '.notice',
    declarations: {
      'margin': '0 3px 8px',
      'color': 'var(--bad)'
    }
  });

  // Media queries
  cssRules.push({
    selector: '@media (min-width: 430px)',
    declarations: {},
    nested: [
      {
        selector: '.speech-settings',
        declarations: {
          'grid-template-columns': '1fr 1fr'
        }
      },
      {
        selector: '.speech-settings label:first-child',
        declarations: {
          'grid-column': '1 / -1'
        }
      }
    ]
  });

  cssRules.push({
    selector: '@media (prefers-reduced-motion: reduce)',
    declarations: {},
    nested: [
      {
        selector: '*',
        declarations: {
          'scroll-behavior': 'auto !important'
        }
      }
    ]
  });

  // Additional header controls
  cssRules.push({
    selector: '.section-title.header-controls',
    declarations: {
      'flex-wrap': 'nowrap',
      'align-items': 'flex-start'
    }
  });

  cssRules.push({
    selector: '.header-controls > .title-actions',
    declarations: {
      'margin-inline-start': 'auto',
      'flex-wrap': 'nowrap',
      'flex-shrink': '0'
    }
  });

  cssRules.push({
    selector: '.header-controls > .title-actions input[type="checkbox"]',
    declarations: {
      'margin': '0'
    }
  });

  cssRules.push({
    selector: '.connection-status',
    declarations: {
      'display': 'flex',
      'align-items': 'center',
      'gap': '8px'
    }
  });

  return cssRules;
}

function formatCSS(cssRules) {
  let cssString = '';

  cssRules.forEach(rule => {
    if (rule.selector.startsWith('@media')) {
      cssString += `${rule.selector} {\n`;
      rule.nested.forEach(nestedRule => {
        cssString += `  ${nestedRule.selector} {`;
        const decls = Object.entries(nestedRule.declarations)
          .map(([prop, value]) => `\n    ${prop}: ${value};`)
          .join('');
        cssString += decls + '\n  }\n';
      });
      cssString += '}\n\n';
    } else {
      cssString += `${rule.selector} {`;
      const decls = Object.entries(rule.declarations)
        .map(([prop, value]) => `\n  ${prop}: ${value};`)
        .join('');
      cssString += decls + '\n}\n\n';
    }
  });

  return cssString;
}

function main() {
  const args = process.argv.slice(2);
  
  if (args.length !== 1) {
    console.error('Usage: node sidepanel.js <output-file>');
    process.exit(1);
  }
  
  const outputFile = args[0];
  const cssRules = generateCSS();
  const cssContent = formatCSS(cssRules);
  
  try {
    fs.writeFileSync(outputFile, cssContent, 'utf8');
    console.log(`CSS file generated successfully: ${outputFile}`);
  } catch (error) {
    console.error(`Error writing to file: ${error.message}`);
    process.exit(1);
  }
}

main();
