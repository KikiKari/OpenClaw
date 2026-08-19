#!/usr/bin/env tclsh
# sidepanel-harness.html — portiert nach tcl
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/tests/sidepanel-harness.html
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/tests/sidepanel-harness.html
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/tests/sidepanel-harness.html
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 Script zur Erzeugung der sidepanel-harness.html
# Portiert von HTML zu Tcl unter Erhaltung der Funktionalität

proc write_sidepanel_harness {filename} {
    set f [open $filename w]
    
    puts $f {<!doctype html>}
    puts $f {<html lang="de">}
    puts $f {<head>}
    puts $f {  <meta charset="utf-8">}
    puts $f {  <meta name="viewport" content="width=device-width, initial-scale=1">}
    puts $f {  <title>Sidepanel Test Harness</title>}
    puts $f {</head>}
    puts $f {<body>}
    puts $f {  <script>}
    puts $f {    (async () => \{}
    puts $f {      const state = \{}
    puts $f {        page: \{ url: "https://www.tiktok.com/@demo/live", title: "Demo LIVE", scannedAtUtc: new Date().toISOString() \},}
    puts $f {        captionInfo: \{ present: true, open: true, supportLang: ["de", "en"], location: null, showType: 1 \},}
    puts $f {        menuCaptionAvailable: true,}
    puts $f {        menuCaptionActive: false,}
    puts $f {        profileInfo: \{}
    puts $f {          present: true, nickname: "Demo Creator", uniqueId: "demo", signature: "Barrierefreier Teststream",}
    puts $f {          followingCount: "12", followerCount: "238800", likeCount: "1800000", live: true, source: "metadata"}
    puts $f {        \},}
    puts $f {        aiSummaryInfo: \{ featureFlagPresent: true, featureEnabled: true, text: "", source: null, overviewCardFound: true, overviewCardHovered: true \},}
    puts $f {        hook: \{ armed: true, installed: true, connected: true, lastError: null \},}
    puts $f {        stream: \{ key: "demo|123", handle: "demo", roomId: "123", teamTag: "tmm", teamEvidence: \{\} \},}
    puts $f {        liveStats: \{}
    puts $f {          viewerCount: "143", totalViewers: "15842", likeCount: "430200",}
    puts $f {          followEvents: 7, shareEvents: 4, shareCount: "19", followerCount: "238800",}
    puts $f {          lastUpdatedUtc: new Date().toISOString(), recentEventIds: []}
    puts $f {        \},}
    puts $f {        playerState: \{}
    puts $f {          available: true, playing: true, muted: false, elapsedText: "1:17:42", pipActive: false, fullscreenActive: false,}
    puts $f {          volume: 0.72, volumePercent: 72, volumeGainDb: -2.9, peakDbfs: -8.4,}
    puts $f {          limiterEnabled: true, limiterThresholdDbfs: -6, limiterReductionDb: -1.2, limiterMode: "Kompressor",}
    puts $f {          connectedStreams: 4, multiGuest: true, updatedAtUtc: new Date().toISOString()}
    puts $f {        \},}
    puts $f {        selectedQuality: "540p",}
    puts $f {        chatMessages: [}
    puts $f {          \{ messageId: "1", participantKey: "id:1", author: "Anna", content: "Guten Abend", contentLanguage: "de-DE", source: "websocket", receivedAtUtc: new Date().toISOString() \},}
    puts $f {          \{ messageId: "2", participantKey: "id:2", author: "Ben", content: "Welche Sorte ist das?", contentLanguage: "de-DE", source: "dom", receivedAtUtc: new Date().toISOString() \},}
    puts $f {          \{ messageId: "3", author: "Clara", content: "Danke für die Erklärung", contentLanguage: "de-DE", source: "websocket", receivedAtUtc: new Date().toISOString() \},}
    puts $f {          \{ messageId: "4", author: "David", content: "Bitte einmal mischen", contentLanguage: "de-DE", source: "websocket", receivedAtUtc: new Date().toISOString() \},}
    puts $f {          \{ messageId: "5", author: "Eva", content: "Das ist gut lesbar", contentLanguage: "de-DE", source: "websocket", receivedAtUtc: new Date().toISOString() \}}
    puts $f {        ],}
    puts $f {        participants: \{}
    puts $f {          "id:1": \{ key: "id:1", name: "Anna", messageCount: 12, wordCount: 48, giftEventCount: 2, giftItemCount: 24, lastSeenAtUtc: new Date().toISOString() \},}
    puts $f {          "id:2": \{ key: "id:2", name: "Ben", messageCount: 8, wordCount: 39, giftEventCount: 0, giftItemCount: 0, lastSeenAtUtc: new Date().toISOString() \},}
    puts $f {          "name:clara": \{ key: "name:clara", name: "Clara", messageCount: 6, wordCount: 31, giftEventCount: 1, giftItemCount: 1, lastSeenAtUtc: new Date().toISOString() \}}
    puts $f {        \},}
    puts $f {        streamMutes: [],}
    puts $f {        participantsTruncated: false,}
    puts $f {        media: [}
    puts $f {          \{ url: "https://pull.example.tiktokcdn.com/live/stream_hd.flv?expire=1&sign=test", protocol: "FLV", quality: "720p", sdkKey: "hd", bitrate: 1800000, codec: "h264", width: 1280, height: 720, fps: 30, audioOnly: false, hostname: "pull.example.tiktokcdn.com", source: "metadata" \},}
    puts $f {          \{ url: "https://pull.example.tiktokcdn-eu.com/live/stream_720p.m3u8?sign=test", protocol: "HLS", quality: "720p", sdkKey: "hd", bitrate: 1800000, codec: "h264", width: 1280, height: 720, fps: 30, audioOnly: false, hostname: "pull.example.tiktokcdn-eu.com", source: "network" \},}
    puts $f {          \{ url: "https://pull.example.tiktokcdn.com/live/stream_sd.flv?expire=1&sign=test", protocol: "FLV", quality: "540p", sdkKey: "sd", bitrate: 900000, codec: "h264", width: 960, height: 540, fps: 30, audioOnly: false, hostname: "pull.example.tiktokcdn.com", source: "metadata" \}}
    puts $f {        ],}
    puts $f {        captions: [}
    puts $f {          \{ receivedAtUtc: new Date().toISOString(), sentenceId: "42", definite: true, contents: [\{ lang: "de", text: "Dies ist eine Test-Caption." \}] \}}
    puts $f {        ],}
    puts $f {        debug: \{ enabled: false, entries: [\{ atUtc: new Date().toISOString(), event: "scan", detail: \{ mediaCount: 3 \} \}] \}}
    puts $f {      \};}
    puts $f {}
    puts $f {      globalThis.chrome = \{}
    puts $f {        tabs: \{}
    puts $f {          query: async () => [\{ id: 1, url: state.page.url, title: state.page.title \}],}
    puts $f {          onActivated: \{ addListener() \{\} \}}
    puts $f {        \},}
    puts $f {        tabCapture: \{ capture(_options, callback) \{ callback(null); \} \},}
    puts $f {        runtime: \{}
    puts $f {          sendMessage: async (message) => \{}
    puts $f {            if (message.type === "TLC_GET_STATE") return \{ ok: true, state \};}
    puts $f {            if (message.type === "TLC_GET_SETTINGS") return \{ ok: true, settings: \{ autoHook: true, keepSpeechActive: true, speechVolume: 0.5, speechLanguage: "auto", speakNames: true, shortenNames: false, serviceUrl: "http://127.0.0.1:43117", pairingCode: "", permanentMutes: [] \} \};}
    puts $f {            if (message.type === "TLC_SCAN") \{}
    puts $f {              return \{ ok: true, response: \{ captionInfo: state.captionInfo, captionControl: true, mediaCount: state.media.length \} \};}
    puts $f {            \}}
    puts $f {            if (message.type === "TLC_GET_PLAYER_STATE") return \{ ok: true, response: \{ playerState: state.playerState \} \};}
    puts $f {            if (message.type === "TLC_PLAYER_ACTION") \{}
    puts $f {              if (message.action === "toggle-play") state.playerState.playing = !state.playerState.playing;}
    puts $f {              if (message.action === "toggle-mute") state.playerState.muted = !state.playerState.muted;}
    puts $f {              if (message.action === "set-volume") \{}
    puts $f {                state.playerState.volume = Number(message.value);}
    puts $f {                state.playerState.volumePercent = Math.round(Number(message.value) * 100);}
    puts $f {                state.playerState.volumeGainDb = Number(message.value) > 0 ? 20 * Math.log10(Number(message.value)) : null;}
    puts $f {              \}}
    puts $f {              if (message.action === "set-limiter") \{}
    puts $f {                state.playerState.limiterEnabled = Boolean(message.enabled);}
    puts $f {                state.playerState.limiterThresholdDbfs = Number(message.thresholdDbfs);}
    puts $f {              \}}
    puts $f {              return \{ ok: true, response: \{ activated: true, playerState: state.playerState \} \};}
    puts $f {            \}}
    puts $f {            if (message.type === "TLC_CLEAR_CHAT") \{}
    puts $f {              state.chatMessages = [];}
    puts $f {              return \{ ok: true \};}
    puts $f {            \}}
    puts $f {            if (message.type === "TLC_SET_DEBUG") \{}
    puts $f {              state.debug.enabled = Boolean(message.enabled);}
    puts $f {              return \{ ok: true, state \};}
    puts $f {            \}}
    puts $f {            if (message.type === "TLC_CLEAR_DEBUG") \{}
    puts $f {              state.debug.entries = [];}
    puts $f {              return \{ ok: true \};}
    puts $f {            \}}
    puts $f {            if (message.type === "TLC_SET_MUTE") return \{ ok: true, state, settings: \{ permanentMutes: [] \} \};}
    puts $f {            if (message.type === "TLC_GET_DEBUG_REPORT") return \{ ok: true, report: \{ version: "0.7.0", debug: state.debug \} \};}
    puts $f {            return \{ ok: true, response: \{ activated: true \} \};}
    puts $f {          \},}
    puts $f {          onMessage: \{ addListener() \{\} \}}
    puts $f {        \}}
    puts $f {      \};}
    puts $f {}
    puts $f {      const source = await fetch("../browser-extension/sidepanel.html").then((response) => response.text());}
    puts $f {      const parsed = new DOMParser().parseFromString(source, "text/html");}
    puts $f {      document.title = parsed.title;}
    puts $f {      for (const child of [...parsed.body.children]) \{}
    puts $f {        if (child.tagName !== "SCRIPT") document.body.append(document.importNode(child, true));}
    puts $f {      \}}
    puts $f {      const css = document.createElement("link");}
    puts $f {      css.rel = "stylesheet";}
    puts $f {      css.href = "../browser-extension/sidepanel.css?v=0.7.0-1";}
    puts $f {      document.head.append(css);}
    puts $f {      const coreScript = document.createElement("script");}
    puts $f {      coreScript.src = "../browser-extension/content-core.js";}
    puts $f {      coreScript.onload = () => \{}
    puts $f {        const script = document.createElement("script");}
    puts $f {        script.src = "../browser-extension/sidepanel.js";}
    puts $f {        document.body.append(script);}
    puts $f {      \};}
    puts $f {      document.body.append(coreScript);}
    puts $f {    \})();}
    puts $f {  </script>}
    puts $f {</body>}
    puts $f {</html>}
    
    close $f
}

# Hauptprogramm - prüft ob ein Dateiname übergeben wurde
if {$argc != 1} {
    puts stderr "Verwendung: $argv0 <ausgabedatei>"
    exit 1
}

set output_file [lindex $argv 0]
write_sidepanel_harness $output_file
