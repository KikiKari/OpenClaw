#!/usr/bin/env node
// sidepanel.html — portiert nach javascript
// Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/sidepanel.html
// Erzeugt: 2026-11-05 durch ABSTRACTIONS_MANAGER.py

import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

function createDocument() {
  const doc = {
    doctype: '<!doctype html>',
    html: {
      attrs: { lang: 'de' },
      head: {
        children: [
          { tag: 'meta', attrs: { charset: 'utf-8' } },
          { tag: 'meta', attrs: { name: 'viewport', content: 'width=device-width, initial-scale=1' } },
          { tag: 'title', text: 'TikTok LIVE Companion' },
          { tag: 'link', attrs: { rel: 'stylesheet', href: 'sidepanel.css' } },
          { tag: 'link', attrs: { rel: 'stylesheet', href: 'icon-controls.css' } },
          { tag: 'link', attrs: { rel: 'stylesheet', href: 'status-overview-panel.css' } }
        ]
      },
      body: {
        children: []
      }
    }
  };

  // Body content
  const body = doc.html.body;

  // Hidden page title
  body.children.push({ tag: 'p', attrs: { id: 'page-title', hidden: true } });

  // Main container
  const main = { tag: 'main', children: [] };
  body.children.push(main);

  // Chat section
  const chatSection = {
    tag: 'section',
    attrs: { 'aria-labelledby': 'chat-heading' },
    children: [
      {
        tag: 'div',
        attrs: { class: 'section-title' },
        children: [
          { tag: 'h2', attrs: { id: 'chat-heading' }, text: 'Chat' },
          {
            tag: 'div',
            attrs: { class: 'title-actions' },
            children: [
              { tag: 'span', attrs: { id: 'chat-led', class: 'status-led off', role: 'status', 'aria-label': 'Chat inaktiv', title: 'Chat inaktiv' } },
              { tag: 'button', attrs: { id: 'chat-count', class: 'count count-button', type: 'button', 'aria-haspopup': 'dialog', title: 'Gesammelte Chatzeilen öffnen' }, text: '0' },
              { tag: 'button', attrs: { id: 'refresh-chat', class: 'secondary compact', title: 'Chatanzeige leeren' }, text: 'Reset' },
              { tag: 'button', attrs: { id: 'toggle-speech', class: 'secondary compact', 'aria-pressed': 'false', 'aria-label': 'Vorlesen' }, text: 'On' },
              { tag: 'span', attrs: { id: 'speech-led', class: 'status-led off', role: 'status', 'aria-label': 'Vorlesen inaktiv', title: 'Vorlesen inaktiv' } }
            ]
          }
        ]
      },
      { tag: 'div', attrs: { id: 'chat-list', class: 'chat-list empty', role: 'log', 'aria-live': 'polite', 'aria-relevant': 'additions', 'aria-label': 'Die letzten fünf bereinigten Chatnachrichten' }, text: 'Noch keine Chatnachrichten erkannt.' },
      { tag: 'p', attrs: { id: 'speech-status', role: 'status', class: 'inline-status' }, text: 'Vorlesen ist ausgeschaltet.' },
      {
        tag: 'div',
        attrs: { class: 'control-label' },
        children: [
          { tag: 'label', attrs: { for: 'speech-volume' }, text: 'Vorleselautstärke' },
          { tag: 'output', attrs: { id: 'speech-volume-output', for: 'speech-volume' }, text: '100%' }
        ]
      },
      { tag: 'input', attrs: { id: 'speech-volume', type: 'range', min: '0', max: '100', step: '5', value: '50' } },
      {
        tag: 'div',
        attrs: { class: 'button-row' },
        children: [
          { tag: 'button', attrs: { id: 'service-action', class: 'secondary' }, text: 'Sprachdienst' },
          { tag: 'button', attrs: { id: 'sherpa-action', class: 'secondary' }, text: 'Sherpa' },
          { tag: 'button', attrs: { id: 'open-speech-settings', class: 'secondary compact settings-button', type: 'button', 'aria-label': 'Erweiterte Einstellungen öffnen', 'aria-haspopup': 'dialog', title: 'Einstellungen' } }
        ]
      },
      { tag: 'p', attrs: { id: 'service-status', class: 'inline-status' }, text: 'Lokaler Sprachdienst noch nicht geprüft.' },
      { tag: 'div', attrs: { id: 'service-setup', class: 'inline-status', hidden: true }, children: [
        { tag: 'button', attrs: { id: 'copy-service-setup', class: 'secondary compact' }, text: 'Installation abschließen!' }
      ]}
    ]
  };
  main.children.push(chatSection);

  // Stats section
  const statsSection = {
    tag: 'section',
    attrs: { 'aria-labelledby': 'stats-heading' },
    children: [
      {
        tag: 'div',
        attrs: { class: 'section-title' },
        children: [
          { tag: 'h2', attrs: { id: 'stats-heading' }, text: 'LIVE-Information' },
          { tag: 'span', attrs: { id: 'stats-live', class: 'live-indicator' }, text: 'warte' }
        ]
      },
      { tag: 'div', attrs: { id: 'live-stats', class: 'status-grid stats-grid' } },
      { tag: 'p', attrs: { id: 'stats-status', class: 'inline-status' } }
    ]
  };
  main.children.push(statsSection);

  // Page info section
  const pageInfoSection = {
    tag: 'section',
    attrs: { id: 'page-info-section', 'aria-labelledby': 'page-info-heading' },
    children: [
      {
        tag: 'div',
        attrs: { class: 'section-title' },
        children: [
          { tag: 'h2', attrs: { id: 'page-info-heading' }, text: 'PROFIL-Information' },
          {
            tag: 'div',
            attrs: { class: 'title-actions' },
            children: [
              { tag: 'span', attrs: { id: 'page-info-source', class: 'live-indicator' }, text: 'Metadaten' },
              { tag: 'button', attrs: { id: 'refresh-page-info', class: 'secondary compact', title: 'Refresh' }, text: 'Refresh' },
              { tag: 'button', attrs: { id: 'force-page-info', class: 'secondary compact danger-outline' }, text: 'Force' }
            ]
          }
        ]
      },
      { tag: 'div', attrs: { id: 'profile-info', class: 'profile-info', hidden: true } },
      { tag: 'div', attrs: { id: 'summary-info', class: 'summary-info' } }
    ]
  };
  main.children.push(pageInfoSection);

  // Hook section
  const hookSection = {
    tag: 'section',
    attrs: { 'aria-labelledby': 'hook-heading' },
    children: [
      {
        tag: 'div',
        attrs: { class: 'section-title header-controls' },
        children: [
          { tag: 'h2', attrs: { id: 'hook-heading' }, text: 'Connection' },
          {
            tag: 'div',
            attrs: { class: 'title-actions' },
            children: [
              { tag: 'button', attrs: { id: 'reset-tab', class: 'secondary compact danger-outline', title: 'Reset' }, text: 'Reset' },
              { tag: 'input', attrs: { id: 'hook-autostart', type: 'checkbox', 'aria-label': 'Hook dauerhaft', title: 'Hook dauerhaft: Off' } },
              { tag: 'span', attrs: { class: 'status-led off', 'data-switch-status': 'hook-autostart', role: 'status' } }
            ]
          }
        ]
      },
      {
        tag: 'div',
        attrs: { class: 'button-row' },
        children: [
          { tag: 'button', attrs: { id: 'toggle-hook', class: 'primary', 'aria-label': 'Connection', 'aria-pressed': 'false' }, text: 'On' },
          { tag: 'button', attrs: { id: 'open-connection-settings', class: 'secondary compact settings-button', type: 'button', 'aria-label': 'Connection-Einstellungen öffnen', 'aria-haspopup': 'dialog' } },
          { tag: 'button', attrs: { id: 'open-embed-live', class: 'secondary' }, text: 'Embed' },
          { tag: 'button', attrs: { id: 'open-normal-live', class: 'secondary' }, text: 'Browser' },
          { tag: 'button', attrs: { id: 'player-vlc-frame', class: 'secondary compact' }, text: 'Player' }
        ]
      },
      {
        tag: 'div',
        attrs: { class: 'connection-status' },
        children: [
          { tag: 'span', attrs: { id: 'hook-led', class: 'status-led off', role: 'status', 'aria-label': 'Hook inaktiv', title: 'Hook inaktiv' } },
          { tag: 'p', attrs: { id: 'hook-status', class: 'inline-status' } }
        ]
      },
      { tag: 'p', attrs: { id: 'embed-startup-status', class: 'inline-status', role: 'status', 'aria-live': 'polite', hidden: true } },
      { tag: 'button', attrs: { id: 'cancel-embed-startup', class: 'secondary', hidden: true }, text: 'Embed-Start abbrechen' },
      { tag: 'p', attrs: { id: 'hook-reconnect-status', class: 'inline-status', role: 'status' }, text: 'Hook-Reconnect: aus' },
      { tag: 'p', attrs: { id: 'player-recovery-status', class: 'inline-status', role: 'status' }, text: 'Player-Recovery: aus' }
    ]
  };
  main.children.push(hookSection);

  // Player section
  const playerSection = {
    tag: 'section',
    attrs: { 'aria-labelledby': 'player-heading' },
    children: [
      {
        tag: 'div',
        attrs: { class: 'section-title header-controls' },
        children: [
          { tag: 'h2', attrs: { id: 'player-heading' }, text: 'Player' },
          {
            tag: 'div',
            attrs: { class: 'title-actions' },
            children: [
              { tag: 'button', attrs: { id: 'player-replay', class: 'secondary compact', title: 'Neu laden' }, text: 'Neu laden' },
              { tag: 'input', attrs: { id: 'limiter-enabled', type: 'checkbox', 'aria-label': 'Pegelschutz', title: 'Pegelschutz: Off' } },
              { tag: 'span', attrs: { class: 'status-led off', 'data-switch-status': 'limiter-enabled', role: 'status' } }
            ]
          }
        ]
      },
      {
        tag: 'div',
        attrs: { class: 'player-controls', role: 'group', 'aria-label': 'TikTok-Player steuern' },
        children: [
          { tag: 'button', attrs: { id: 'player-play', class: 'secondary compact' }, text: 'Play' },
          { tag: 'button', attrs: { id: 'player-mute', class: 'secondary compact' }, text: 'Mute' },
          { tag: 'button', attrs: { id: 'player-pip', class: 'secondary compact' }, text: 'Bild-in-Bild' },
          { tag: 'button', attrs: { id: 'player-fullscreen', class: 'secondary compact' }, text: 'Vollbild' },
          { tag: 'button', attrs: { id: 'player-report', class: 'secondary compact danger-outline' }, text: 'Meldung' }
        ]
      },
      {
        tag: 'div',
        attrs: { class: 'audio-controls' },
        children: [
          {
            tag: 'div',
            attrs: { class: 'control-label' },
            children: [
              { tag: 'label', attrs: { for: 'player-volume' }, text: 'Lautstärke' },
              { tag: 'output', attrs: { id: 'player-volume-output', for: 'player-volume' }, text: '–' }
            ]
          },
          { tag: 'input', attrs: { id: 'player-volume', type: 'range', min: '0', max: '100', step: '1', value: '100' } },
          {
            tag: 'div',
            attrs: { class: 'audio-meter-row' },
            children: [
              { tag: 'span', text: 'Spitzenpegel' },
              { tag: 'strong', attrs: { id: 'player-peak' }, text: '–' }
            ]
          },
          {
            tag: 'div',
            attrs: { class: 'control-label' },
            children: [
              { tag: 'label', attrs: { for: 'limiter-strength' }, text: 'Schutzstärke' },
              { tag: 'output', attrs: { id: 'limiter-strength-output', for: 'limiter-strength' }, text: '30' }
            ]
          },
          { tag: 'input', attrs: { id: 'limiter-strength', type: 'range', min: '0', max: '100', step: '1', value: '30' } }
        ]
      },
      { tag: 'p', attrs: { id: 'multi-guest-status', class: 'inline-status' }, text: 'Verbundene Streams: noch nicht erkannt.' },
      { tag: 'p', attrs: { id: 'player-status', role: 'status', class: 'inline-status' }, text: 'Warte auf den TikTok-Player.' },
      { tag: 'span', attrs: { id: 'player-time', class: 'player-time', hidden: true }, text: '–' }
    ]
  };
  main.children.push(playerSection);

  // Top chatters section
  const topChattersSection = {
    tag: 'section',
    attrs: { 'aria-labelledby': 'top-chatters-heading' },
    children: [
      {
        tag: 'div',
        attrs: { class: 'section-title' },
        children: [
          { tag: 'h2', attrs: { id: 'top-chatters-heading' }, text: 'Top-Chatter' },
          { tag: 'button', attrs: { id: 'open-audience', class: 'secondary compact' }, text: 'Zuschauer*innen' }
        ]
      },
      { tag: 'p', attrs: { id: 'team-tag-status', class: 'inline-status' }, text: 'Teamkürzel: noch nicht erkannt.' },
      { tag: 'div', attrs: { id: 'top-chatters', class: 'top-chatters empty' }, text: 'Noch keine Personen im Chat beobachtet.' },
      {
        tag: 'div',
        attrs: { id: 'top-chatters-actions', class: 'top-chatters-actions', hidden: true },
        children: [
          { tag: 'button', attrs: { id: 'top-chatters-reset', class: 'top-chatter-link', type: 'button', hidden: true }, text: 'Reset' },
          { tag: 'button', attrs: { id: 'top-chatters-more', class: 'top-chatter-link', type: 'button' }, text: 'mehr…' }
        ]
      }
    ]
  };
  main.children.push(topChattersSection);

  // Recommendations section
  const recommendationsSection = {
    tag: 'section',
    attrs: { id: 'recommendations-section', 'aria-labelledby': 'recommendations-heading' },
    children: [
      {
        tag: 'div',
        attrs: { class: 'section-title' },
        children: [
          { tag: 'h2', attrs: { id: 'recommendations-heading' }, text: 'LIVE-Empfehlungen' },
          { tag: 'span', attrs: { id: 'recommendation-status', class: 'live-indicator' }, text: 'bereit' }
        ]
      },
      {
        tag: 'div',
        attrs: { class: 'recommendation-controls' },
        children: [
          {
            tag: 'label',
            children: [
              { tag: 'span', text: 'Anzahl' },
              { tag: 'input', attrs: { id: 'recommendation-limit', type: 'number', min: '1', max: '300', step: '1', value: '20', inputmode: 'numeric' } }
            ]
          },
          {
            tag: 'label',
            children: [
              { tag: 'span', text: 'Sortierung' },
              {
                tag: 'select',
                attrs: { id: 'recommendation-sort' },
                children: [
                  { tag: 'option', attrs: { value: 'tiktok' }, text: 'TikTok-Reihenfolge' },
                  { tag: 'option', attrs: { value: 'viewers' }, text: 'Zuschauer*innen' }
                ]
              }
            ]
          }
        ]
      },
      {
        tag: 'div',
        attrs: { class: 'button-row' },
        children: [
          { tag: 'button', attrs: { id: 'scan-recommendations', class: 'primary' }, text: 'Empfehlungen scannen' },
          { tag: 'button', attrs: { id: 'cancel-recommendations', class: 'secondary', hidden: true }, text: 'Abbrechen' }
        ]
      },
      { tag: 'p', attrs: { id: 'recommendation-progress', class: 'inline-status', 'aria-live': 'polite' }, text: 'Noch kein Scan gestartet.' },
      { tag: 'div', attrs: { id: 'recommendation-list', class: 'recommendation-list empty' }, text: 'Noch keine Empfehlungen erfasst.' },
      {
        tag: 'div',
        attrs: { id: 'recommendation-actions', class: 'top-chatters-actions', hidden: true },
        children: [
          { tag: 'button', attrs: { id: 'recommendation-more', class: 'top-chatter-link', type: 'button' }, text: 'mehr…' }
        ]
      }
    ]
  };
  main.children.push(recommendationsSection);

  // Overview section
  const overviewSection = {
    tag: 'section',
    attrs: { 'aria-labelledby': 'overview-heading' },
    children: [
      {
        tag: 'div',
        attrs: { class: 'section-title header-controls' },
        children: [
          { tag: 'h2', attrs: { id: 'overview-heading' }, text: 'STATUS-Monitor' },
          {
            tag: 'div',
            attrs: { class: 'title-actions' },
            children: [
              { tag: 'button', attrs: { id: 'overview-settings', class: 'secondary compact', type: 'button', 'aria-label': 'Monitor Einstellungen' }, text: 'Monitor Einstellungen' },
              { tag: 'button', attrs: { id: 'overview-reset', class: 'secondary compact', type: 'button', 'aria-label': 'Streamnamen leeren' }, text: 'Streamnamen leeren' },
              { tag: 'input', attrs: { id: 'overview-enabled', type: 'checkbox', 'aria-label': 'LIVE-Prüfung' } },
              { tag: 'span', attrs: { class: 'status-led off', 'data-switch-status': 'overview-enabled', role: 'status' } }
            ]
          }
        ]
      },
      { tag: 'div', attrs: { id: 'overview-rows' } },
      {
        tag: 'div',
        attrs: { class: 'button-row overview-actions' },
        children: [
          { tag: 'button', attrs: { id: 'overview-check', class: 'secondary', type: 'button', 'aria-label': 'Jetzt prüfen', title: 'Jetzt prüfen' } },
          { tag: 'button', attrs: { id: 'overview-copy', class: 'secondary' }, text: 'Alle kopieren' },
          { tag: 'button', attrs: { id: 'overview-open', class: 'primary' }, text: 'Overview' }
        ]
      },
      {
        tag: 'div',
        attrs: { class: 'top-chatters-actions' },
        children: [
          { tag: 'button', attrs: { id: 'overview-collapse', class: 'top-chatter-link', type: 'button', hidden: true }, text: 'Reset' },
          { tag: 'button', attrs: { id: 'overview-more', class: 'top-chatter-link', type: 'button' }, text: 'mehr…' }
        ]
      },
      { tag: 'p', attrs: { id: 'overview-message', class: 'overview-visually-hidden', role: 'status' } }
    ]
  };
  main.children.push(overviewSection);

  // Caption section
  const captionSection = {
    tag: 'section',
    attrs: { 'aria-labelledby': 'caption-heading' },
    children: [
      {
        tag: 'div',
        attrs: { class: 'section-title' },
        children: [
          { tag: 'h2', attrs: { id: 'caption-heading' }, text: 'Titel' },
          { tag: 'button', attrs: { id: 'scan', class: 'secondary' }, text: 'Status' }
        ]
      },
      { tag: 'div', attrs: { id: 'caption-status', class: 'status-grid' } },
      { tag: 'button', attrs: { id: 'enable-captions', class: 'primary' }, text: 'Untertitel' },
      { tag: 'p', attrs: { id: 'caption-action-status', role: 'status', class: 'inline-status action-status' } }
    ]
  };
  main.children.push(captionSection);

  // Song section
  const songSection = {
    tag: 'section',
    attrs: { 'aria-labelledby': 'song-heading' },
    children: [
      {
        tag: 'div',
        attrs: { class: 'section-title header-controls' },
        children: [
          { tag: 'h2', attrs: { id: 'song-heading' }, text: 'Songs' },
          {
            tag: 'div',
            attrs: { class: 'title-actions' },
            children: [
              { tag: 'input', attrs: { id: 'song-enabled', type: 'checkbox', 'aria-label': 'Songerkennung', title: 'Songerkennung: Off' } },
              { tag: 'span', attrs: { id: 'song-led', class: 'status-led off', 'data-switch-status': 'song-enabled', role: 'status', 'aria-label': 'Songerkennung inaktiv' } }
            ]
          }
        ]
      },
      { tag: 'button', attrs: { id: 'recognize-song', class: 'primary', disabled: true }, text: 'Jetzt erkennen' },
      { tag: 'p', attrs: { id: 'song-status', class: 'inline-status' } },
      { tag: 'div', attrs: { id: 'song-result', class: 'song-result', hidden: true } }
    ]
  };
  main.children.push(songSection);

  // Links section
  const linksSection = {
    tag: 'section',
    attrs: { 'aria-labelledby': 'links-heading' },
    children: [
      {
        tag: 'div',
        attrs: { class: 'section-title' },
        children: [
          { tag: 'h2', attrs: { id: 'links-heading' }, text: 'HAR-Logs' },
          { tag: 'span', attrs: { id: 'media-count', class: 'count' }, text: '0' }
        ]
      },
      { tag: 'div', attrs: { id: 'media-list', class: 'list empty' }, text: 'Noch keine FLV-/HLS-Links erkannt.' }
    ]
  };
  main.children.push(linksSection);

  // Log section
  const logSection = {
    tag: 'section',
    attrs: { 'aria-labelledby': 'log-heading' },
    children: [
      {
        tag: 'div',
        attrs: { class: 'section-title header-controls' },
        children: [
          { tag: 'h2', attrs: { id: 'log-heading' }, text: 'LIVE-Logs' },
          {
            tag: 'div',
            attrs: { class: 'title-actions' },
            children: [
              { tag: 'span', attrs: { class: 'status-led off', 'data-counter-status': 'caption-count', role: 'status' } },
              { tag: 'span', attrs: { id: 'caption-count', class: 'count' }, text: '0' },
              { tag: 'button', attrs: { id: 'clear', class: 'ghost compact', title: 'Reset' }, text: 'Reset' },
              { tag: 'input', attrs: { id: 'live-logs-enabled', type: 'checkbox', 'aria-label': 'LIVE-Logs', title: 'LIVE-Logs: Off' } },
              { tag: 'span', attrs: { class: 'status-led off', 'data-switch-status': 'live-logs-enabled', role: 'status', 'aria-label': 'LIVE-Logs: deaktiviert' } }
            ]
          }
        ]
      },
      {
        tag: 'div',
        attrs: { class: 'button-row' },
        children: [
          { tag: 'button', attrs: { id: 'export-log', class: 'secondary' }, text: 'JSON-L-Export' },
          { tag: 'button', attrs: { id: 'export-caption-raw', class: 'secondary' }, text: 'RAW-JSON-Export' }
        ]
      },
      { tag: 'div', attrs: { id: 'caption-list', class: 'list empty' }, text: 'Noch keine CaptionMessages empfangen.' }
    ]
  };
  main.children.push(logSection);

  // Debug section
  const debugSection = {
    tag: 'section',
    attrs: { 'aria-labelledby': 'debug-heading' },
    children: [
      {
        tag: 'div',
        attrs: { class: 'section-title header-controls' },
        children: [
          { tag: 'h2', attrs: { id: 'debug-heading' }, text: 'Debugmodus' },
          {
            tag: 'div',
            attrs: { class: 'title-actions' },
            children: [
              { tag: 'span', attrs: { class: 'status-led off', 'data-counter-status': 'debug-count', role: 'status' } },
              { tag: 'span', attrs: { id: 'debug-count', class: 'count' }, text: '0' },
              { tag: 'button', attrs: { id: 'clear-debug', class: 'ghost compact', title: 'Reset' }, text: 'Reset' },
              { tag: 'input', attrs: { id: 'debug-enabled', type: 'checkbox', 'aria-label': 'Diagnoseereignisse für diesen Tab protokollieren', title: 'Diagnoseereignisse für diesen Tab protokollieren: Off' } },
              { tag: 'span', attrs: { class: 'status-led off', 'data-switch-status': 'debug-enabled', role: 'status' } }
            ]
          }
        ]
      },
      {
        tag: 'div',
        attrs: { class: 'button-row' },
        children: [
          { tag: 'button', attrs: { id: 'export-debug', class: 'secondary' }, text: 'Debug exportieren' }
        ]
      },
      { tag: 'p', attrs: { class: 'muted small' } }
    ]
  };
  main.children.push(debugSection);

  // Audience modal
  const audienceModal = {
    tag: 'div',
    attrs: { id: 'audience-modal', class: 'modal-backdrop', hidden: true },
    children: [
      {
        tag: 'section',
        attrs: { class: 'modal', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'audience-heading' },
        children: [
          {
            tag: 'div',
            attrs: { class: 'section-title' },
            children: [
              { tag: 'h2', attrs: { id: 'audience-heading' }, text: 'Im Chat beobachtete Personen' },
              { tag: 'button', attrs: { id: 'close-audience', class: 'secondary compact', 'aria-label': 'Übersicht schließen' }, text: 'Schließen' }
            ]
          },
          { tag: 'p', attrs: { id: 'audience-limit', class: 'inline-status' } },
          { tag: 'div', attrs: { id: 'audience-list', class: 'audience-list' } }
        ]
      }
    ]
  };
  body.children.push(audienceModal);

  // Speech settings modal
  const speechSettingsModal = {
    tag: 'div',
    attrs: { id: 'speech-settings-modal', class: 'modal-backdrop', hidden: true },
    children: [
      {
        tag: 'section',
        attrs: { class: 'modal', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'speech-settings-heading' },
        children: [
          {
            tag: 'div',
            attrs: { class: 'section-title' },
            children: [
              { tag: 'h2', attrs: { id: 'speech-settings-heading' }, text: 'Erweiterte Einstellungen' },
              { tag: 'button', attrs: { id: 'close-speech-settings', class: 'secondary compact', 'aria-label': 'Einstellungen schließen' }, text: 'Schließen' }
            ]
          },
          {
            tag: 'div',
            attrs: { class: 'settings-grid speech-integration-settings' },
            children: [
              {
                tag: 'label',
                attrs: { class: 'icon-style-setting' },
                children: [
                  { tag: 'span', text: 'Icon-Stil' },
                  {
                    tag: 'select',
                    attrs: { id: 'icon-style' },
                    children: [
                      { tag: 'option', attrs: { value: 'plastisch' }, text: '3D / Plastisch' },
                      { tag: 'option', attrs: { value: 'glass' }, text: 'Glass / Realistisch' },
                      { tag: 'option', attrs: { value: 'linear' }, text: 'Minimal / Linear' }
                    ]
                  }
                ]
              },
              {
                tag: 'label',
                children: [
                  { tag: 'span', text: 'Sprache' },
                  {
                    tag: 'select',
                    attrs: { id: 'speech-language' },
                    children: [
                      { tag: 'option', attrs: { value: 'auto' }, text: 'Auto' },
                      { tag: 'option', attrs: { value: 'de-DE' }, text: 'Deutsch' },
                      { tag: 'option', attrs: { value: 'en-US' }, text: 'Englisch' },
                      { tag: 'option', attrs: { value: 'ru-RU' }, text: 'Russisch' },
                      { tag: 'option', attrs: { value: 'uk-UA' }, text: 'Ukrainisch' },
                      { tag: 'option', attrs: { value: 'bg-BG' }, text: 'Bulgarisch' },
                      { tag: 'option', attrs: { value: 'sr-RS' }, text: 'Serbisch' },
                      { tag: 'option', attrs: { value: 'kk-KZ' }, text: 'Kasachisch' },
                      { tag: 'option', attrs: { value: 'zh-CN' }, text: 'Chinesisch' },
                      { tag: 'option', attrs: { value: 'ja-JP' }, text: 'Japanisch' },
                      { tag: 'option', attrs: { value: 'ko-KR' }, text: 'Koreanisch' },
                      { tag: 'option', attrs: { value: 'ar-JO' }, text: 'Arabisch' },
                      { tag: 'option', attrs: { value: 'fa-IR' }, text: 'Persisch' },
                      { tag: 'option', attrs: { value: 'ur-PK' }, text: 'Urdu' },
                      { tag: 'option', attrs: { value: 'hi-IN' }, text: 'Hindi' },
                      { tag: 'option', attrs: { value: 'ne-NP' }, text: 'Nepali' },
                      { tag: 'option', attrs: { value: 'ml-IN' }, text: 'Malayalam' }
                    ]
                  }
                ]
              },
              {
                tag: 'label',
                children: [
                  { tag: 'span', text: 'Stimme' },
                  {
                    tag: 'select',
                    attrs: { id: 'speech-voice' },
                    children: [
                      { tag: 'option', attrs: { value: '' }, text: 'Standard' }
                    ]
                  }
                ]
              },
              {
                tag: 'label',
                attrs: { id: 'audd-token-setting' },
                children: [
                  { tag: 'span', attrs: { id: 'audd-token-label' }, text: 'AudD API-Token (optional - ' },
                  { tag: 'a', attrs: { href: 'https://audd.io/', target: '_blank', rel: 'noopener noreferrer' }, text: 'https://AudD.io' },
                  { tag: 'span', text: ' Trial/Paid)' },
                  { tag: 'input', attrs: { id: 'audd-token', type: 'password', autocomplete: 'off', spellcheck: false } }
                ]
              },
              {
                tag: 'label',
                attrs: { id: 'pairing-code-setting' },
                children: [
                  { tag: 'span', text: 'Pairing-Code' },
                  { tag: 'input', attrs: { id: 'pairing-code', type: 'password', autocomplete: 'off', spellcheck: false } }
                ]
              },
              {
                tag: 'label',
                children: [
                  { tag: 'span', text: 'Universal API-Key' },
                  { tag: 'input', attrs: { id: 'universal-caption-api-key', type: 'password', autocomplete: 'off', spellcheck: false } }
                ]
              }
            ]
          },
          { tag: 'label', attrs: { class: 'option-row' }, children: [
            { tag: 'input', attrs: { id: 'speak-names', type: 'checkbox', checked: true } },
            { tag: 'span', text: ' Chatnamen sprechen' }
          ]},
          { tag: 'label', attrs: { class: 'option-row' }, children: [
            { tag: 'input', attrs: { id: 'shorten-names', type: 'checkbox' } },
            { tag: 'span', text: ' Chatnamen kürzen' }
          ]},
          {
