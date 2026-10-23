#!/usr/bin/env pwsh
# test_android_recovery.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_android_recovery.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_android_recovery.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_android_recovery.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_android_recovery.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

#Requires -Version 7.0

using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text
using namespace System.Text.RegularExpressions

$ErrorActionPreference = 'Stop'

# Mock Node.js modules and functions
function New-MockTestEnvironment {
    param(
        [bool]$IsIOS = $false
    )

    $now = 10000
    $plays = 0
    $seq = 0
    $timers = [Dictionary[int, PSCustomObject]]::new()
    $intervals = @()
    $listeners = @{}
    $events = @()
    
    $video = [PSCustomObject]@{
        clientWidth = 100
        clientHeight = 100
        currentTime = 1
        paused = $false
        ended = $false
        readyState = 4
        dataset = @{}
        addEventListener = { param($n, $f) $listeners[$n] = $f }
        play = { 
            $script:plays++
            return [System.Threading.Tasks.Task]::CompletedTask
        }
        textTracks = @()
    }

    $root = [PSCustomObject]@{
        location = [PSCustomObject]@{
            origin = 'https://www.tiktok.com'
            pathname = '/@creator/live'
        }
        crypto = [PSCustomObject]@{
            randomUUID = {
                $script:seq++
                return "11111111-1111-1111-1111-$('{0:D12}' -f $script:seq)"
            }
        }
        Date = [PSCustomObject]@{
            now = { return $script:now }
        }
        document = [PSCustomObject]@{
            scripts = @()
            body = [PSCustomObject]@{ innerText = '' }
            querySelectorAll = {
                param($s)
                if ($s -eq 'video') { return @($script:video) }
                return @()
            }
            querySelector = { return $null }
        }
        tlcBridge = [PSCustomObject]@{
            postMessage = {
                param($s)
                $events.Add(($s | ConvertFrom-Json))
            }
        }
        addEventListener = { param($n, $f) $listeners[$n] = $f }
        postMessage = {
            param($m)
            $events.Add($m)
        }
        setInterval = {
            param($f)
            $intervals += $f
            return $intervals.Count
        }
        clearInterval = { }
        setTimeout = {
            param($f, $ms)
            $id = ++$script:seq
            $timers[$id] = [PSCustomObject]@{
                f = $f
                at = $script:now + $ms
            }
            return $id
        }
        clearTimeout = {
            param($id)
            $timers.Remove($id)
        }
    }

    if ($IsIOS) {
        $root.PSObject.Properties.Remove('tlcBridge')
        $root | Add-Member -NotePropertyName 'webkit' -NotePropertyValue ([PSCustomObject]@{
            messageHandlers = [PSCustomObject]@{
                tlcBridge = [PSCustomObject]@{
                    postMessage = {
                        param($m)
                        $events.Add($m)
                    }
                }
            }
        })
    }

    $root | Add-Member -NotePropertyName 'top' -NotePropertyValue $root

    # Load android_recovery.js content
    $rawPath = Join-Path $PSScriptRoot '..\..\mobile\android\app\src\main\res\raw'
    $recoveryScriptPath = Join-Path $rawPath 'android_recovery.js'
    $scriptContent = Get-Content -Path $recoveryScriptPath -Raw
    
    # Execute script in current context (simplified)
    Invoke-Expression $scriptContent

    return [PSCustomObject]@{
        dispatch = {
            param($data)
            $mockEvent = [PSCustomObject]@{
                source = $root
                origin = $root.location.origin
                data = [PSCustomObject]@{
                    source = "tiktok-live-companion"
                }
            }
            
            # Merge properties from data
            foreach ($prop in $data.PSObject.Properties) {
                $mockEvent.data | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
            }
            
            if ($listeners.ContainsKey('message')) {
                $listeners['message'].Invoke($mockEvent)
            }
        }
        root = $root
        video = $video
        events = $events
        timers = $timers
        plays = { return $plays }
        tick = {
            param($ms)
            $script:now += $ms
            
            # Execute intervals
            foreach ($f in $intervals) {
                & $f
            }
            
            # Execute timers that are due
            $dueTimers = @()
            foreach ($kv in $timers.GetEnumerator()) {
                if ($kv.Value.at -le $now) {
                    $dueTimers += $kv.Key
                }
            }
            
            foreach ($id in $dueTimers) {
                $timer = $timers[$id]
                $timers.Remove($id)
                & $timer.f
            }
        }
        api = $root.TLC_MOBILE_RECOVERY
    }
}

# Test functions
function Assert-Equal {
    param($Actual, $Expected, $Message = "")
    if ($Actual -ne $Expected) {
        throw "Assertion failed: Expected '$Expected', but got '$Actual'. $Message"
    }
}

function Assert-Ok {
    param($Condition, $Message = "")
    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

function Assert-Match {
    param($Actual, $Pattern, $Message = "")
    if ($Actual -notmatch $Pattern) {
        throw "Assertion failed: '$Actual' does not match pattern '$Pattern'. $Message"
    }
}

function Assert-DeepEqual {
    param($Actual, $Expected, $Message = "")
    if (($Actual -join "") -ne ($Expected -join "")) {
        throw "Assertion failed: Objects are not equal. $Message"
    }
}

# Test cases
Write-Host "Running tests..."

# Test 1: player recovery waits configured interval once and never touches navigation
try {
    $s = New-MockTestEnvironment
    $s.api.command('set-auto-reconnect', @{enabled = $true; delaySeconds = 3})
    $s.api.recover('stalled')
    Assert-Equal $s.timers.Count 1
    $s.tick.Invoke(2999)
    Assert-Equal $s.plays.Invoke() 0
    $s.tick.Invoke(1)
    Assert-Equal $s.plays.Invoke() 1
    Assert-Equal $s.root.location.pathname '/@creator/live'
    Write-Host "✓ Test 1 passed"
} catch {
    Write-Host "✗ Test 1 failed: $_"
}

# Test 2: user pause and VLC cancel pending recovery
try {
    foreach ($cmd in @('pause', 'set-vlc-active')) {
        $s = New-MockTestEnvironment
        $s.api.command('set-auto-reconnect', @{enabled = $true})
        $s.api.recover('stalled')
        $s.api.command($cmd, @{active = $true})
        $s.tick.Invoke(4000)
        Assert-Equal $s.plays.Invoke() 0
    }
    Write-Host "✓ Test 2 passed"
} catch {
    Write-Host "✗ Test 2 failed: $_"
}

# Test 3: media progress cancels attempt without replacing media
try {
    $s = New-MockTestEnvironment
    $s.api.command('set-auto-reconnect', @{enabled = $true})
    $s.api.recover('waiting')
    $s.video.currentTime = 2
    $s.tick.Invoke(3000)
    Assert-Equal $s.plays.Invoke() 0
    Write-Host "✓ Test 3 passed"
} catch {
    Write-Host "✗ Test 3 failed: $_"
}

# Test 4: caption websocket activity expires independently from menu
try {
    $s = New-MockTestEnvironment
    & $s.dispatch @{
        type = "caption"
        caption = @{
            contents = @(@{lang = "de"; text = "test"})
        }
    }
    
    $captionEvents = $s.events | Where-Object { $_.type -eq "caption-state" }
    $lastEvent = $captionEvents[-1]
    Assert-Equal $lastEvent.payload.websocket $true
    
    $s.tick.Invoke(16000)
    
    $captionEvents = $s.events | Where-Object { $_.type -eq 'caption-state' }
    $e = $captionEvents[-1]
    Assert-Equal $e.payload.websocket $false
    Assert-Equal $e.payload.activityTtlMs 15000
    Write-Host "✓ Test 4 passed"
} catch {
    Write-Host "✗ Test 4 failed: $_"
}

# Test 5: Android uses byte-identical browser controller and protocol parser
try {
    $raw = Join-Path $PSScriptRoot '..\..\mobile\android\app\src\main\res\raw'
    $browserExt = Join-Path $PSScriptRoot '..\browser-extension'
    
    foreach ($filePair in @(
        @('hook_recovery.js', 'hook-recovery.js'),
        @('recovery_hook.js', 'hook.js'),
        @('proto_main.js', 'proto-main.js')
    )) {
        $mobileFile = Get-Content -Path (Join-Path $raw $filePair[0]) -Raw
        $browserFile = Get-Content -Path (Join-Path $browserExt $filePair[1]) -Raw
        Assert-DeepEqual $mobileFile $browserFile
    }
    Write-Host "✓ Test 5 passed"
} catch {
    Write-Host "✗ Test 5 failed: $_"
}

# Test 6: iOS WebKit bridge receives correlated recovery observations
try {
    $s = New-MockTestEnvironment -IsIOS $true
    $s.tick.Invoke(1000)
    
    $e = $s.events | Where-Object { $_.type -eq 'player-observation' } | Select-Object -First 1
    Assert-Ok ($null -ne $e)
    Assert-Equal $e.payload.frameKind 'top'
    Assert-Match $e.payload.documentId '^[a-f0-9-]{36}$'
    
    & $s.dispatch @{
        type = 'caption'
        caption = @{
            text = 'ios-caption'
        }
    }
    
    $captionEvents = $s.events | Where-Object { $_.type -eq 'caption' }
    $lastCaption = $captionEvents[-1]
    Assert-Equal $lastCaption.payload.text 'ios-caption'
    Write-Host "✓ Test 6 passed"
} catch {
    Write-Host "✗ Test 6 failed: $_"
}

# Test 7: iOS and Android inject identical recovery implementations
try {
    $raw = Join-Path $PSScriptRoot '..\..\mobile\android\app\src\main\res\raw'
    $ios = Join-Path $PSScriptRoot '..\..\mobile\ios\Resources'
    
    foreach ($filePair in @(
        @('android_recovery.js', 'mobile-recovery.js'),
        @('hook_recovery.js', 'hook-recovery.js'),
        @('recovery_hook.js', 'recovery-hook.js'),
        @('export_privacy.js', 'export-privacy.js'),
        @('proto_main.js', 'proto-main.js'),
        @('content_core.js', 'content-core.js')
    )) {
        $androidFile = Get-Content -Path (Join-Path $raw $filePair[0]) -Raw
        $iosFile = Get-Content -Path (Join-Path $ios $filePair[1]) -Raw
        Assert-DeepEqual $androidFile $iosFile
    }
    Write-Host "✓ Test 7 passed"
} catch {
    Write-Host "✗ Test 7 failed: $_"
}

# Test 8: Connection off stops Companion chat delivery, on resumes without touching player
try {
    foreach ($isIOS in @($false, $true)) {
        $s = New-MockTestEnvironment -IsIOS $isIOS
        $s.api.command('set-connection', @{enabled = $false})
        
        & $s.dispatch @{
            type = 'chat-message'
            chatMessage = @{
                content = 'hidden from Companion'
            }
        }
        
        $chatEvents = $s.events | Where-Object { $_.type -eq 'chat' }
        Assert-Equal $chatEvents.Count 0
        
        $s.api.command('set-connection', @{enabled = $true})
        
        & $s.dispatch @{
            type = 'chat-message'
            chatMessage = @{
                content = 'visible'
            }
        }
        
        $chatEvents = $s.events | Where-Object { $_.type -eq 'chat' }
        Assert-Equal $chatEvents.Count 1
        Assert-Equal $s.plays.Invoke() 0
    }
    Write-Host "✓ Test 8 passed"
} catch {
    Write-Host "✗ Test 8 failed: $_"
}

Write-Host "Tests completed."
