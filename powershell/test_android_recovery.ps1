#!/usr/bin/env pwsh
# test_android_recovery.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_android_recovery.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_android_recovery.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_android_recovery.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_android_recovery.cjs
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

#Requires -Version 7.0

using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text
using namespace System.Text.Json

$ErrorActionPreference = 'Stop'

# Mocking framework for testing JavaScript logic in PowerShell
class MockWindow {
    [object]$location = @{ origin = 'https://www.tiktok.com'; pathname = '/@creator/live' }
    [object]$crypto = @{ randomUUID = { return "11111111-1111-1111-1111-$($this.seq.ToString('D12'))" } }
    [object]$document = @{ scripts = @(); body = @{ innerText = '' }; querySelectorAll = { param($s) if ($s -eq 'video') { return @($this.video) } else { return @() } }; querySelector = { return $null } }
    [object]$tlcBridge = @{ postMessage = { param($s) $this.events.Add([JsonSerializer]::Deserialize($s, [object])) } }
    [object]$webkit = $null
    [List[object]]$events = [List[object]]::new()
    [hashtable]$listeners = @{}
    [int]$now = 10000
    [int]$plays = 0
    [int]$seq = 0
    [Dictionary[int, object]]$timers = [Dictionary[int, object]]::new()
    [List[scriptblock]]$intervals = [List[scriptblock]]::new()
    [object]$video = @{
        clientWidth = 100
        clientHeight = 100
        currentTime = 1
        paused = $false
        ended = $false
        readyState = 4
        dataset = @{}
        addEventListener = { param($n, $f) $this.listeners[$n] = $f }.GetNewClosure()
        play = { $this.plays++ }.GetNewClosure()
        textTracks = @()
    }

    MockWindow([bool]$ios) {
        if ($ios) {
            $this.tlcBridge = $null
            $this.webkit = @{ messageHandlers = @{ tlcBridge = @{ postMessage = { param($m) $this.events.Add($m) }.GetNewClosure() } } }
        }
        $this.document.video = $this.video
        $rawPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'mobile/android/app/src/main/res/raw'
        $scriptContent = Get-Content -Path (Join-Path $rawPath 'android_recovery.js') -Raw
        Invoke-Expression -Command $scriptContent
        $this.top = $this
    }

    [void] dispatch([object]$data) {
        $eventData = @{
            source = $this
            origin = $this.location.origin
            data = @{ source = "tiktok-live-companion" } + $data
        }
        if ($this.listeners.ContainsKey('message')) {
            & $this.listeners['message'] $eventData
        }
    }

    [void] tick([int]$ms) {
        $this.now += $ms
        foreach ($interval in $this.intervals.ToArray()) {
            & $interval
        }
        $toRemove = @()
        foreach ($kv in $this.timers.GetEnumerator()) {
            if ($kv.Value.at -le $this.now) {
                & $kv.Value.f
                $toRemove += $kv.Key
            }
        }
        foreach ($key in $toRemove) {
            $this.timers.Remove($key)
        }
    }

    [void] postMessage([object]$m) {
        $this.events.Add($m)
    }

    [void] addEventListener([string]$n, [scriptblock]$f) {
        $this.listeners[$n] = $f
    }

    [object] setInterval([scriptblock]$f) {
        $this.intervals.Add($f)
        return $this.intervals.Count
    }

    [void] clearInterval() {}

    [object] setTimeout([scriptblock]$f, [int]$ms) {
        $id = ++$this.seq
        $this.timers[$id] = @{ f = $f; at = $this.now + $ms }
        return $id
    }

    [void] clearTimeout([int]$id) {
        $this.timers.Remove($id)
    }
}

# Test functions
function Test-PlayerRecoveryWaitsConfiguredInterval {
    $s = [MockWindow]::new($false)
    $s.TLC_MOBILE_RECOVERY.command('set-auto-reconnect', @{ enabled = $true; delaySeconds = 3 })
    $s.TLC_MOBILE_RECOVERY.recover('stalled')
    if ($s.timers.Count -ne 1) { throw "Expected 1 timer, got $($s.timers.Count)" }
    $s.tick(2999)
    if ($s.plays -ne 0) { throw "Expected 0 plays after 2999ms, got $($s.plays)" }
    $s.tick(1)
    if ($s.plays -ne 1) { throw "Expected 1 play after 3000ms, got $($s.plays)" }
    if ($s.location.pathname -ne '/@creator/live') { throw "Location changed unexpectedly" }
}

function Test-UserPauseAndVLCCancelPendingRecovery {
    foreach ($cmd in @('pause', 'set-vlc-active')) {
        $s = [MockWindow]::new($false)
        $s.TLC_MOBILE_RECOVERY.command('set-auto-reconnect', @{ enabled = $true })
        $s.TLC_MOBILE_RECOVERY.recover('stalled')
        $s.TLC_MOBILE_RECOVERY.command($cmd, @{ active = $true })
        $s.tick(4000)
        if ($s.plays -ne 0) { throw "Expected 0 plays after $cmd command, got $($s.plays)" }
    }
}

function Test-MediaProgressCancelsAttemptWithoutReplacingMedia {
    $s = [MockWindow]::new($false)
    $s.TLC_MOBILE_RECOVERY.command('set-auto-reconnect', @{ enabled = $true })
    $s.TLC_MOBILE_RECOVERY.recover('waiting')
    $s.video.currentTime = 2
    $s.tick(3000)
    if ($s.plays -ne 0) { throw "Expected 0 plays when media progresses, got $($s.plays)" }
}

function Test-CaptionWebsocketActivityExpiresIndependentlyFromMenu {
    $s = [MockWindow]::new($false)
    $s.dispatch(@{ type = "caption"; caption = @{ contents = @(@{ lang = "de"; text = "test" }) } })
    $websocketEvents = $s.events | Where-Object { $_.type -eq "caption-state" }
    $lastEvent = $websocketEvents[-1]
    if ($lastEvent.payload.websocket -ne $true) { throw "Expected initial websocket state to be true" }
    $s.tick(16000)
    $updatedEvents = $s.events | Where-Object { $_.type -eq 'caption-state' }
    $finalEvent = $updatedEvents[-1]
    if ($finalEvent.payload.websocket -ne $false) { throw "Expected expired websocket state to be false" }
    if ($finalEvent.payload.activityTtlMs -ne 15000) { throw "Expected TTL to be 15000, got $($finalEvent.payload.activityTtlMs)" }
}

function Test-AndroidUsesByteIdenticalBrowserControllerAndProtocolParser {
    $rawDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'mobile/android/app/src/main/res/raw'
    $browserExtDir = Join-Path $PSScriptRoot '../browser-extension'
    
    $pairs = @(
        @('hook_recovery.js', 'hook-recovery.js'),
        @('recovery_hook.js', 'hook.js'),
        @('proto_main.js', 'proto-main.js')
    )
    
    foreach ($pair in $pairs) {
        $mobileFile = Get-Content -Path (Join-Path $rawDir $pair[0]) -Raw
        $browserFile = Get-Content -Path (Join-Path $browserExtDir $pair[1]) -Raw
        if ($mobileFile -ne $browserFile) { 
            throw "Files $($pair[0]) and $($pair[1]) differ"
        }
    }
}

function Test-iOSWebKitBridgeReceivesCorrelatedRecoveryObservations {
    $s = [MockWindow]::new($true)
    $s.tick(1000)
    $e = $s.events | Where-Object { $_.type -eq 'player-observation' } | Select-Object -First 1
    if (-not $e) { throw "No player observation event found" }
    if ($e.payload.frameKind -ne 'top') { throw "Expected frameKind 'top', got '$($e.payload.frameKind)'" }
    if ($e.payload.documentId -notmatch '^[a-f0-9-]{36}$') { throw "Invalid documentId format: $($e.payload.documentId)" }
    $s.dispatch(@{ type = 'caption'; caption = @{ text = 'ios-caption' } })
    $captionEvents = $s.events | Where-Object { $_.type -eq 'caption' }
    $lastCaption = $captionEvents[-1]
    if ($lastCaption.payload.text -ne 'ios-caption') { throw "Caption text mismatch" }
}

function Test-iOSAndAndroidInjectIdenticalRecoveryImplementations {
    $rawDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'mobile/android/app/src/main/res/raw'
    $iosDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'mobile/ios/Resources'
    
    $pairs = @(
        @('android_recovery.js', 'mobile-recovery.js'),
        @('hook_recovery.js', 'hook-recovery.js'),
        @('recovery_hook.js', 'recovery-hook.js'),
        @('export_privacy.js', 'export-privacy.js'),
        @('proto_main.js', 'proto-main.js'),
        @('content_core.js', 'content-core.js')
    )
    
    foreach ($pair in $pairs) {
        $androidFile = Get-Content -Path (Join-Path $rawDir $pair[0]) -Raw
        $iosFile = Get-Content -Path (Join-Path $iosDir $pair[1]) -Raw
        if ($androidFile -ne $iosFile) { 
            throw "Files $($pair[0]) and $($pair[1]) differ between platforms"
        }
    }
}

function Test-ConnectionOffStopsCompanionChatDelivery {
    foreach ($ios in @($false, $true)) {
        $s = [MockWindow]::new($ios)
        $s.TLC_MOBILE_RECOVERY.command('set-connection', @{ enabled = $false })
        $s.dispatch(@{ type = 'chat-message'; chatMessage = @{ content = 'hidden from Companion' } })
        $chatEvents = $s.events | Where-Object { $_.type -eq 'chat' }
        if ($chatEvents.Count -ne 0) { throw "Expected no chat events when connection disabled, got $($chatEvents.Count)" }
        $s.TLC_MOBILE_RECOVERY.command('set-connection', @{ enabled = $true })
        $s.dispatch(@{ type = 'chat-message'; chatMessage = @{ content = 'visible' } })
        $updatedChatEvents = $s.events | Where-Object { $_.type -eq 'chat' }
        if ($updatedChatEvents.Count -ne 1) { throw "Expected 1 chat event when connection enabled, got $($updatedChatEvents.Count)" }
        if ($s.plays -ne 0) { throw "Player should not have been touched, plays: $($s.plays)" }
    }
}

# Run all tests
try {
    Test-PlayerRecoveryWaitsConfiguredInterval
    Write-Host "✓ Player recovery waits configured interval test passed"
} catch {
    Write-Error "✗ Player recovery waits configured interval test failed: $($_.Exception.Message)"
}

try {
    Test-UserPauseAndVLCCancelPendingRecovery
    Write-Host "✓ User pause and VLC cancel pending recovery test passed"
} catch {
    Write-Error "✗ User pause and VLC cancel pending recovery test failed: $($_.Exception.Message)"
}

try {
    Test-MediaProgressCancelsAttemptWithoutReplacingMedia
    Write-Host "✓ Media progress cancels attempt without replacing media test passed"
} catch {
    Write-Error "✗ Media progress cancels attempt without replacing media test failed: $($_.Exception.Message)"
}

try {
    Test-CaptionWebsocketActivityExpiresIndependentlyFromMenu
    Write-Host "✓ Caption websocket activity expires independently from menu test passed"
} catch {
    Write-Error "✗ Caption websocket activity expires independently from menu test failed: $($_.Exception.Message)"
}

try {
    Test-AndroidUsesByteIdenticalBrowserControllerAndProtocolParser
    Write-Host "✓ Android uses byte-identical browser controller and protocol parser test passed"
} catch {
    Write-Error "✗ Android uses byte-identical browser controller and protocol parser test failed: $($_.Exception.Message)"
}

try {
    Test-iOSWebKitBridgeReceivesCorrelatedRecoveryObservations
    Write-Host "✓ iOS WebKit bridge receives correlated recovery observations test passed"
} catch {
    Write-Error "✗ iOS WebKit bridge receives correlated recovery observations test failed: $($_.Exception.Message)"
}

try {
    Test-iOSAndAndroidInjectIdenticalRecoveryImplementations
    Write-Host "✓ iOS and Android inject identical recovery implementations test passed"
} catch {
    Write-Error "✗ iOS and Android inject identical recovery implementations test failed: $($_.Exception.Message)"
}

try {
    Test-ConnectionOffStopsCompanionChatDelivery
    Write-Host "✓ Connection off stops Companion chat delivery test passed"
} catch {
    Write-Error "✗ Connection off stops Companion chat delivery test failed: $($_.Exception.Message)"
}
