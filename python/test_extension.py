#!/usr/bin/env python3
# test_extension.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_extension.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_extension.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_extension.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

import json
import os
import subprocess
import sys
from pathlib import Path

# Konfiguration
ROOT_DIR = Path(__file__).parent.parent.resolve()
EXTENSION_DIR = ROOT_DIR / "browser-extension"
MANIFEST_PATH = EXTENSION_DIR / "manifest.json"
MOBILE_BRIDGE_PATH = ROOT_DIR / "mobile-shared" / "webview-bridge.js"

# Manifest laden
with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
    manifest = json.load(f)

# Core-Modul laden (angenommen, dass es eine Python-Version gibt)
sys.path.append(str(EXTENSION_DIR))
import content_core as core
import proto_main as proto

# Mobile Bridge laden
with open(MOBILE_BRIDGE_PATH, "r", encoding="utf-8") as f:
    mobile_bridge = f.read()

def concat(*chunks):
    """Verbindet mehrere Byte-Chunks zu einem einzigen bytearray"""
    result = bytearray()
    for chunk in chunks:
        result.extend(chunk)
    return result

def varint(value):
    """Erstellt eine Varint-Kodierung eines Werts"""
    value = int(value)
    bytes_list = []
    while True:
        byte = value & 0x7F
        value >>= 7
        if value:
            byte |= 0x80
        bytes_list.append(byte)
        if not value:
            break
    return bytearray(bytes_list)

def bytes_field(number, value):
    """Erstellt ein Protobuf-Bytes-Feld"""
    if isinstance(value, str):
        body = value.encode('utf-8')
    else:
        body = value
    tag = (number << 3) | 2
    return concat(varint(tag), varint(len(body)), body)

def int_field(number, value):
    """Erstellt ein Protobuf-Integer-Feld"""
    tag = number << 3
    return concat(varint(tag), varint(value))

# Tests für Manifest
assert manifest["manifest_version"] == 3
assert manifest["version"] == "0.8.2"
assert "sidePanel" in manifest["permissions"]
assert "webRequest" in manifest["permissions"]
assert "tabCapture" in manifest["permissions"]
assert "http://127.0.0.1/*" in manifest["host_permissions"]
assert "http://localhost/*" in manifest["host_permissions"]
assert "cookies" not in manifest["permissions"]
assert "webRequestBlocking" not in manifest["permissions"]
assert "nativeMessaging" not in manifest["permissions"]
assert manifest["content_scripts"][0]["js"][0] == "vendor-mpegts.js"

# Tests für Vendor-Dateien
mpegts_vendor_path = EXTENSION_DIR / "vendor-mpegts.js"
mpegts_license_path = EXTENSION_DIR / "vendor-mpegts.LICENSE.txt"
mpegts_notice_path = EXTENSION_DIR / "vendor-mpegts.NOTICE.md"

assert mpegts_vendor_path.exists()
assert mpegts_license_path.exists()
assert mpegts_notice_path.exists()

# SHA256-Prüfung
import hashlib
with open(mpegts_vendor_path, "rb") as f:
    content = f.read()
    sha256_hash = hashlib.sha256(content).hexdigest().upper()
assert sha256_hash == "0786F9AF6780822FF29240259A73B07ED7BC479BC44966E49418DD38213B8064"

# Tests für Mobile Bridge
assert 'location.hostname !== "www.tiktok.com"' in mobile_bridge
assert "document.cookie" not in mobile_bridge
assert "QUICK_RECOVER_RELOAD_COOLDOWN_MS = 400" in mobile_bridge
assert '"set-auto-reconnect"' in mobile_bridge
assert '"set-limiter"' in mobile_bridge

# Tests für Manifest-Dateien
for relative in [
    manifest["background"]["service_worker"],
    manifest["side_panel"]["default_path"]
]:
    full_path = EXTENSION_DIR / relative
    assert full_path.exists(), f"Fehlende Manifest-Datei: {relative}"

for item in manifest["content_scripts"]:
    for js_file in item["js"]:
        full_path = EXTENSION_DIR / js_file
        assert full_path.exists(), f"Fehlende Manifest-Datei: {js_file}"

# Tests für JavaScript-Dateien
scripts = [f for f in os.listdir(EXTENSION_DIR) if f.endswith(".js")]
for name in scripts:
    source_path = EXTENSION_DIR / name
    with open(source_path, "r", encoding="utf-8") as f:
        source = f.read()
    
    # Syntaxprüfung
    if name == "peak-limiter-worklet.js":
        result = subprocess.run([sys.executable, "--check", "--input-type=module"], 
                              input=source, text=True, capture_output=True)
        assert result.returncode == 0, result.stderr
    else:
        compile(source, name, "exec")
    
    # Sicherheitsprüfungen
    assert "eval(" not in source, f"{name} enthält eval()"
    assert "new Function(" not in source, f"{name} enthält new Function()"
    assert ".innerHTML =" not in source, f"{name} weist innerHTML zu"

# Tests für Core-Funktionen
metadata = {
    "room": {
        "caption_info": {"open": True, "support_lang": ["de", "en"], "show_type": 1},
        "stream_data": "{\"pull\":\"https:\\/\\/pull-flv-f77.example.tiktokcdn.com\\/stage\\/stream_hd.flv?expire=1\\u0026sign=abc\",\"hls\":\"https:\\/\\/pull-hls.example.tiktokcdn-eu.com\\/stage\\/stream_720p.m3u8?sign=xyz\"}"
    }
}
inspected = core.inspect_metadata(metadata)
assert inspected["captionInfo"]["present"] == True
assert inspected["captionInfo"]["open"] == True
assert inspected["captionInfo"]["supportLang"] == ["de", "en"]
assert len(inspected["media"]) == 2
assert any(item["protocol"] == "FLV" and item["quality"] == "HD" for item in inspected["media"])
assert any(item["protocol"] == "HLS" and item["quality"] == "720p" for item in inspected["media"])

assert core.classify_media_url("https://evil.example/stream.flv") is None
assert core.QUALITY_LABELS["auto"] == "Automatisch"
assert core.sanitize_chat_text("Hallo 😊 Welt ❤️") == "Hallo Welt"
assert core.sanitize_chat_text("@Nutzer 👍🏽 bleibt hier") == "@Nutzer bleibt hier"
assert core.word_count("Hallo 😊 schöne Welt") == 3
assert core.team_suffix_candidate("Miimii tmm") == "tmm"
assert core.team_suffix_candidate("Ben") == ""
assert core.team_suffix_candidate("das ist gut") == "gut"
assert core.content_has_token("@Honey tmm wo is mein Tee?", "tmm") == True
assert core.strip_team_tag("@Honey tmm wo is mein Tee?", "tmm") == "@Honey wo is mein Tee?"
assert core.strip_team_tag("das ist gut", "tmm") == "das ist gut"
assert core.shorten_nickname("Anja Schaarschmidt89") == "Anja"
assert core.shorten_nickname("Team Kimm") == "Team Kimm"
assert core.shorten_nickname("Blitzerbiest") == "Blitzerbiest"
assert core.shorten_nickname("Traumtänzer.der.Nächte") == "Traumtänzer"
assert core.shorten_nickname("Vanny_GioPrimetv") == "Vanny"
assert core.shorten_nickname("Die Löwin") == "Löwin"
assert core.shorten_nickname("liane15") == "liane"
assert core.shorten_nickname("MKU Maskenaufsicht") == "Maskenaufsicht"
assert core.shorten_nickname("Butterfly 004") == "Butterfly"
assert core.spoken_nickname("user572838499281727393816181") == "user572"
assert core.spoken_nickname("Rebecca № 2 💕") == "Rebecca"
assert core.collapse_laughter("hahahahahahhhhahhhaaaa Gott du Plemmi") == "haha Gott du Plemmi"
assert core.resolve_speech_language("auto", "de") == "de-DE"
assert core.resolve_speech_language("en-US", "de") == "en-US"
assert core.limiter_strength_to_dbfs(0) == -4
assert core.limiter_strength_to_dbfs(100) == -30
assert core.limiter_dbfs_to_strength(-30) == 100
assert core.limiter_makeup_compensation(-30, 20) < core.limiter_makeup_compensation(-10, 20)
assert core.compose_speech_text({"author": "Miimii tmm", "content": "@Stivinho danke"}, {"teamTag": "tmm"}) == "Miimii sagt zu Stivinho danke"
assert core.compose_speech_text({"author": "Blitzerbiest", "content": "@Honey tmm wo is mein Tee ?"}, {"teamTag": "tmm"}) == "Blitzerbiest fragt Honey wo is mein Tee"
assert core.compose_speech_text({"author": "Miimii", "content": "@ Stivinho danke"}, {"speakNames": False}) == "Stivinho danke"
assert core.compose_speech_text({"author": "Anja Schaarschmidt89", "content": "Guten Morgen"}, {"shortenNames": True}) == "Anja sagt Guten Morgen"
assert core.compose_speech_text({"author": "Mia", "content": "Hallo @"}) == "Mia sagt Hallo @"
assert core.game_event_speech({"rawText": "Jacky hat 1 Boosterhandschuh gesendet"}) == "Booster wurde gesetzt"
assert core.game_event_speech({"rawText": "Jacky hat Rose gesendet x 1"}) == ""
assert core.compose_speech_text({"author": "System", "content": "Booster wurde gesetzt", "systemSpeechText": "Booster wurde gesetzt"}) == "Booster wurde gesetzt"
assert core.should_filter_game_mode_speech(
    {"author": "A", "content": "Jacky", "receivedAtUtc": "2026-07-26T10:00:10.000Z"},
    {"jacky": {"name": "🫶Jacky🫶", "displayId": "jacky"}},
    [
        {"content": "Jacky", "receivedAtUtc": "2026-07-26T10:00:00.000Z"},
        {"content": "🫶 Jacky 🫶", "receivedAtUtc": "2026-07-26T10:00:05.000Z"}
    ]
) == True
assert core.should_filter_game_mode_speech(
    {"author": "A", "content": "@Jacky danke", "receivedAtUtc": "2026-07-26T10:00:10.000Z"},
    {"jacky": {"name": "Jacky", "displayId": "jacky"}},
    [{"content": "@Jacky danke", "receivedAtUtc": "2026-07-26T10:00:05.000Z"}]
) == False
assert core.compose_speech_text({"author": "user572838499281727393816181", "content": "hahahahahahhhhahhhaaaa bald"}) == "user572 sagt haha bald"
assert core.compose_speech_text({"author": "deroy", "content": "@user572838499281727393816181 bald bist du nur noch ein sohn"}) == "deroy sagt zu user572 bald bist du nur noch ein sohn"
assert core.compose_speech_text({"author": "Rebecca № 2 💕", "content": "@Vanny_GioPrimetv hallo"}, {"shortenNames": True}) == "Rebecca sagt zu Vanny hallo"

team = core.accumulate_team_evidence({}, "Miimii tmm", "Teilt den Stream", [])
assert team["teamTag"] == ""
team = core.accumulate_team_evidence(team["evidence"], "Honey tmm", "wo ist mein Tee?", ["Teilt den Stream"])
assert team["teamTag"] == "tmm"
team = core.accumulate_team_evidence({}, "Miimii tmm", "danke", [])
team = core.accumulate_team_evidence(team["evidence"], "Stivinho", "tmm hilft", ["danke"])
assert team["teamTag"] == "tmm"
assert core.accumulate_team_evidence({}, "Miimii tmm", "tmm danke", [])["teamTag"] == "tmm"
assert core.accumulate_team_evidence({}, "Ben", "Ben ist da", [])["teamTag"] == ""
assert core.stream_identity_changed({"handle": "demo", "roomId": "1"}, {"handle": "demo", "roomId": "1"}) == False
assert core.stream_identity_changed({"handle": "demo", "roomId": "1"}, {"handle": "demo", "roomId": "2"}) == True
assert core.stream_identity_changed({"handle": "demo", "roomId": ""}, {"handle": "other", "roomId": ""}) == True
assert core.live_handle_from_url("https://www.tiktok.com/@Demo/live") == "demo"
assert core.live_handle_from_url("https://www.tiktok.com/embed/live/@Other") == "other"
assert core.live_handle_from_url("https://www.tiktok.com/@demo") == ""
assert core.live_handle_from_url("not a url") == ""
assert core.parse_compact_count("3,231") == 3231
assert core.parse_compact_count("3.231") == 3231
assert core.parse_compact_count("3.2K") == 3200
assert core.parse_compact_count("1,1M") == 1100000
assert core.parse_compact_count("nicht verfügbar") is None

recommendation_items = core.dedupe_recommendations([
    {"handle": "@Alpha", "displayName": "", "title": "Erster Stream", "viewerCount": None, "url": "https://www.tiktok.com/@alpha/live", "position": 1},
    {"handle": "alpha", "displayName": "Alpha Live", "viewerCount": 123, "viewerLabel": "123", "position": 2},
    {"handle": "Beta", "displayName": "Beta", "viewerCount": 500, "url": "https://www.tiktok.com/@beta/live", "position": 3},
    {"handle": "gamma", "displayName": "Gamma", "viewerCount": None, "url": "https://www.tiktok.com/@gamma/live", "position": 2}
])
assert len(recommendation_items) == 3
assert recommendation_items[0]["handle"] == "alpha"
assert recommendation_items[0]["displayName"] == "Alpha Live"
assert recommendation_items[0]["viewerCount"] == 123
assert core.sort_recommendations(recommendation_items, "viewers")[0]["handle"] == "beta"

profile_and_summary = core.inspect_metadata({
    "live_ai_summary_ui": {"vid": "v2"},
    "userInfo": {
        "uniqueId": "demo",
        "nickname": "Demo",
        "signature": "Eine Bio",
        "stats": {"followingCount": 12, "followerCount": 345, "heartCount": 678}
    }
})
assert profile_and_summary["profileInfo"]["present"] == True
assert profile_and_summary["profileInfo"]["uniqueId"] == "demo"
assert profile_and_summary["profileInfo"]["followerCount"] == "345"
assert profile_and_summary["aiSummaryInfo"]["featureFlagPresent"] == True
assert profile_and_summary["aiSummaryInfo"]["text"] == ""

actual_summary = core.inspect_metadata({"live_summary_text": "Eine tatsächlich gelieferte Zusammenfassung."})
assert actual_summary["aiSummaryInfo"]["text"] == "Eine tatsächlich gelieferte Zusammenfassung."

pull_data = {
    "options": {"qualities": [
        {"sdk_key": "origin", "name": "Original"},
        {"sdk_key": "hd", "name": "720p"},
        {"sdk_key": "sd", "name": "540p"},
        {"sdk_key": "ld", "name": "360p"}
    ]},
    "stream_data": json.dumps({
        "data": {
            "origin": {"main": {"flv": "https://pull.example.tiktokcdn.com/live/stream_origin.flv", "sdk_params": json.dumps({"VCodec": "h265", "vbitrate": 2600000, "width": 1920, "height": 1080, "fps": 60})}},
            "hd": {"main": {"flv": "https://pull.example.tiktokcdn.com/live/stream_hd.flv", "hls": "https://pull.example.tiktokcdn.com/live/stream_hd.m3u8", "sdk_params": json.dumps({"VCodec": "h264", "vbitrate": 1800000, "width": 1280, "height": 720, "fps": 30})}},
            "sd": {"main": {"flv": "https://pull.example.tiktokcdn.com/live/stream_sd.flv", "sdk_params": json.dumps({"VCodec": "h264", "vbitrate": 900000, "width": 960, "height": 540, "fps": 30})}},
            "ld": {"main": {"flv": "https://pull.example.tiktokcdn.com/live/stream_ld.flv", "sdk_params": json.dumps({"VCodec": "h264", "vbitrate": 600000, "width": 640, "height": 360, "fps": 30})}}
        }
    })
}
variants = core.extract_stream_variants(pull_data)
assert len(variants) == 5
assert any(item["sdkKey"] == "origin" and item["quality"] == "Original" and item["height"] == 1080 for item in variants)
assert any(item["sdkKey"] == "hd" and item["quality"] == "720p" and item["bitrate"] == 1800000 for item in variants)
assert any(item["sdkKey"] == "sd" and item["width"] == 960 and item["height"] == 540 for item in variants)
assert any(item["sdkKey"] == "ld" and item["quality"] == "360p" and item["height"] == 360 for item in variants)

# Protobuf-Tests
caption_content = concat(bytes_field(1, "de"), bytes_field(2, "Guten Abend"))
caption_payload = concat(
    int_field(2, 123456),
    int_field(3, 1500),
    bytes_field(4, caption_content),
    int_field(5, 77),
    int_field(6, 3),
    int_field(7, 1)
)
base_message = concat(bytes_field(1, "WebcastCaptionMessage"), bytes_field(2, caption_payload))
fetch_result = bytes_field(1, base_message)
decoded = proto.decode_fetch_result(fetch_result)
assert len(decoded["captions"]) == 1
assert decoded["captions"][0]["contents"][0]["lang"] == "de"
assert decoded["captions"][0]["contents"][0]["text"] == "Guten Abend"
assert decoded["captions"][0]["sentenceId"] == "77"
assert decoded["captions"][0]["definite"] == True

chat_user = concat(int_field(1, 123), bytes_field(3, "Demo 😊"), bytes_field(38, "demo_user"))
chat_payload = concat(
    bytes_field(1, concat(int_field(2, 9010))),
    bytes_field(2, chat_user),
    bytes_field(3, "Guten Abend ❤️"),
    bytes_field(14, "de")
)
chat_fetch = bytes_field(1, concat(bytes_field(1, "WebcastChatMessage"), bytes_field(2, chat_payload)))
chat_decoded = proto.decode_fetch_result(chat_fetch)["chatMessages"]
assert len(chat_decoded) == 1
assert chat_decoded[0]["messageId"] == "9010"
assert chat_decoded[0]["nickname"] == "Demo 😊"
assert chat_decoded[0]["displayId"] == "demo_user"
assert chat_decoded[0]["content"] == "Guten Abend ❤️"
assert chat_decoded[0]["contentLanguage"] == "de"

gift_payload = concat(
    bytes_field(1, concat(int_field(2, 9020))),
    int_field(2, 777),
    int_field(5, 23),
    bytes_field(7, chat_user),
    int_field(9, 1)
)
gift_fetch = bytes_field(1, concat(bytes_field(1, "WebcastGiftMessage"), bytes_field(2, gift_payload)))
gift_decoded = proto.decode_fetch_result(gift_fetch)["giftMessages"]
assert len(gift_decoded) == 1
assert gift_decoded[0]["nickname"] == "Demo 😊"
assert gift_decoded[0]["repeatCount"] == "23"

common = concat(int_field(2, 9001), bytes_field(8, bytes_field(1, "pm_mt_msg_viewer")))
room_users = concat(bytes_field(1, common), int_field(3, 143), int_field(7, 15842))
likes = concat(bytes_field(1, common), int_field(2, 10), int_field(3, 430200))
social_common = concat(int_field(2, 9002), bytes_field(8, bytes_field(1, "pm_main_follow_message_viewer_2")))
social = concat(bytes_field(1, social_common), int_field(6, 238800))
live_fetch = concat(
    bytes_field(1, concat(bytes_field(1, "WebcastRoomUserSeqMessage"), bytes_field(2, room_users))),
    bytes_field(1, concat(bytes_field(1, "WebcastLikeMessage"), bytes_field(2, likes))),
    bytes_field(1, concat(bytes_field(1, "WebcastSocialMessage"), bytes_field(2, social)))
)
live_decoded = proto.decode_fetch_result(live_fetch)["liveEvents"]
assert len(live_decoded) == 3
assert live_decoded[0]["viewerCount"] == "143"
assert live_decoded[0]["totalViewers"] == "15842"
assert live_decoded[1]["likeCount"] == "430200"
assert live_decoded[2]["kind"] == "follow"
assert live_decoded[2]["followerCount"] == "238800"

# Zusätzliche Tests für Source-Dateien
background_source = (EXTENSION_DIR / "background.js").read_text(encoding="utf-8")
content_source = (EXTENSION_DIR / "content.js").read_text(encoding="utf-8")
hook_source = (EXTENSION_DIR / "hook.js").read_text(encoding="utf-8")
sidepanel_source = (EXTENSION_DIR / "sidepanel.js").read_text(encoding="utf-8")
proto_main_source = (EXTENSION_DIR / "proto-main.js").read_text(encoding="utf-8")
setup_source = (ROOT_DIR / "companion-service" / "setup.ps1").read_text(encoding="utf-8")
repair_source = (ROOT_DIR / "companion-service" / "Sprachdienst-reparieren.cmd").read_text(encoding="utf-8")
repair_powershell_source = (ROOT_DIR / "companion-service" / "repair-service.ps1").read_text(encoding="utf-8")

assert "const MAX_CHAT = 500;" in background_source
assert 'case "TLC_CHAT_MESSAGE"' in background_source
assert 'case "TLC_GET_PLAYER_STATE"' in background_source
assert 'case "TLC_CLEAR_CHAT"' in background_source
assert 'case "TLC_REFRESH_PAGE_INFO"' in background_source
assert 'case "TLC_SCAN_RECOMMENDATIONS"' in background_source
assert 'case "TLC_CANCEL_RECOMMENDATION_SCAN"' in background_source
assert 'case "TLC_RECOMMENDATION_SCAN_PROGRESS"' in background_source
assert "recommendationScan: emptyRecommendationScan()" in background_source
assert 'case "TLC_FORCE_PROFILE"' in background_source
assert "handleLiveTabUrlChange(tabId, changeInfo.url" in background_source
assert 'case "TLC_OPEN_EMBED_LIVE"' in background_source
assert 'case "TLC_SET_MUTE"' in background_source
assert 'case "TLC_GIFT_MESSAGE"' in background_source
assert 'case "TLC_SET_AUTOSTART"' in background_source
assert 'case "TLC_SET_QUICK_RECOVER"' in background_source
assert 'case "TLC_QUICK_RECOVER"' in background_source
assert 'case "TLC_PLAYER_STATE_PUSH"' in background_source
assert 'case "TLC_GET_DEBUG_REPORT"' in background_source

for debug_component in ["vlcReplacement", "speechAndChatSettings", "rawJsonExportAvailable", "jsonLinesExportAvailable", "songRecognition", "topChatters", "playerQuickRecovery"]:
    assert debug_component in background_source, f"Debug-Komponente fehlt: {debug_component}"

assert 'path: "browser-local-service-audd"' in background_source
assert "universalCaptionApiKeyConfigured" in background_source
assert 'const PROFILE_PREFIX = "tlc-profile-"' in background_source
assert "hookEnabled: false" in background_source
assert "quickRecoverEnabled: false" in background_source
assert "speechEnabled: false" in background_source
assert "chatSourceTabId: null" in background_source
assert "chatTargetTabId: null" in background_source
assert "debugEnabled: false" in background_source
assert "waitingForTikTok: true" in background_source
assert "function normalizePlayerState" in background_source
assert "duplicateMessageId" in background_source
assert "if (duplicate) {" in background_source
assert "await setState(tabId, state);" in background_source
assert "available: booleanValue(playerState.available)" in background_source
assert 'case "TLC_SET_DEBUG"' in background_source
assert "await setSettings({ debugEnabled: Boolean(message.enabled) })" not in background_source
assert "enabled: true" in background_source
assert "return { armed: Boolean(enabled), waitingForTikTok: Boolean(enabled), reloading: false }" in background_source
assert "await chrome.tabs.reload(tabId, { bypassCache: true })" in background_source
assert "www\\.tiktok\\.com\\/-" in background_source
assert "www\\.tiktok\\.com\\/embed\\/live" in background_source
assert "function openEmbedLive" in background_source
assert "function ensureEmbedChatSource" in background_source
assert "chatTargetTabId: embedTabId" in background_source
assert "chrome.tabs.create({ url: expectedUrl, active: false" in background_source
assert 'case "TLC_FULLSCREEN_EXITED"' in background_source
assert "replacement = await chrome.tabs.create" not in background_source
assert "function isLivePage()" in content_source
assert "^\\/@[^/]+\\/live" in content_source
assert "^\\/embed\\/live" in content_source
assert "if (!force || !isLivePage())" in content_source
assert 'action === "open-report"' in content_source
assert 'action === "set-volume"' in content_source
assert 'action === "set-limiter"' in content_source
assert "createPeakLimiterNode" in content_source
assert "createGain" in content_source
assert "limiterMakeupCompensation" not in content_source
assert "captureStream" in content_source
assert "createMediaStreamSource" in content_source
assert "audio-context-resume-deferred" in content_source
assert "continue watching" in content_source
assert "video.play().catch" in content_source
assert "function quickRecoverReason" in content_source
assert "let quickRecoverArmed = false" in content_source
assert "quickRecoverArmed = true" in content_source
assert "if (!quickRecoverArmed) return \"\";" in content_source
assert "const POPUP_GUARD_GRACE_MS = 40;" in content_source
assert "const QUICK_RECOVER_INTERVAL_MS = 40;" in content_source
assert "const QUICK_RECOVER_CONFIRM_MS = 3000;" in content_source
assert "now - quickRecoverReasonSince < quickRecoverConfirmMs" in content_source
assert "let quickRecoverConfirmMs = QUICK_RECOVER_CONFIRM_MS" in content_source
assert "quickRecoverSeconds: 3" in background_source
assert "state.quickRecoverSeconds = seconds" in background_source
assert "setSettings({ quickRecoverSeconds: seconds })" not in background_source
assert "const MAX_DEBUG" not in background_source
assert "raw: state" not in background_source
assert "exportPrivacy.diagnosticReport(" in background_source
assert '`raw:${String(message?.type || "unknown")}`' in background_source
assert "let quickRecoverPending = false" in content_source
assert "if (quickRecoverPending) return" in content_source
assert "quickRecoverInFlight.has(tabId)" in background_source
assert "QUICK_RECOVER_LOCAL_PLAY_MS" not in content_source
assert 'type: "TLC_QUICK_RECOVER"' in content_source
assert 'type: "TLC_FULLSCREEN_EXITED"' in content_source
assert 'type: "TLC_PLAYER_STATE_PUSH"' in content_source
assert "chatSourceOnly" in content_source
assert "function playMediaFallback" in content_source
assert "tlc-media-fallback" in content_source
assert "tlc-media-fallback-status" in content_source
assert "VLC Ersatz wird geprüft." in content_source
assert "attemptedMediaFallbackUrls" in content_source
assert "globalThis.mpegts.createPlayer" in content_source
assert "enableWorker: false" in content_source
assert 'setTimeout(() => done(false, "timeout"), 15000)' in content_source
assert "Erneuter Klick prüft die nächste ungetestete Quelle." in content_source
assert "playerBonus" in content_source
assert "videoArea * 4.5" in content_source
assert '"fullscreenchange"' in content_source

popup_guard_source = (EXTENSION_DIR / "popup-guard.js").read_text(encoding="utf-8")
assert "keepwatching" in popup_guard_source
assert "^\\/embed\\/live" in popup_guard_source
assert "video.volume > cap" not in content_source
assert "Lautstärkedeckel" not in content_source
assert f"${{volumePercent}}%" in sidepanel_source
assert f"${{value}}%" in sidepanel_source
assert "function activateSpeech" in sidepanel_source
assert "function persistSpeechEnabled" in sidepanel_source
assert 'type: "TLC_SET_TAB_SPEECH"' in sidepanel_source
assert 'case "TLC_SET_TAB_SPEECH"' in background_source
assert "ensureOffscreenDocument" in background_source
assert "function booleanValue" in sidepanel_source
assert "booleanValue(playerState.available)" in sidepanel_source
assert "const available = Boolean(playerState.available)" not in sidepanel_source
assert "collectRecommendedSummary" in content_source
assert "collectProfileFromHover" in content_source
assert "function certifiedSvgBadge" in content_source
assert 'root.querySelectorAll("svg")' in content_source
assert "verified|verifiziert|zertifiziert|certified|official" not in content_source
assert "function liveProBadgePresent" in content_source
assert "liveProSeenHandle" in content_source
assert "function elementTextBundle" in content_source
assert "LIVE\\s+Pro" in content_source
assert "Live Pro" in content_source
assert "liveProLabel" in content_source
assert "function sponsoredContentBadgePresent" in content_source
assert "sponsoredContentSeenHandle" in content_source
assert "Werbeinhalt" in content_source
assert "sponsoredContentLabel" in content_source
assert "function paidPartnershipBadgePresent" in content_source
assert "paidPartnershipSeenHandle" in content_source
assert "Bezahlte Partnerschaft" in content_source
assert "paidPartnershipLabel" in content_source
assert 'credentials: "omit"' in content_source
assert 'auto: ["Automatisch", "Automatic", "Auto"]' in content_source
assert 'credentials: "include"' not in content_source
assert 'debug("dom-chat-scan-error"' in content_source
assert 'debug("dom-observer-error"' in content_source
assert "document.addEventListener(\"DOMContentLoaded\", startTabRuntime, { once: true })" in content_source
assert 'sessionStorage.getItem("tlc_ws_hook_enabled")' not in hook_source
assert "currentLiveHandle" in hook_source
assert "^\\/@([^/]+)\\/live" in hook_source
assert "^\\/embed\\/live" in hook_source
assert "else if (!root[protoKey])" in proto_main_source
assert (EXTENSION_DIR / "popup-guard.js").exists()
assert '"popup-guard.js", "proto-main.js", "hook-recovery.js", "hook.js"' in background_source

panel_html = (EXTENSION_DIR / "sidepanel.html").read_text(encoding="utf-8")
assert 'id="quick-recover-seconds"' in panel_html
assert 'min="1" max="59"' in panel_html
panel_css = (EXTENSION_DIR / "sidepanel.css").read_text(encoding="utf-8")
offscreen_source = (EXTENSION_DIR / "offscreen.js").read_text(encoding="utf-8")
assert "TLC_OFFSCREEN_SPEAK" in offscreen_source
assert "TLC_OFFSCREEN_CANCEL" in offscreen_source
assert "offscreen" in manifest["permissions"]
assert panel_html.index('id="page-info-heading"') > panel_html.index('id="top-chatters-heading"')
assert panel_html.index('id="page-info-heading"') < panel_html.index('id="hook-heading"')
assert panel_html.index('id="caption-heading"') > panel_html.index('id="hook-heading"')
assert panel_html.index('id="song-heading"') > panel_html.index('id="player-heading"')
assert 'id="chat-led"' in panel_html
assert 'id="speech-led"' in panel_html
assert 'id="speech-volume"' in panel_html
assert 'id="hook-led"' in panel_html
assert 'id="limiter-enabled"' in panel_html
assert 'id="refresh-page-info"' in panel_html
assert 'id="force-page-info"' in panel_html
assert 'id="top-chatters"' in panel_html
assert 'id="top-chatters-more"' in panel_html
assert 'id="top-chatters-reset"' in panel_html
assert "const allowed = [5, 15, 25, 35, 45, 50]" in sidepanel_source
assert "Math.min(50, current + 10)" in sidepanel_source
assert panel_html.index('id="page-info-section"') < panel_html.index('id="stats-heading"')
assert panel_html.index('id="hook-heading"') < panel_html.index('id="recommendations-section"')
assert panel_html.index('id="recommendations-section"') < panel_html.index('id="caption-heading"')
assert 'id="recommendation-limit"' in panel_html
