#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "8392a617ee5061321f9f798fff0df6cfe5693e6832cc6ffe3a311add9d58e64c", "source_sha256": "5cdd2168705597f720695d3eeea066c9b5361e819b3b2e47c23269290dddc1dd", "target_language": "lua"}
-- sidepanel-harness.html — portiert nach lua
-- Quelle: html, Projects@TikTok-Live-Companion:plugin-source/tests/sidepanel-harness.html
-- auch in: Projects@TikTok-Live-Companion-Android:plugin-source/tests/sidepanel-harness.html
-- auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/tests/sidepanel-harness.html
-- auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/tests/sidepanel-harness.html
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local json = require("cjson")

-- Hilfsfunktion zur Erstellung von ISO-Datumstrings
local function isoDate()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

-- Zustandsobjekt erstellen
local state = {
    page = { url = "https://www.tiktok.com/@demo/live", title = "Demo LIVE", scannedAtUtc = isoDate() },
    captionInfo = { present = true, open = true, supportLang = {"de", "en"}, location = nil, showType = 1 },
    menuCaptionAvailable = true,
    menuCaptionActive = false,
    quickRecoverEnabled = false,
    quickRecoverSeconds = 3,
    profileInfo = {
        present = true, nickname = "Demo Creator", uniqueId = "demo", signature = "Barrierefreier Teststream",
        followingCount = "12", followerCount = "238800", likeCount = "1800000", live = true, source = "metadata"
    },
    aiSummaryInfo = { featureFlagPresent = true, featureEnabled = true, text = "", source = nil, overviewCardFound = true, overviewCardHovered = true },
    hook = { armed = true, installed = true, connected = true, lastError = nil },
    stream = { key = "demo|123", handle = "demo", roomId = "123", teamTag = "tmm", teamEvidence = {} },
    liveStats = {
        viewerCount = "143", totalViewers = "15842", likeCount = "430200",
        followEvents = 7, shareEvents = 4, shareCount = "19", followerCount = "238800",
        lastUpdatedUtc = isoDate(), recentEventIds = {}
    },
    playerState = {
        available = true, playing = true, muted = false, elapsedText = "1:17:42", pipActive = false, fullscreenActive = false,
        volume = 0.72, volumePercent = 72, volumeGainDb = -2.9, peakDbfs = -8.4,
        limiterEnabled = true, limiterThresholdDbfs = -6, limiterReductionDb = -1.2, limiterMode = "Kompressor",
        connectedStreams = 4, multiGuest = true, updatedAtUtc = isoDate()
    },
    selectedQuality = "540p",
    chatMessages = {
        { messageId = "1", participantKey = "id:1", author = "Anna", content = "Guten Abend", contentLanguage = "de-DE", source = "websocket", receivedAtUtc = isoDate() },
        { messageId = "2", participantKey = "id:2", author = "Ben", content = "Welche Sorte ist das?", contentLanguage = "de-DE", source = "dom", receivedAtUtc = isoDate() },
        { messageId = "3", author = "Clara", content = "Danke für die Erklärung", contentLanguage = "de-DE", source = "websocket", receivedAtUtc = isoDate() },
        { messageId = "4", author = "David", content = "Bitte einmal mischen", contentLanguage = "de-DE", source = "websocket", receivedAtUtc = isoDate() },
        { messageId = "5", author = "Eva", content = "Das ist gut lesbar", contentLanguage = "de-DE", source = "websocket", receivedAtUtc = isoDate() }
    },
    participants = {
        ["id:1"] = { key = "id:1", name = "Anna", messageCount = 12, wordCount = 48, giftEventCount = 2, giftItemCount = 24, lastSeenAtUtc = isoDate() },
        ["id:2"] = { key = "id:2", name = "Ben", messageCount = 8, wordCount = 39, giftEventCount = 0, giftItemCount = 0, lastSeenAtUtc = isoDate() },
        ["name:clara"] = { key = "name:clara", name = "Clara", messageCount = 6, wordCount = 31, giftEventCount = 1, giftItemCount = 1, lastSeenAtUtc = isoDate() }
    },
    streamMutes = {},
    participantsTruncated = false,
    media = {
        { url = "https://pull.example.tiktokcdn.com/live/stream_hd.flv?expire=1&sign=test", protocol = "FLV", quality = "720p", sdkKey = "hd", bitrate = 1800000, codec = "h264", width = 1280, height = 720, fps = 30, audioOnly = false, hostname = "pull.example.tiktokcdn.com", source = "metadata" },
        { url = "https://pull.example.tiktokcdn-eu.com/live/stream_720p.m3u8?sign=test", protocol = "HLS", quality = "720p", sdkKey = "hd", bitrate = 1800000, codec = "h264", width = 1280, height = 720, fps = 30, audioOnly = false, hostname = "pull.example.tiktokcdn-eu.com", source = "network" },
        { url = "https://pull.example.tiktokcdn.com/live/stream_sd.flv?expire=1&sign=test", protocol = "FLV", quality = "540p", sdkKey = "sd", bitrate = 900000, codec = "h264", width = 960, height = 540, fps = 30, audioOnly = false, hostname = "pull.example.tiktokcdn.com", source = "metadata" }
    },
    captions = {
        { receivedAtUtc = isoDate(), sentenceId = "42", definite = true, contents = {{ lang = "de", text = "Dies ist eine Test-Caption." }} }
    },
    debug = { enabled = false, entries = {{ atUtc = isoDate(), event = "scan", detail = { mediaCount = 3 } }} }
}

-- HTML generieren
local function generateHTML()
    local html = {}
    
    table.insert(html, '<!doctype html>')
    table.insert(html, '<html lang="de">')
    table.insert(html, '<head>')
    table.insert(html, '  <meta charset="utf-8">')
    table.insert(html, '  <meta name="viewport" content="width=device-width, initial-scale=1">')
    table.insert(html, '  <title>Sidepanel Test Harness</title>')
    table.insert(html, '</head>')
    table.insert(html, '<body>')
    table.insert(html, '  <label>Caption-Testzustand')
    table.insert(html, '    <select id="test-caption-scenario">')
    table.insert(html, '      <option value="metadata">Seitenmetadaten</option>')
    table.insert(html, '      <option value="mixed">DOM und WebSocket aktuell</option>')
    table.insert(html, '      <option value="historical">Nur historische Captions</option>')
    table.insert(html, '      <option value="none">Keine Captions</option>')
    table.insert(html, '    </select>')
    table.insert(html, '  </label>')
    table.insert(html, '  <label>Embed-Testzustand')
    table.insert(html, '    <select id="test-embed-scenario">')
    table.insert(html, '      <option value="loading">Startet</option>')
    table.insert(html, '      <option value="retry-wait">Serverfehler – Wiederanlauf</option>')
    table.insert(html, '      <option value="awaiting-gesture">Benutzeraktion nötig</option>')
    table.insert(html, '      <option value="playing">Wiedergabe bestätigt</option>')
    table.insert(html, '      <option value="failed">Versuche ausgeschöpft</option>')
    table.insert(html, '    </select>')
    table.insert(html, '  </label>')
    table.insert(html, '  <script>')
    table.insert(html, '    (async () => {')
    table.insert(html, '      const state = ' .. json.encode(state) .. ';')
    table.insert(html, '')
    table.insert(html, '      const stateListeners = [];')
    table.insert(html, '      globalThis.chrome = {')
    table.insert(html, '        tabs: {')
    table.insert(html, '          query: async () => [{ id: 1, url: state.page.url, title: state.page.title }],')
    table.insert(html, '          onActivated: { addListener() {} }')
    table.insert(html, '        },')
    table.insert(html, '        tabCapture: { capture(_options, callback) { callback(null); } },')
    table.insert(html, '        runtime: {')
    table.insert(html, '          sendMessage: async (message) => {')
    table.insert(html, '            if (message.type === "TLC_GET_STATE") return { ok: true, state };')
    table.insert(html, '            if (message.type === "TLC_OPEN_EMBED_LIVE") {')
    table.insert(html, '              state.embedStartup = TLC_CONTENT_CORE.newEmbedSession(crypto.randomUUID(), "demo", Date.now());')
    table.insert(html, '              return { ok: true, response: { activated: false, phase: "loading" } };')
    table.insert(html, '            }')
    table.insert(html, '            if (message.type === "TLC_CANCEL_EMBED_STARTUP" || message.type === "TLC_OPEN_NORMAL_LIVE") {')
    table.insert(html, '              if (state.embedStartup) state.embedStartup = { ...state.embedStartup, phase: "cancelled", nextAttemptAtMs: null };')
    table.insert(html, '              return { ok: true };')
    table.insert(html, '            }')
    table.insert(html, '            if (message.type === "TLC_GET_SETTINGS") return { ok: true, settings: { autoHook: true, keepSpeechActive: true, speechVolume: 0.5, speechLanguage: "auto", speakNames: true, shortenNames: false, serviceUrl: "http://127.0.0.1:43117", pairingCode: "", permanentMutes: [], quickRecoverEnabled: state.quickRecoverEnabled, quickRecoverSeconds: state.quickRecoverSeconds } };')
    table.insert(html, '            if (message.type === "TLC_SET_QUICK_RECOVER") {')
    table.insert(html, '              state.quickRecoverEnabled = Boolean(message.enabled);')
    table.insert(html, '              state.quickRecoverSeconds = Math.max(1, Math.min(59, Math.round(Number(message.seconds) || 3)));')
    table.insert(html, '              return { ok: true, state, seconds: state.quickRecoverSeconds };')
    table.insert(html, '            }')
    table.insert(html, '            if (message.type === "TLC_GET_CAPTION_JSONL_EXPORT") return { ok: true, records: TLC_EXPORT_PRIVACY.captions(state.captions) };')
    table.insert(html, '            if (message.type === "TLC_GET_CAPTION_RAW_EXPORT") return { ok: true, report: TLC_EXPORT_PRIVACY.captionReport({')
    table.insert(html, '              version: "0.8.2", generatedAtUtc: new Date().toISOString(), messages: state.captions,')
    table.insert(html, '              dataStreams: state.media, data: { captionInfo: state.captionInfo, captionSources: state.captionSources, playerState: state.playerState }, stream: { page: state.page }')
    table.insert(html, '            }) };')
    table.insert(html, '            if (message.type === "TLC_SCAN") {')
    table.insert(html, '              return { ok: true, response: { captionInfo: state.captionInfo, captionControl: true, mediaCount: state.media.length } };')
    table.insert(html, '            }')
    table.insert(html, '            if (message.type === "TLC_GET_PLAYER_STATE") return { ok: true, response: { playerState: state.playerState } };')
    table.insert(html, '            if (message.type === "TLC_PLAYER_ACTION") {')
    table.insert(html, '              if (message.action === "toggle-play") state.playerState.playing = !state.playerState.playing;')
    table.insert(html, '              if (message.action === "toggle-mute") state.playerState.muted = !state.playerState.muted;')
    table.insert(html, '              if (message.action === "set-volume") {')
    table.insert(html, '                state.playerState.volume = Number(message.value);')
    table.insert(html, '                state.playerState.volumePercent = Math.round(Number(message.value) * 100);')
    table.insert(html, '                state.playerState.volumeGainDb = Number(message.value) > 0 ? 20 * Math.log10(Number(message.value)) : null;')
    table.insert(html, '              }')
    table.insert(html, '              if (message.action === "set-limiter") {')
    table.insert(html, '                state.playerState.limiterEnabled = Boolean(message.enabled);')
    table.insert(html, '                state.playerState.limiterThresholdDbfs = Number(message.thresholdDbfs);')
    table.insert(html, '              }')
    table.insert(html, '              return { ok: true, response: { activated: true, playerState: state.playerState } };')
    table.insert(html, '            }')
    table.insert(html, '            if (message.type === "TLC_CLEAR_CHAT") {')
    table.insert(html, '              state.chatMessages = [];')
    table.insert(html, '              return { ok: true };')
    table.insert(html, '            }')
    table.insert(html, '            if (message.type === "TLC_SET_DEBUG") {')
    table.insert(html, '              state.debug.enabled = Boolean(message.enabled);')
    table.insert(html, '              return { ok: true, state };')
    table.insert(html, '            }')
    table.insert(html, '            if (message.type === "TLC_CLEAR_DEBUG") {')
    table.insert(html, '              state.debug.entries = [];')
    table.insert(html, '              return { ok: true };')
    table.insert(html, '            }')
    table.insert(html, '            if (message.type === "TLC_SET_MUTE") return { ok: true, state, settings: { permanentMutes: [] } };')
    table.insert(html, '            if (message.type === "TLC_GET_DEBUG_REPORT") return { ok: true, report: TLC_EXPORT_PRIVACY.diagnosticReport({ version: "0.8.2", debug: state.debug, page: state.page, media: state.media }) };')
    table.insert(html, '            return { ok: true, response: { activated: true } };')
    table.insert(html, '          },')
    table.insert(html, '          onMessage: { addListener(listener) { stateListeners.push(listener); } }')
    table.insert(html, '        }')
    table.insert(html, '      };')
    table.insert(html, '')
    table.insert(html, '      const assetVersion = Date.now();')
    table.insert(html, '      const source = await fetch("../browser-extension/sidepanel.html", { cache: "no-store" }).then((response) => response.text());')
    table.insert(html, '      const parsed = new DOMParser().parseFromString(source, "text/html");')
    table.insert(html, '      document.title = parsed.title;')
    table.insert(html, '      for (const child of [...parsed.body.children]) {')
    table.insert(html, '        if (child.tagName !== "SCRIPT") document.body.append(document.importNode(child, true));')
    table.insert(html, '      }')
    table.insert(html, '      const css = document.createElement("link");')
    table.insert(html, '      css.rel = "stylesheet";')
    table.insert(html, '      css.href = "../browser-extension/sidepanel.css?v=0.7.0-1";')
    table.insert(html, '      document.head.append(css);')
    table.insert(html, '      const coreScript = document.createElement("script");')
    table.insert(html, '      coreScript.src = `../browser-extension/content-core.js?v=${assetVersion}`;')
    table.insert(html, '      coreScript.onload = () => {')
    table.insert(html, '        document.getElementById("test-embed-scenario").addEventListener("change", (event) => {')
    table.insert(html, '          state.embedStartup = {')
    table.insert(html, '            ...TLC_CONTENT_CORE.newEmbedSession(crypto.randomUUID(), "demo", Date.now()),')
    table.insert(html, '            phase: event.target.value, reason: "server-error", attempt: event.target.value === "failed" ? 3 : 1')
    table.insert(html, '          };')
    table.insert(html, '          stateListeners.forEach((listener) => listener({ type: "TLC_STATE_UPDATED", tabId: 1, state }));')
    table.insert(html, '        });')
    table.insert(html, '        document.getElementById("test-caption-scenario").addEventListener("change", (event) => {')
    table.insert(html, '          const mode = event.target.value;')
    table.insert(html, '          const observedAt = Date.now() - (mode === "historical" ? 60_000 : 0);')
    table.insert(html, '          state.captions = mode === "none" ? [] : ["DomCaption", "WebcastCaptionMessage"].map((method) => ({')
    table.insert(html, '            method, source: method === "DomCaption" ? "dom" : "websocket", receivedAtUtc: new Date(observedAt).toISOString(),')
    table.insert(html, '            contents: [{ lang: "de", text: "Dies ist eine Test-Caption." }]')
    table.insert(html, '          }));')
    table.insert(html, '          state.captionSources = TLC_CONTENT_CORE.captionSourceSnapshot();')
    table.insert(html, '          if (mode === "metadata") state.captionSources.metadata = { present: true, open: true, supportLang: ["de"] };')
    table.insert(html, '          else for (const caption of state.captions) state.captionSources = TLC_CONTENT_CORE.observeCaptionSource(state.captionSources, caption, observedAt);')
    table.insert(html, '          state.captionInfo = TLC_CONTENT_CORE.summarizeCaptionSources(state.captionSources);')
    table.insert(html, '          stateListeners.forEach((listener) => listener({ type: "TLC_STATE_UPDATED", tabId: 1, state }));')
    table.insert(html, '        });')
    table.insert(html, '        const privacyScript = document.createElement("script");')
    table.insert(html, '        privacyScript.src = `../browser-extension/export-privacy.js?v=${assetVersion}`;')
    table.insert(html, '        privacyScript.onload = () => {')
    table.insert(html, '          const script = document.createElement("script");')
    table.insert(html, '          script.src = `../browser-extension/sidepanel.js?v=${assetVersion}`;')
    table.insert(html, '          document.body.append(script);')
    table.insert(html, '        };')
    table.insert(html, '        document.body.append(privacyScript);')
    table.insert(html, '      };')
    table.insert(html, '      document.body.append(coreScript);')
    table.insert(html, '    })();')
    table.insert(html, '  </script>')
    table.insert(html, '</body>')
    table.insert(html, '</html>')
    
    return table.concat(html, "\n")
end

-- Hauptprogramm
local filename = arg[1] or "sidepanel-harness.html"
local file = io.open(filename, "w")
if not file then
    print("Fehler: Konnte Datei " .. filename .. " nicht öffnen")
    os.exit(1)
end

file:write(generateHTML())
file:close()

print("HTML-Datei erfolgreich erstellt: " .. filename)
