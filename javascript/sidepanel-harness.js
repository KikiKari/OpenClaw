#!/usr/bin/env node
// sidepanel-harness.html — portiert nach javascript
// Quelle: html, Projects@TikTok-Live-Companion:plugin-source/tests/sidepanel-harness.html
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/tests/sidepanel-harness.html
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/tests/sidepanel-harness.html
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/tests/sidepanel-harness.html
// Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Create the HTML document structure
function createDocument() {
  return {
    doctype: '<!doctype html>',
    html: {
      attributes: { lang: 'de' },
      head: {
        children: [
          { tag: 'meta', attributes: { charset: 'utf-8' } },
          { tag: 'meta', attributes: { name: 'viewport', content: 'width=device-width, initial-scale=1' } },
          { tag: 'title', content: 'Sidepanel Test Harness' }
        ]
      },
      body: {
        children: []
      }
    }
  };
}

// Create label and select elements
function createSelect(labelText, selectId, options) {
  return {
    tag: 'label',
    content: labelText,
    children: [
      {
        tag: 'select',
        attributes: { id: selectId },
        children: options.map(option => ({
          tag: 'option',
          attributes: { value: option.value },
          content: option.text
        }))
      }
    ]
  };
}

// Generate the complete HTML content
function generateHTML(doc) {
  let html = doc.doctype + '\n';
  html += `<html lang="${doc.html.attributes.lang}">\n`;
  html += '<head>\n';
  for (const child of doc.html.head.children) {
    if (child.tag === 'meta') {
      html += `  <meta charset="${child.attributes.charset}">\n`;
    } else if (child.tag === 'title') {
      html += `  <title>${child.content}</title>\n`;
    }
  }
  html += '</head>\n';
  html += '<body>\n';
  
  // Add the select elements
  for (const child of doc.html.body.children) {
    if (child.tag === 'label') {
      html += `  <label>${child.content}\n`;
      html += `    <select id="${child.children[0].attributes.id}">\n`;
      for (const option of child.children[0].children) {
        html += `      <option value="${option.attributes.value}">${option.content}</option>\n`;
      }
      html += '    </select>\n';
      html += '  </label>\n';
    }
  }
  
  // Add the script content
  html += '  <script>\n';
  html += '    (async () => {\n';
  html += '      const state = {\n';
  html += '        page: { url: "https://www.tiktok.com/@demo/live", title: "Demo LIVE", scannedAtUtc: new Date().toISOString() },\n';
  html += '        captionInfo: { present: true, open: true, supportLang: ["de", "en"], location: null, showType: 1 },\n';
  html += '        menuCaptionAvailable: true,\n';
  html += '        menuCaptionActive: false,\n';
  html += '        quickRecoverEnabled: false,\n';
  html += '        quickRecoverSeconds: 3,\n';
  html += '        profileInfo: {\n';
  html += '          present: true, nickname: "Demo Creator", uniqueId: "demo", signature: "Barrierefreier Teststream",\n';
  html += '          followingCount: "12", followerCount: "238800", likeCount: "1800000", live: true, source: "metadata"\n';
  html += '        },\n';
  html += '        aiSummaryInfo: { featureFlagPresent: true, featureEnabled: true, text: "", source: null, overviewCardFound: true, overviewCardHovered: true },\n';
  html += '        hook: { armed: true, installed: true, connected: true, lastError: null },\n';
  html += '        stream: { key: "demo|123", handle: "demo", roomId: "123", teamTag: "tmm", teamEvidence: {} },\n';
  html += '        liveStats: {\n';
  html += '          viewerCount: "143", totalViewers: "15842", likeCount: "430200",\n';
  html += '          followEvents: 7, shareEvents: 4, shareCount: "19", followerCount: "238800",\n';
  html += '          lastUpdatedUtc: new Date().toISOString(), recentEventIds: []\n';
  html += '        },\n';
  html += '        playerState: {\n';
  html += '          available: true, playing: true, muted: false, elapsedText: "1:17:42", pipActive: false, fullscreenActive: false,\n';
  html += '          volume: 0.72, volumePercent: 72, volumeGainDb: -2.9, peakDbfs: -8.4,\n';
  html += '          limiterEnabled: true, limiterThresholdDbfs: -6, limiterReductionDb: -1.2, limiterMode: "Kompressor",\n';
  html += '          connectedStreams: 4, multiGuest: true, updatedAtUtc: new Date().toISOString()\n';
  html += '        },\n';
  html += '        selectedQuality: "540p",\n';
  html += '        chatMessages: [\n';
  html += '          { messageId: "1", participantKey: "id:1", author: "Anna", content: "Guten Abend", contentLanguage: "de-DE", source: "websocket", receivedAtUtc: new Date().toISOString() },\n';
  html += '          { messageId: "2", participantKey: "id:2", author: "Ben", content: "Welche Sorte ist das?", contentLanguage: "de-DE", source: "dom", receivedAtUtc: new Date().toISOString() },\n';
  html += '          { messageId: "3", author: "Clara", content: "Danke für die Erklärung", contentLanguage: "de-DE", source: "websocket", receivedAtUtc: new Date().toISOString() },\n';
  html += '          { messageId: "4", author: "David", content: "Bitte einmal mischen", contentLanguage: "de-DE", source: "websocket", receivedAtUtc: new Date().toISOString() },\n';
  html += '          { messageId: "5", author: "Eva", content: "Das ist gut lesbar", contentLanguage: "de-DE", source: "websocket", receivedAtUtc: new Date().toISOString() }\n';
  html += '        ],\n';
  html += '        participants: {\n';
  html += '          "id:1": { key: "id:1", name: "Anna", messageCount: 12, wordCount: 48, giftEventCount: 2, giftItemCount: 24, lastSeenAtUtc: new Date().toISOString() },\n';
  html += '          "id:2": { key: "id:2", name: "Ben", messageCount: 8, wordCount: 39, giftEventCount: 0, giftItemCount: 0, lastSeenAtUtc: new Date().toISOString() },\n';
  html += '          "name:clara": { key: "name:clara", name: "Clara", messageCount: 6, wordCount: 31, giftEventCount: 1, giftItemCount: 1, lastSeenAtUtc: new Date().toISOString() }\n';
  html += '        },\n';
  html += '        streamMutes: [],\n';
  html += '        participantsTruncated: false,\n';
  html += '        media: [\n';
  html += '          { url: "https://pull.example.tiktokcdn.com/live/stream_hd.flv?expire=1&sign=test", protocol: "FLV", quality: "720p", sdkKey: "hd", bitrate: 1800000, codec: "h264", width: 1280, height: 720, fps: 30, audioOnly: false, hostname: "pull.example.tiktokcdn.com", source: "metadata" },\n';
  html += '          { url: "https://pull.example.tiktokcdn-eu.com/live/stream_720p.m3u8?sign=test", protocol: "HLS", quality: "720p", sdkKey: "hd", bitrate: 1800000, codec: "h264", width: 1280, height: 720, fps: 30, audioOnly: false, hostname: "pull.example.tiktokcdn-eu.com", source: "network" },\n';
  html += '          { url: "https://pull.example.tiktokcdn.com/live/stream_sd.flv?expire=1&sign=test", protocol: "FLV", quality: "540p", sdkKey: "sd", bitrate: 900000, codec: "h264", width: 960, height: 540, fps: 30, audioOnly: false, hostname: "pull.example.tiktokcdn.com", source: "metadata" }\n';
  html += '        ],\n';
  html += '        captions: [\n';
  html += '          { receivedAtUtc: new Date().toISOString(), sentenceId: "42", definite: true, contents: [{ lang: "de", text: "Dies ist eine Test-Caption." }] }\n';
  html += '        ],\n';
  html += '        debug: { enabled: false, entries: [{ atUtc: new Date().toISOString(), event: "scan", detail: { mediaCount: 3 } }] }\n';
  html += '      };\n\n';
  html += '      const stateListeners = [];\n';
  html += '      globalThis.chrome = {\n';
  html += '        tabs: {\n';
  html += '          query: async () => [{ id: 1, url: state.page.url, title: state.page.title }],\n';
  html += '          onActivated: { addListener() {} }\n';
  html += '        },\n';
  html += '        tabCapture: { capture(_options, callback) { callback(null); } },\n';
  html += '        runtime: {\n';
  html += '          sendMessage: async (message) => {\n';
  html += '            if (message.type === "TLC_GET_STATE") return { ok: true, state };\n';
  html += '            if (message.type === "TLC_OPEN_EMBED_LIVE") {\n';
  html += '              state.embedStartup = TLC_CONTENT_CORE.newEmbedSession(crypto.randomUUID(), "demo", Date.now());\n';
  html += '              return { ok: true, response: { activated: false, phase: "loading" } };\n';
  html += '            }\n';
  html += '            if (message.type === "TLC_CANCEL_EMBED_STARTUP" || message.type === "TLC_OPEN_NORMAL_LIVE") {\n';
  html += '              if (state.embedStartup) state.embedStartup = { ...state.embedStartup, phase: "cancelled", nextAttemptAtMs: null };\n';
  html += '              return { ok: true };\n';
  html += '            }\n';
  html += '            if (message.type === "TLC_GET_SETTINGS") return { ok: true, settings: { autoHook: true, keepSpeechActive: true, speechVolume: 0.5, speechLanguage: "auto", speakNames: true, shortenNames: false, serviceUrl: "http://127.0.0.1:43117", pairingCode: "", permanentMutes: [], quickRecoverEnabled: state.quickRecoverEnabled, quickRecoverSeconds: state.quickRecoverSeconds } };\n';
  html += '            if (message.type === "TLC_SET_QUICK_RECOVER") {\n';
  html += '              state.quickRecoverEnabled = Boolean(message.enabled);\n';
  html += '              state.quickRecoverSeconds = Math.max(1, Math.min(59, Math.round(Number(message.seconds) || 3)));\n';
  html += '              return { ok: true, state, seconds: state.quickRecoverSeconds };\n';
  html += '            }\n';
  html += '            if (message.type === "TLC_GET_CAPTION_JSONL_EXPORT") return { ok: true, records: TLC_EXPORT_PRIVACY.captions(state.captions) };\n';
  html += '            if (message.type === "TLC_GET_CAPTION_RAW_EXPORT") return { ok: true, report: TLC_EXPORT_PRIVACY.captionReport({\n';
  html += '              version: "0.8.2", generatedAtUtc: new Date().toISOString(), messages: state.captions,\n';
  html += '              dataStreams: state.media, data: { captionInfo: state.captionInfo, captionSources: state.captionSources, playerState: state.playerState }, stream: { page: state.page }\n';
  html += '            }) };\n';
  html += '            if (message.type === "TLC_SCAN") {\n';
  html += '              return { ok: true, response: { captionInfo: state.captionInfo, captionControl: true, mediaCount: state.media.length } };\n';
  html += '            }\n';
  html += '            if (message.type === "TLC_GET_PLAYER_STATE") return { ok: true, response: { playerState: state.playerState } };\n';
  html += '            if (message.type === "TLC_PLAYER_ACTION") {\n';
  html += '              if (message.action === "toggle-play") state.playerState.playing = !state.playerState.playing;\n';
  html += '              if (message.action === "toggle-mute") state.playerState.muted = !state.playerState.muted;\n';
  html += '              if (message.action === "set-volume") {\n';
  html += '                state.playerState.volume = Number(message.value);\n';
  html += '                state.playerState.volumePercent = Math.round(Number(message.value) * 100);\n';
  html += '                state.playerState.volumeGainDb = Number(message.value) > 0 ? 20 * Math.log10(Number(message.value)) : null;\n';
  html += '              }\n';
  html += '              if (message.action === "set-limiter") {\n';
  html += '                state.playerState.limiterEnabled = Boolean(message.enabled);\n';
  html += '                state.playerState.limiterThresholdDbfs = Number(message.thresholdDbfs);\n';
  html += '              }\n';
  html += '              return { ok: true, response: { activated: true, playerState: state.playerState } };\n';
  html += '            }\n';
  html += '            if (message.type === "TLC_CLEAR_CHAT") {\n';
  html += '              state.chatMessages = [];\n';
  html += '              return { ok: true };\n';
  html += '            }\n';
  html += '            if (message.type === "TLC_SET_DEBUG") {\n';
  html += '              state.debug.enabled = Boolean(message.enabled);\n';
  html += '              return { ok: true, state };\n';
  html += '            }\n';
  html += '            if (message.type === "TLC_CLEAR_DEBUG") {\n';
  html += '              state.debug.entries = [];\n';
  html += '              return { ok: true };\n';
  html += '            }\n';
  html += '            if (message.type === "TLC_SET_MUTE") return { ok: true, state, settings: { permanentMutes: [] } };\n';
  html += '            if (message.type === "TLC_GET_DEBUG_REPORT") return { ok: true, report: TLC_EXPORT_PRIVACY.diagnosticReport({ version: "0.8.2", debug: state.debug, page: state.page, media: state.media }) };\n';
  html += '            return { ok: true, response: { activated: true } };\n';
  html += '          },\n';
  html += '          onMessage: { addListener(listener) { stateListeners.push(listener); } }\n';
  html += '        }\n';
  html += '      };\n\n';
  html += '      const assetVersion = Date.now();\n';
  html += '      const source = await fetch("../browser-extension/sidepanel.html", { cache: "no-store" }).then((response) => response.text());\n';
  html += '      const parsed = new DOMParser().parseFromString(source, "text/html");\n';
  html += '      document.title = parsed.title;\n';
  html += '      for (const child of [...parsed.body.children]) {\n';
  html += '        if (child.tagName !== "SCRIPT") document.body.append(document.importNode(child, true));\n';
  html += '      }\n';
  html += '      const css = document.createElement("link");\n';
  html += '      css.rel = "stylesheet";\n';
  html += '      css.href = "../browser-extension/sidepanel.css?v=0.7.0-1";\n';
  html += '      document.head.append(css);\n';
  html += '      const coreScript = document.createElement("script");\n';
  html += '      coreScript.src = `../browser-extension/content-core.js?v=${assetVersion}`;\n';
  html += '      coreScript.onload = () => {\n';
  html += '        document.getElementById("test-embed-scenario").addEventListener("change", (event) => {\n';
  html += '          state.embedStartup = {\n';
  html += '            ...TLC_CONTENT_CORE.newEmbedSession(crypto.randomUUID(), "demo", Date.now()),\n';
  html += '            phase: event.target.value, reason: "server-error", attempt: event.target.value === "failed" ? 3 : 1\n';
  html += '          };\n';
  html += '          stateListeners.forEach((listener) => listener({ type: "TLC_STATE_UPDATED", tabId: 1, state }));\n';
  html += '        });\n';
  html += '        document.getElementById("test-caption-scenario").addEventListener("change", (event) => {\n';
  html += '          const mode = event.target.value;\n';
  html += '          const observedAt = Date.now() - (mode === "historical" ? 60_000 : 0);\n';
  html += '          state.captions = mode === "none" ? [] : ["DomCaption", "WebcastCaptionMessage"].map((method) => ({\n';
  html += '            method, source: method === "DomCaption" ? "dom" : "websocket", receivedAtUtc: new Date(observedAt).toISOString(),\n';
  html += '            contents: [{ lang: "de", text: "Dies ist eine Test-Caption." }]\n';
  html += '          }));\n';
  html += '          state.captionSources = TLC_CONTENT_CORE.captionSourceSnapshot();\n';
  html += '          if (mode === "metadata") state.captionSources.metadata = { present: true, open: true, supportLang: ["de"] };\n';
  html += '          else for (const caption of state.captions) state.captionSources = TLC_CONTENT_CORE.observeCaptionSource(state.captionSources, caption, observedAt);\n';
  html += '          state.captionInfo = TLC_CONTENT_CORE.summarizeCaptionSources(state.captionSources);\n';
  html += '          stateListeners.forEach((listener) => listener({ type: "TLC_STATE_UPDATED", tabId: 1, state }));\n';
  html += '        });\n';
  html += '        const privacyScript = document.createElement("script");\n';
  html += '        privacyScript.src = `../browser-extension/export-privacy.js?v=${assetVersion}`;\n';
  html += '        privacyScript.onload = () => {\n';
  html += '          const script = document.createElement("script");\n';
  html += '          script.src = `../browser-extension/sidepanel.js?v=${assetVersion}`;\n';
  html += '          document.body.append(script);\n';
  html += '        };\n';
  html += '        document.body.append(privacyScript);\n';
  html += '      };\n';
  html += '      document.body.append(coreScript);\n';
  html += '    })();\n';
  html += '  </script>\n';
  html += '</body>\n';
  html += '</html>\n';
  
  return html;
}

// Main function to generate and write the HTML file
async function main() {
  const outputFile = process.argv[2];
  
  if (!outputFile) {
    console.error('Usage: node script.js <output-file>');
    process.exit(1);
  }
  
  // Create the document structure
  const doc = createDocument();
  
  // Add the caption test scenario select
  doc.html.body.children.push(
    createSelect(
      'Caption-Testzustand',
      'test-caption-scenario',
      [
        { value: 'metadata', text: 'Seitenmetadaten' },
        { value: 'mixed', text: 'DOM und WebSocket aktuell' },
        { value: 'historical', text: 'Nur historische Captions' },
        { value: 'none', text: 'Keine Captions' }
      ]
    )
  );
  
  // Add the embed test scenario select
  doc.html.body.children.push(
    createSelect(
      'Embed-Testzustand',
      'test-embed-scenario',
      [
        { value: 'loading', text: 'Startet' },
        { value: 'retry-wait', text: 'Serverfehler – Wiederanlauf' },
        { value: 'awaiting-gesture', text: 'Benutzeraktion nötig' },
        { value: 'playing', text: 'Wiedergabe bestätigt' },
        { value: 'failed', text: 'Versuche ausgeschöpft' }
      ]
    )
  );
  
  // Generate the HTML content
  const htmlContent = generateHTML(doc);
  
  // Write to file
  try {
    await fs.writeFile(outputFile, htmlContent, 'utf8');
    console.log(`HTML file generated successfully: ${outputFile}`);
  } catch (error) {
    console.error('Error writing file:', error);
    process.exit(1);
  }
}

main();
