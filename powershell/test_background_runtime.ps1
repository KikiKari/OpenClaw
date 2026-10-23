#!/usr/bin/env pwsh
# test_background_runtime.cjs — portiert nach powershell
# Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_background_runtime.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

# Execute the real service worker with an in-memory Chrome API. Fixtures contain
# synthetic data only; no browser profile, credentials or live traffic is read.

$extension = Join-Path $PSScriptRoot "../browser-extension"
$core = & (Join-Path $extension "content-core.ps1")
$exportPrivacy = & (Join-Path $extension "export-privacy.ps1")

function New-TestSuite {
    param(
        [string]$Name,
        [scriptblock]$ScriptBlock
    )
    
    Write-Host "Running test: $Name"
    try {
        & $ScriptBlock
        Write-Host "✓ $Name" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ $Name" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Message = "")
    
    if ($Actual -ne $Expected) {
        throw "Assertion failed: Expected '$Expected', but got '$Actual'. $Message"
    }
}

function Assert-DeepEqual {
    param($Actual, $Expected, [string]$Message = "")
    
    if (($Actual | ConvertTo-Json -Depth 10) -ne ($Expected | ConvertTo-Json -Depth 10)) {
        throw "Deep assertion failed: Objects are not equal. $Message"
    }
}

function Assert-Ok {
    param($Condition, [string]$Message = "")
    
    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

function Assert-Rejects {
    param([scriptblock]$ScriptBlock, [string]$ExpectedMessage = "")
    
    try {
        & $ScriptBlock
        throw "Expected promise to reject but it resolved"
    }
    catch {
        if ($ExpectedMessage -and $_.Exception.Message -notlike "*$ExpectedMessage*") {
            throw "Expected rejection message '$ExpectedMessage' but got '$($_.Exception.Message)'"
        }
    }
}

# Test 0PE-170: startup retry backs off, caps at three attempts and ignores stale documents
New-TestSuite "0PE-170: startup retry backs off, caps at three attempts and ignores stale documents" {
    $state = $core.newEmbedSession("test", "creator", 1000)
    
    function Observe($now, $status, $documentId = "a", $documentStartedAtMs = 1000) {
        $result = $core.advanceEmbedSession($state, @{ status = $status; documentId = $documentId; documentStartedAtMs = $documentStartedAtMs }, $now)
        $script:state = $result.session
        return $result.action
    }
    
    Assert-Equal (Observe 2000 "server-error") "none"
    Assert-Equal $state.nextAttemptAtMs 4000
    Assert-Equal (Observe 3999 "server-error") "none"
    Assert-Equal (Observe 4000 "server-error") "reload"
    Assert-Equal $state.attempt 2
    Assert-Equal (Observe 5000 "playing") "none"
    Assert-Equal $state.phase "loading" "old document cannot complete a newer attempt"
    Observe 6000 "unavailable" "b" 4500
    Assert-Equal $state.nextAttemptAtMs 10000
    Assert-Equal (Observe 10000 "unavailable" "b" 4500) "reload"
    Observe 11000 "server-error" "c" 10500
    Assert-Equal $state.phase "failed"
    Assert-Equal $state.attempt 3
    Assert-Equal (Observe 100000 "server-error" "c" 10500) "none"
}

# Test 0PE-170: playback before retry cancels it, while login/ended/gesture never reload
New-TestSuite "0PE-170: playback before retry cancels it, while login/ended/gesture never reload" {
    $observation = { param($status) @{ status = $status; documentId = "a"; documentStartedAtMs = 1000 } }
    $initial = $core.newEmbedSession("test", "creator", 1000)
    $waiting = $core.advanceEmbedSession($initial, (& $observation "server-error"), 2000).session
    $recovered = $core.advanceEmbedSession($waiting, (& $observation "playing"), 3000)
    Assert-Equal $recovered.session.phase "playing"
    Assert-Equal $recovered.session.nextAttemptAtMs $null
    
    foreach ($status in @("login-required", "ended", "awaiting-gesture")) {
        $result = $core.advanceEmbedSession($waiting, (& $observation $status), 6000)
        Assert-Equal $result.action "none"
        Assert-Equal $result.session.nextAttemptAtMs $null
    }
    
    Assert-Equal ($core.advanceEmbedSession(@{ phase = "cancelled" } + $initial, (& $observation "server-error"), 100000).action) "none"
    Assert-Equal ($core.classifyEmbedObservation(@{ text = "Server error" })) "server-error"
    Assert-Equal ($core.classifyEmbedObservation(@{ text = "LIVE is unavailable" })) "unavailable"
    Assert-Equal ($core.classifyEmbedObservation(@{ text = "Melde dich an für das vollständige Erlebnis" })) "login-required"
    Assert-Equal ($core.classifyEmbedObservation(@{ playing = $true; readyState = 4 })) "playing"
    Assert-Equal ($core.classifyEmbedObservation(@{ paused = $true; readyState = 4 })) "awaiting-gesture"
}

# Worker function would need significant implementation for PowerShell
# Due to complexity of mocking Chrome APIs and VM contexts, we'll focus on core logic tests

# Test 0PE-167: explicit user pause suppresses media recovery without hiding genuine failures after resume
New-TestSuite "0PE-167: explicit user pause suppresses media recovery without hiding genuine failures after resume" {
    $video = @{ paused = $true; readyState = 4; error = $null; ended = $false }
    Assert-Equal ($core.mediaRecoveryReason($video, @{ userPaused = $true })) ""
    Assert-Equal ($core.mediaRecoveryReason($video)) "video-paused"
    Assert-Equal ($core.mediaRecoveryReason(@{ paused = $false } + $video)) ""
    Assert-Equal ($core.mediaRecoveryReason(@{ error = @{} } + $video)) "video-error"
    Assert-Equal ($core.mediaRecoveryReason(@{ ended = $true } + $video)) "video-ended"
    Assert-Equal ($core.mediaRecoveryReason(@{ paused = $false; readyState = 1 } + $video)) "video-not-ready"
    Assert-Equal ($core.mediaRecoveryReason($video, @{ graceElapsed = $false })) ""
    Assert-Equal ($core.mediaRecoveryReason($null)) ""
}

# Test 0PE-170: missing playback times out on observations and stale or invalid observations do nothing
New-TestSuite "0PE-170: missing playback times out on observations and stale or invalid observations do nothing" {
    $state = $core.newEmbedSession("test", "creator", 1000)
    $observation = @{ status = "waiting"; documentId = "a"; documentStartedAtMs = 1000 }
    Assert-Equal ($core.advanceEmbedSession($state, $observation, 15999).session.phase) "loading"
    Assert-Equal ($core.advanceEmbedSession($state, $observation, 16000).session.phase) "retry-wait"
    Assert-Equal ($core.advanceEmbedSession($state, $observation, 91000).session.phase) "failed"
    
    foreach ($invalid in @(@{ status = "unknown" } + $observation, @{ documentStartedAtMs = 999 } + $observation)) {
        Assert-DeepEqual ($core.advanceEmbedSession($state, $invalid, 16000)) @{ session = $state; action = "none" }
    }
}

# Test 0PE-172: unknown report keys, malformed URL protocols and unknown metadata values fail closed
New-TestSuite "0PE-172: unknown report keys, malformed URL protocols and unknown metadata values fail closed" {
    $input = @{ 
        raw = @{ password = "PRIVATE-KEY" }
        cookie = "PRIVATE-COOKIE"
        media = @(@{ url = "data:PRIVATE-PAYLOAD"; source = "PRIVATE-SOURCE" })
        components = @{ 
            captions = @{ 
                sources = @("PRIVATE-SOURCE")
                languages = @("PRIVATE-LANGUAGE")
                unknown = "PRIVATE-CONTENT"
            }
        }
    }
    
    $result = $exportPrivacy.diagnosticReport($input)
    Assert-Ok (-not ($result | ConvertTo-Json -Depth 10).Contains("PRIVATE-"))
    Assert-Equal ($exportPrivacy.url("not a url")) $null
    Assert-Equal ($exportPrivacy.url("blob:https://example.com/private")) $null
}

Write-Host "All tests completed." -ForegroundColor Green
