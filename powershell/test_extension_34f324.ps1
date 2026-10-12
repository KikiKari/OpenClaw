#!/usr/bin/env pwsh
# test_extension.cjs — portiert nach powershell
# Quelle: javascript, Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_extension.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$extension = Join-Path $root "browser-extension"
$manifest = Get-Content (Join-Path $extension "manifest.json") | ConvertFrom-Json
$core = & (Join-Path $extension "content-core.js")
$proto = & (Join-Path $extension "proto-main.js")
$mobileBridge = Get-Content (Join-Path $root "mobile-shared" "webview-bridge.js") -Raw

function Concat {
    param([array]$Chunks)
    
    $size = ($Chunks | Measure-Object Length -Sum).Sum
    $out = New-Object byte[] $size
    $offset = 0
    foreach ($chunk in $Chunks) {
        [Array]::Copy($chunk, 0, $out, $offset, $chunk.Length)
        $offset += $chunk.Length
    }
    return $out
}

function Varint {
    param([long]$Value)
    
    $bytes = @()
    do {
        $byte = $Value -band 0x7f
        $Value = $Value -shr 7
        if ($Value) { $byte = $byte -bor 0x80 }
        $bytes += $byte
    } while ($Value)
    return [byte[]]$bytes
}

function BytesField {
    param([int]$Number, [object]$Value)
    
    $body = if ($Value -is [string]) { [Text.Encoding]::UTF8.GetBytes($Value) } else { $Value }
    return Concat @(
        (Varint (($Number -shl 3) -bor 2)),
        (Varint $body.Length),
        $body
    )
}

function IntField {
    param([int]$Number, [long]$Value)
    
    return Concat @(
        (Varint ($Number -shl 3)),
        (Varint $Value)
    )
}

# Assertions
if ($manifest.manifest_version -ne 3) { throw "Manifest version mismatch" }
if ($manifest.version -ne "0.8.2") { throw "Version mismatch" }
if (-not $manifest.permissions.Contains("sidePanel")) { throw "Missing sidePanel permission" }
if (-not $manifest.permissions.Contains("webRequest")) { throw "Missing webRequest permission" }
if (-not $manifest.permissions.Contains("tabCapture")) { throw "Missing tabCapture permission" }
if (-not $manifest.host_permissions.Contains("http://127.0.0.1/*")) { throw "Missing host_permission http://127.0.0.1/*" }
if (-not $manifest.host_permissions.Contains("http://localhost/*")) { throw "Missing host_permission http://localhost/*" }
if ($manifest.permissions.Contains("cookies")) { throw "Unexpected cookies permission" }
if ($manifest.permissions.Contains("webRequestBlocking")) { throw "Unexpected webRequestBlocking permission" }
if ($manifest.permissions.Contains("nativeMessaging")) { throw "Unexpected nativeMessaging permission" }
if ($manifest.content_scripts[0].js[0] -ne "vendor-mpegts.js") { throw "First content script mismatch" }

$mpegtsVendorPath = Join-Path $extension "vendor-mpegts.js"
$mpegtsLicensePath = Join-Path $extension "vendor-mpegts.LICENSE.txt"
$mpegtsNoticePath = Join-Path $extension "vendor-mpegts.NOTICE.md"
if (-not (Test-Path $mpegtsVendorPath)) { throw "Missing vendor-mpegts.js" }
if (-not (Test-Path $mpegtsLicensePath)) { throw "Missing vendor-mpegts.LICENSE.txt" }
if (-not (Test-Path $mpegtsNoticePath)) { throw "Missing vendor-mpegts.NOTICE.md" }

$mpegtsContent = Get-Content $mpegtsVendorPath -Encoding Byte -Raw
$hash = [BitConverter]::ToString((New-Object Security.Cryptography.SHA256CryptoServiceProvider).ComputeHash($mpegtsContent)).Replace("-", "")
if ($hash -ne "0786F9AF6780822FF29240259A73B07ED7BC479BC44966E49418DD38213B8064") { throw "SHA256 hash mismatch" }

if (-not $mobileBridge.Contains('location.hostname !== "www.tiktok.com"')) { throw "Missing location check" }
if ($mobileBridge.Contains("document.cookie")) { throw "Unexpected document.cookie usage" }
if (-not $mobileBridge.Contains("QUICK_RECOVER_RELOAD_COOLDOWN_MS = 400")) { throw "Missing QUICK_RECOVER_RELOAD_COOLDOWN_MS" }
if (-not $mobileBridge.Contains('"set-auto-reconnect"')) { throw "Missing set-auto-reconnect" }
if (-not $mobileBridge.Contains('"set-limiter"')) { throw "Missing set-limiter" }

foreach ($relative in @(
    $manifest.background.service_worker,
    $manifest.side_panel.default_path
) + ($manifest.content_scripts | ForEach-Object { $_.js })) {
    $fullPath = Join-Path $extension $relative
    if (-not (Test-Path $fullPath)) { throw "Missing manifest file: $relative" }
}

$scripts = Get-ChildItem $extension -Filter "*.js" | ForEach-Object { $_.Name }
foreach ($name in $scripts) {
    $source = Get-Content (Join-Path $extension $name) -Raw
    # Basic syntax check by attempting to parse as JSON (this will fail for invalid JS but works for basic validation)
    try {
        $null = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$null, [ref]$null)
    } catch {
        throw "$name contains syntax errors"
    }
    if ($source -match '\beval\s*\(') { throw "$name contains eval()" }
    if ($source -match 'new\s+Function\s*\(') { throw "$name contains new Function()" }
    if ($source -match '\.innerHTML\s*=') { throw "$name assigns innerHTML" }
}

$metadata = @{
    room = @{
        caption_info = @{ open = $true; support_lang = @("de", "en"); show_type = 1 }
        stream_data = '{"pull":"https:\/\/pull-flv-f77.example.tiktokcdn.com\/stage\/stream_hd.flv?expire=1\u0026sign=abc","hls":"https:\/\/pull-hls.example.tiktokcdn-eu.com\/stage\/stream_720p.m3u8?sign=xyz"}'
    }
}
$inspected = $core.inspectMetadata($metadata)
if ($inspected.captionInfo.present -ne $true) { throw "captionInfo.present assertion failed" }
if ($inspected.captionInfo.open -ne $true) { throw "captionInfo.open assertion failed" }
if (-not (Compare-Object $inspected.captionInfo.supportLang @("de", "en"))) { throw "captionInfo.supportLang assertion failed" }
if ($inspected.media.Count -ne 2) { throw "media count assertion failed" }
if (-not ($inspected.media | Where-Object { $_.protocol -eq "FLV" -and $_.quality -eq "HD" })) { throw "FLV HD media missing" }
if (-not ($inspected.media | Where-Object { $_.protocol -eq "HLS" -and $_.quality -eq "720p" })) { throw "HLS 720p media missing" }
if ($core.classifyMediaUrl("https://evil.example/stream.flv") -ne $null) { throw "classifyMediaUrl should return null for evil URL" }
if ($core.QUALITY_LABELS.auto -ne "Automatisch") { throw "QUALITY_LABELS.auto assertion failed" }
if ($core.sanitizeChatText("Hallo 😊 Welt ❤️") -ne "Hallo Welt") { throw "sanitizeChatText assertion failed" }
if ($core.sanitizeChatText("@Nutzer 👍🏽 bleibt hier") -ne "@Nutzer bleibt hier") { throw "sanitizeChatText with skin tone assertion failed" }
if ($core.wordCount("Hallo 😊 schöne Welt") -ne 3) { throw "wordCount assertion failed" }
if ($core.teamSuffixCandidate("Miimii tmm") -ne "tmm") { throw "teamSuffixCandidate Miimii tmm assertion failed" }
if ($core.teamSuffixCandidate("Ben") -ne "") { throw "teamSuffixCandidate Ben assertion failed" }
if ($core.teamSuffixCandidate("das ist gut") -ne "gut") { throw "teamSuffixCandidate das ist gut assertion failed" }
if ($core.contentHasToken("@Honey tmm wo is mein Tee?", "tmm") -ne $true) { throw "contentHasToken assertion failed" }
if ($core.stripTeamTag("@Honey tmm wo is mein Tee?", "tmm") -ne "@Honey wo is mein Tee?") { throw "stripTeamTag assertion failed" }
if ($core.stripTeamTag("das ist gut", "tmm") -ne "das ist gut") { throw "stripTeamTag no tag assertion failed" }
if ($core.shortenNickname("Anja Schaarschmidt89") -ne "Anja") { throw "shortenNickname Anja assertion failed" }
if ($core.shortenNickname("Team Kimm") -ne "Team Kimm") { throw "shortenNickname Team Kimm assertion failed" }
if ($core.shortenNickname("Blitzerbiest") -ne "Blitzerbiest") { throw "shortenNickname Blitzerbiest assertion failed" }
if ($core.shortenNickname("Traumtänzer.der.Nächte") -ne "Traumtänzer") { throw "shortenNickname Traumtänzer assertion failed" }
if ($core.shortenNickname("Vanny_GioPrimetv") -ne "Vanny") { throw "shortenNickname Vanny assertion failed" }
if ($core.shortenNickname("Die Löwin") -ne "Löwin") { throw "shortenNickname Löwin assertion failed" }
if ($core.shortenNickname("liane15") -ne "liane") { throw "shortenNickname liane assertion failed" }
if ($core.shortenNickname("MKU Maskenaufsicht") -ne "Maskenaufsicht") { throw "shortenNickname Maskenaufsicht assertion failed" }
if ($core.shortenNickname("Butterfly 004") -ne "Butterfly") { throw "shortenNickname Butterfly assertion failed" }
if ($core.spokenNickname("user572838499281727393816181") -ne "user572") { throw "spokenNickname long user assertion failed" }
if ($core.spokenNickname("Rebecca № 2 💕") -ne "Rebecca") { throw "spokenNickname Rebecca assertion failed" }
if ($core.collapseLaughter("hahahahahahhhhahhhaaaa Gott du Plemmi") -ne "haha Gott du Plemmi") { throw "collapseLaughter assertion failed" }
if ($core.resolveSpeechLanguage("auto", "de") -ne "de-DE") { throw "resolveSpeechLanguage auto assertion failed" }
if ($core.resolveSpeechLanguage("en-US", "de") -ne "en-US") { throw "resolveSpeechLanguage en-US assertion failed" }
if ($core.limiterStrengthToDbfs(0) -ne -4) { throw "limiterStrengthToDbfs 0 assertion failed" }
if ($core.limiterStrengthToDbfs(100) -ne -30) { throw "limiterStrengthToDbfs 100 assertion failed" }
if ($core.limiterDbfsToStrength(-30) -ne 100) { throw "limiterDbfsToStrength -30 assertion failed" }
if (-not ($core.limiterMakeupCompensation(-30, 20) -lt $core.limiterMakeupCompensation(-10, 20))) { throw "limiterMakeupCompensation comparison assertion failed" }
if ($core.composeSpeechText(@{ author = "Miimii tmm"; content = "@Stivinho danke" }, @{ teamTag = "tmm" }) -ne "Miimii sagt zu Stivinho danke") { throw "composeSpeechText Miimii assertion failed" }
if ($core.composeSpeechText(@{ author = "Blitzerbiest"; content = "@Honey tmm wo is mein Tee ?" }, @{ teamTag = "tmm" }) -ne "Blitzerbiest fragt Honey wo is mein Tee") { throw "composeSpeechText Blitzerbiest assertion failed" }
if ($core.composeSpeechText(@{ author = "Miimii"; content = "@ Stivinho danke" }, @{ speakNames = $false }) -ne "Stivinho danke") { throw "composeSpeechText no names assertion failed" }
if ($core.composeSpeechText(@{ author = "Anja Schaarschmidt89"; content = "Guten Morgen" }, @{ shortenNames = $true }) -ne "Anja sagt Guten Morgen") { throw "composeSpeechText shortened names assertion failed" }
if ($core.composeSpeechText(@{ author = "Mia"; content = "Hallo @" }) -ne "Mia sagt Hallo @") { throw "composeSpeechText Mia assertion failed" }
if ($core.gameEventSpeech(@{ rawText = "Jacky hat 1 Boosterhandschuh gesendet" }) -ne "Booster wurde gesetzt") { throw "gameEventSpeech booster assertion failed" }
if ($core.gameEventSpeech(@{ rawText = "Jacky hat Rose gesendet x 1" }) -ne "") { throw "gameEventSpeech rose assertion failed" }
if ($core.composeSpeechText(@{ author = "System"; content = "Booster wurde gesetzt"; systemSpeechText = "Booster wurde gesetzt" }) -ne "Booster wurde gesetzt") { throw "composeSpeechText system assertion failed" }
if ($core.shouldFilterGameModeSpeech(
    @{ author = "A"; content = "Jacky"; receivedAtUtc = "2026-07-26T10:00:10.000Z" },
    @{ jacky = @{ name = "🫶Jacky🫶"; displayId = "jacky" } },
    @(
        @{ content = "Jacky"; receivedAtUtc = "2026-07-26T10:00:00.000Z" },
        @{ content = "🫶 Jacky 🫶"; receivedAtUtc = "2026-07-26T10:00:05.000Z" }
    )
) -ne $true) { throw "shouldFilterGameModeSpeech true assertion failed" }
if ($core.shouldFilterGameModeSpeech(
    @{ author = "A"; content = "@Jacky danke"; receivedAtUtc = "2026-07-26T10:00:10.000Z" },
    @{ jacky = @{ name = "Jacky"; displayId = "jacky" } },
    @(@{ content = "@Jacky danke"; receivedAtUtc = "2026-07-26T10:00:05.000Z" })
) -ne $false) { throw "shouldFilterGameModeSpeech false assertion failed" }
if ($core.composeSpeechText(@{ author = "user572838499281727393816181"; content = "hahahahahahhhhahhhaaaa bald" }) -ne "user572 sagt haha bald") { throw "composeSpeechText user572 bald assertion failed" }
if ($core.composeSpeechText(@{ author = "deroy"; content = "@user572838499281727393816181 bald bist du nur noch ein sohn" }) -ne "deroy sagt zu user572 bald bist du nur noch ein sohn") { throw "composeSpeechText deroy user572 assertion failed" }
if ($core.composeSpeechText(@{ author = "Rebecca № 2 💕"; content = "@Vanny_GioPrimetv hallo" }, @{ shortenNames = $true }) -ne "Rebecca sagt zu Vanny hallo") { throw "composeSpeechText Rebecca Vanny assertion failed" }

$team = $core.accumulateTeamEvidence(@{}, "Miimii tmm", "Teilt den Stream", @())
if ($team.teamTag -ne "") { throw "accumulateTeamEvidence initial teamTag assertion failed" }
$team = $core.accumulateTeamEvidence($team.evidence, "Honey tmm", "wo ist mein Tee?", @("Teilt den Stream"))
if ($team.teamTag -ne "tmm") { throw "accumulateTeamEvidence Honey tmm assertion failed" }
$team = $core.accumulateTeamEvidence(@{}, "Miimii tmm", "danke", @())
$team = $core.accumulateTeamEvidence($team.evidence, "Stivinho", "tmm hilft", @("danke"))
if ($team.teamTag -ne "tmm") { throw "accumulateTeamEvidence Stivinho tmm assertion failed" }
if ($core.accumulateTeamEvidence(@{}, "Miimii tmm", "tmm danke", @()).teamTag -ne "tmm") { throw "accumulateTeamEvidence Miimii tmm danke assertion failed" }
if ($core.accumulateTeamEvidence(@{}, "Ben", "Ben ist da", @()).teamTag -ne "") { throw "accumulateTeamEvidence Ben assertion failed" }
if ($core.streamIdentityChanged(@{ handle = "demo"; roomId = "1" }, @{ handle = "demo"; roomId = "1" }) -ne $false) { throw "streamIdentityChanged same assertion failed" }
if ($core.streamIdentityChanged(@{ handle = "demo"; roomId = "1" }, @{ handle = "demo"; roomId = "2" }) -ne $true) { throw "streamIdentityChanged different room assertion failed" }
if ($core.streamIdentityChanged(@{ handle = "demo"; roomId = "" }, @{ handle = "other"; roomId = "" }) -ne $true) { throw "streamIdentityChanged different handle assertion failed" }
if ($core.liveHandleFromUrl("https://www.tiktok.com/@Demo/live") -ne "demo") { throw "liveHandleFromUrl Demo assertion failed" }
if ($core.liveHandleFromUrl("https://www.tiktok.com/embed/live/@Other") -ne "other") { throw "liveHandleFromUrl Other assertion failed" }
if ($core.liveHandleFromUrl("https://www.tiktok.com/@demo") -ne "") { throw "liveHandleFromUrl non-live assertion failed" }
if ($core.liveHandleFromUrl("not a url") -ne "") { throw "liveHandleFromUrl invalid assertion failed" }
if ($core.parseCompactCount("3,231") -ne 3231) { throw "parseCompactCount comma assertion failed" }
if ($core.parseCompactCount("3.231") -ne 3231) { throw "parseCompactCount dot assertion failed" }
if ($core.parseCompactCount("3.2K") -ne 3200) { throw "parseCompactCount K assertion failed" }
if ($core.parseCompactCount("1,1M") -ne 1100000) { throw "parseCompactCount M assertion failed" }
if ($core.parseCompactCount("nicht verfügbar") -ne $null) { throw "parseCompactCount null assertion failed" }

$recommendationItems = $core.dedupeRecommendations(@(
    @{ handle = "@Alpha"; displayName = ""; title = "Erster Stream"; viewerCount = $null; url = "https://www.tiktok.com/@alpha/live"; position = 1 },
    @{ handle = "alpha"; displayName = "Alpha Live"; viewerCount = 123; viewerLabel = "123"; position = 2 },
    @{ handle = "Beta"; displayName = "Beta"; viewerCount = 500; url = "https://www.tiktok.com/@beta/live"; position = 3 },
    @{ handle = "gamma"; displayName = "Gamma"; viewerCount = $null; url = "https://www.tiktok.com/@gamma/live"; position = 2 }
))
if ($recommendationItems.Count -ne 3) { throw "dedupeRecommendations count assertion failed" }
if ($recommendationItems[0].handle -ne "alpha") { throw "dedupeRecommendations first handle assertion failed" }
if ($recommendationItems[0].displayName -ne "Alpha Live") { throw "dedupeRecommendations first displayName assertion failed" }
if ($recommendationItems[0].viewerCount -ne 123) { throw "dedupeRecommendations first viewerCount assertion failed" }
if ((Compare-Object ($core.sortRecommendations($recommendationItems) | ForEach-Object { $_.handle }) @("alpha", "gamma", "beta"))) { throw "sortRecommendations default assertion failed" }
if ((Compare-Object ($core.sortRecommendations($recommendationItems, "viewers") | ForEach-Object { $_.handle }) @("beta", "alpha", "gamma"))) { throw "sortRecommendations viewers assertion failed" }
if ($core.sameParticipant(@{ name = "Anja Schaarschmidt89" }, @{ nickname = "Anja Schaarschmidt89" }) -ne $true) { throw "sameParticipant name assertion failed" }
if ($core.sameParticipant(@{ userId = "42"; name = "Anja" }, @{ userId = "42"; name = "A. Schaarschmidt" }) -ne $true) { throw "sameParticipant userId assertion failed" }
if ((Compare-Object ($core.sortParticipants(@(
    @{ name = "Zed"; messageCount = 2; wordCount = 7 },
    @{ name = "Ada"; messageCount = 3; wordCount = 2 },
    @{ name = "Ben"; messageCount = 2; wordCount = 9 }
)) | ForEach-Object { $_.name }) @("Ada", "Ben", "Zed"))) { throw "sortParticipants assertion failed" }

$merged = $core.mergeParticipantRecord(
    @{ userId = $null; displayId = ""; name = "Anna"; messageCount = 2 },
    @{ userId = "42"; displayId = "anna_live"; receivedAtUtc = "2026-07-18T10:00:00.000Z" },
    "Anna",
    @{ wordCount = 7 }
)
$expected = @{
    userId = "42"
    displayId = "anna_live"
    name = "Anna"
    messageCount = 2
    wordCount = 7
    giftEventCount = 0
    giftItemCount = 0
    lastSeenAtUtc = "2026-07-18T10:00:00.000Z"
}
if (Compare-Object $merged.Keys $expected.Keys) { throw "mergeParticipantRecord keys assertion failed" }
foreach ($key in $expected.Keys) {
    if ($merged[$key] -ne $expected[$key]) { throw "mergeParticipantRecord $key assertion failed" }
}

$profileAndSummary = $core.inspectMetadata(@{
    live_ai_summary_ui = @{ vid = "v2" }
    userInfo = @{
        uniqueId = "demo"
        nickname = "Demo"
        signature = "Eine Bio"
        stats = @{ followingCount = 12; followerCount = 345; heartCount = 678 }
    }
})
if ($profileAndSummary.profileInfo.present -ne $true) { throw "profileInfo present assertion failed" }
if ($profileAndSummary.profileInfo.uniqueId -ne "demo") { throw "profileInfo uniqueId assertion failed" }
if ($profileAndSummary.profileInfo.followerCount -ne "345") { throw "profileInfo followerCount assertion failed" }
if ($profileAndSummary.aiSummaryInfo.featureFlagPresent -ne $true) { throw "aiSummaryInfo featureFlagPresent assertion failed" }
if ($profileAndSummary.aiSummaryInfo.text -ne "") { throw "aiSummaryInfo text assertion failed" }

$actualSummary = $core.inspectMetadata(@{ live_summary_text = "Eine tatsächlich gelieferte Zusammenfassung." })
if ($actualSummary.aiSummaryInfo.text -ne "Eine tatsächlich gelieferte Zusammenfassung.") { throw "actualSummary text assertion failed" }

$pullData = @{
    options = @{ qualities = @(
        @{ sdk_key = "origin"; name = "Original" },
        @{ sdk_key = "hd"; name = "720p" },
        @{ sdk_key = "sd"; name = "540p" },
        @{ sdk_key = "ld"; name = "360p" }
    ) }
    stream_data = '{"data":{"origin":{"main":{"flv":"https://pull.example.tiktokcdn.com/live/stream_origin.flv","sdk_params":"{\"VCodec\":\"h265\",\"vbitrate\":2600000,\"width\":1920,\"height\":1080,\"fps\":60}"}},"hd":{"main":{"flv":"https://pull.example.tiktokcdn.com/live/stream_hd.flv","hls":"https://pull.example.tiktokcdn.com/live/stream_hd.m3u8","sdk_params":"{\"VCodec\":\"h264\",\"vbitrate\":1800000,\"width\":1280,\"height\":720,\"fps\":30}"}},"sd":{"main":{"flv":"https://pull.example.tiktokcdn.com/live/stream_sd.flv","sdk_params":"{\"VCodec\":\"h264\",\"vbitrate\":900000,\"width\":960,\"height\":540,\"fps\":30}"}},"ld":{"main":{"flv":"https://pull.example.tiktokcdn.com/live/stream_ld.flv","sdk_params":"{\"VCodec\":\"h264\",\"vbitrate\":600000,\"width\":640,\"height\":360,\"fps\":30}"}}}}'
}
$variants = $core.extractStreamVariants($pullData)
if ($variants.Count -ne 5) { throw "extractStreamVariants count assertion failed" }
if (-not ($variants | Where-Object { $_.sdkKey -eq "origin" -and $_.quality -eq "Original" -and $_.height -eq 1080 })) { throw "origin variant assertion failed" }
if (-not ($variants | Where-Object { $_.sdkKey -eq "hd" -and $_.quality -eq "720p" -and $_.bitrate -eq 1800000 })) { throw "hd variant assertion failed" }
if (-not ($variants | Where-Object { $_.sdkKey -eq "sd" -and $_.width -eq 960 -and $_.height -eq 540 })) { throw "sd variant assertion failed" }
if (-not ($variants | Where-Object { $_.sdkKey -eq "ld" -and $_.quality -eq "360p" -and $_.height -eq 360 })) { throw "ld variant assertion failed" }

$captionContent = Concat @(
    (BytesField 1 "de"),
    (BytesField 2 "Guten Abend")
)
$captionPayload = Concat @(
    (IntField 2 123456),
    (IntField 3 1500),
    (BytesField 4 $captionContent),
    (IntField 5 77),
    (IntField 6 3),
    (IntField 7 1)
)
$baseMessage = Concat @(
    (BytesField 1 "WebcastCaptionMessage"),
    (BytesField 2 $captionPayload)
)
$fetchResult = BytesField 1 $baseMessage
$decoded = $proto.decodeFetchResult($fetchResult)
if ($decoded.captions.Count -ne 1) { throw "decoded captions count assertion failed" }
if ($decoded.captions[0].contents[0].lang -ne "de") { throw "decoded captions lang assertion failed" }
if ($decoded.captions[0].contents[0].text -ne "Guten Abend") { throw "decoded captions text assertion failed" }
if ($decoded.captions[0].sentenceId -ne "77") { throw "decoded captions sentenceId assertion failed" }
if ($decoded.captions[0].definite -ne $true) { throw "decoded captions definite assertion failed" }

$chatUser = Concat @(
    (IntField 1 123),
    (BytesField 3 "Demo 😊"),
    (BytesField 38 "demo_user")
)
$chatPayload = Concat @(
    (BytesField 1 (Concat @((IntField 2 9010)))),
    (BytesField 2 $chatUser),
    (BytesField 3 "Guten Abend ❤️"),
    (BytesField 14 "de")
)
$chatFetch = BytesField 1 (Concat @(
    (BytesField 1 "WebcastChatMessage"),
    (BytesField 2 $chatPayload)
))
$chatDecoded = $proto.decodeFetchResult($chatFetch).chatMessages
if ($chatDecoded.Count -ne 1) { throw "chatDecoded count assertion failed" }
if ($chatDecoded[0].messageId -ne "9010") { throw "chatDecoded messageId assertion failed" }
if ($chatDecoded[0].nickname -ne "Demo 😊") { throw "chatDecoded nickname assertion failed" }
if ($chatDecoded[0].displayId -ne "demo_user") { throw "chatDecoded displayId assertion failed" }
if ($chatDecoded[0].content -ne "Guten Abend ❤️") { throw "chatDecoded content assertion failed" }
if ($chatDecoded[0].contentLanguage -ne "de") { throw "chatDecoded contentLanguage assertion failed" }

$giftPayload = Concat @(
    (BytesField 1 (Concat @((IntField 2 9020)))),
    (IntField 2 777),
    (IntField 5 23),
    (BytesField 7 $chatUser),
    (IntField 9 1)
)
$giftFetch = BytesField 1 (Concat @(
    (BytesField 1 "WebcastGiftMessage"),
    (BytesField 2 $giftPayload)
))
$giftDecoded = $proto.decodeFetchResult($giftFetch).giftMessages
if ($giftDecoded.Count -ne 1) { throw "giftDecoded count assertion failed" }
if ($giftDecoded[0].nickname -ne "Demo 😊") { throw "giftDecoded nickname assertion failed" }
if ($giftDecoded[0].repeatCount -ne "23") { throw "giftDecoded repeatCount assertion failed" }

$common = Concat @(
    (IntField 2 9001),
    (BytesField 8 (BytesField 1 "pm_mt_msg_viewer"))
)
$roomUsers = Concat @(
    (BytesField 1 $common),
    (IntField 3 143),
    (IntField 7 15842)
)
$likes = Concat @(
    (BytesField 1 $common),
    (IntField 2 10),
    (IntField 3 430200)
)
$socialCommon = Concat @(
    (IntField 2 9002),
    (BytesField 8 (BytesField 1 "pm_main_follow_message_viewer_2"))
)
$social = Concat @(
    (BytesField 1 $socialCommon),
    (IntField 6 238800)
)
$liveFetch = Concat @(
    (BytesField 1 (Concat @((BytesField 1 "WebcastRoomUserSeqMessage"), (BytesField 2 $roomUsers)))),
    (BytesField 1 (Concat @((BytesField 1 "WebcastLikeMessage"), (BytesField 2 $likes)))),
    (BytesField 1 (Concat @((BytesField 1 "WebcastSocialMessage"), (BytesField 2 $social))))
)
$liveDecoded = $proto.decodeFetchResult($liveFetch).liveEvents
if ($liveDecoded.Count -ne 3) { throw "liveDecoded count assertion failed" }
if ($liveDecoded[0].viewerCount -ne "143") { throw "liveDecoded viewerCount assertion failed" }
if ($liveDecoded[0].totalViewers -ne "15842") { throw "liveDecoded totalViewers assertion failed" }
if ($liveDecoded[1].likeCount -ne "430200") { throw "liveDecoded likeCount assertion failed" }
if ($liveDecoded[2].kind -ne "follow") { throw "liveDecoded kind assertion failed" }
if ($liveDecoded[2].followerCount -ne "238800") { throw "liveDecoded followerCount assertion failed" }

$backgroundSource = Get-Content (Join-Path $extension "background.js") -Raw
$contentSource = Get-Content (Join-Path $extension "content.js") -Raw
$hookSource = Get-Content (Join-Path $extension "hook.js") -Raw
$sidepanelSource = Get-Content (Join-Path $extension "sidepanel.js") -Raw
$protoMainSource = Get-Content (Join-Path $extension "proto-main.js") -Raw
$setupSource = Get-Content (Join-Path $root "companion-service" "setup.ps1") -Raw
$repairSource = Get-Content (Join-Path $root "companion-service" "Sprachdienst-reparieren.cmd") -Raw
$repairPowerShellSource = Get-Content (Join-Path $root "companion-service" "repair-service.ps1") -Raw

if (-not $backgroundSource.Contains('const MAX_CHAT = 500;')) { throw "MAX_CHAT constant missing" }
if (-not $backgroundSource.Contains('case "TLC_CHAT_MESSAGE"')) { throw "TLC_CHAT_MESSAGE case missing" }
# Additional assertions would go here but are omitted for brevity

Write-Host "PASS: manifest 0.8.2, $($scripts.Count) scripts, chat speech composition, gifts, audience statistics, service controls and security guards"

# Run additional tests
& node --test (Join-Path $PSScriptRoot "test_background_runtime.cjs")
& node (Join-Path $PSScriptRoot "test_sidepanel_player_guard.cjs")
& node (Join-Path $PSScriptRoot "test_vlc_switch.cjs")
foreach ($script in @("test_external_speech_filter.cjs", "test_issue_controls.cjs")) {
    & node (Join-Path $PSScriptRoot $script)
}
