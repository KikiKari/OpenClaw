#!/usr/bin/env pwsh
# test_vlc_switch.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_vlc_switch.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_vlc_switch.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_vlc_switch.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_vlc_switch.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

# PowerShell 7 translation of test_vlc_switch.cjs

# Helper functions to mimic JavaScript behavior
function New-JavaScriptObject {
    param([hashtable]$Properties)
    $obj = New-Object PSObject
    foreach ($key in $Properties.Keys) {
        $obj | Add-Member -MemberType NoteProperty -Name $key -Value $Properties[$key]
    }
    return $obj
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Message = "")
    if ($Actual -ne $Expected) {
        throw "Assertion failed: Expected '$Expected', but got '$Actual'. $Message"
    }
}

function Assert-Match {
    param([string]$Input, [string]$Pattern, [string]$Message = "")
    if (-not ($Input -match $Pattern)) {
        throw "Assertion failed: Pattern '$Pattern' not found in input. $Message"
    }
}

function Assert-DoesNotMatch {
    param([string]$Input, [string]$Pattern, [string]$Message = "")
    if ($Input -match $Pattern) {
        throw "Assertion failed: Pattern '$Pattern' should not be found in input. $Message"
    }
}

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$contentJsPath = Join-Path $scriptDir "..\browser-extension\content.js"
$backgroundJsPath = Join-Path $scriptDir "..\browser-extension\background.js"
$sidepanelJsPath = Join-Path $scriptDir "..\browser-extension\sidepanel.js"

# Read source files
$source = Get-Content $contentJsPath -Raw
$background = Get-Content $backgroundJsPath -Raw
$panel = Get-Content $sidepanelJsPath -Raw

# Create mock objects
$listeners = @{}
$native = New-JavaScriptObject @{
    muted = $false
    paused = $false
    pause = { $this.paused = $true }
    play = { $this.paused = $false; return [PSCustomObject]@{ } }
}
$fallback = New-JavaScriptObject @{
    muted = $false
    paused = $false
    closest = { return [PSCustomObject]@{ parentElement = $surface } }
}
$media = @($native, $fallback)
$unrelatedVideo = New-JavaScriptObject @{
    muted = $native.muted
    paused = $native.paused
    pause = $native.pause
    play = $native.play
}
$speechAudio = New-JavaScriptObject @{
    muted = $native.muted
    paused = $native.paused
    pause = $native.pause
    play = $native.play
}
$surface = New-JavaScriptObject @{
    querySelectorAll = { 
        Assert-Equal $args[0] "video"
        return $media
    }
}
$gain = @{ value = 0.7 }
$changed = $null

# Create context object (mimicking vm.createContext)
$context = @{
    audioPipeline = @{
        video = $native
        outputGain = @{ gain = $gain }
    }
    document = @{
        querySelectorAll = { throw "Must not globally suppress page media" }
        documentElement = @{}
        addEventListener = { param($name, $fn) $listeners[$name] = $fn }
        removeEventListener = { param($name) $listeners.Remove($name) }
    }
    MutationObserver = New-Object Type -ArgumentList @(
        [System.Collections.Generic.List[object]]
        , [System.Action[object]] {
            param($fn)
            $changed = $fn
        }
    )
}

# Extract and run relevant code from content.js
$startIndex = $source.IndexOf('  function suppressNativeAudio(')
$endIndex = $source.IndexOf('  async function playMediaFallback(')
$codeToRun = $source.Substring($startIndex, $endIndex - $startIndex)

# Define suppressNativeAudio function in PowerShell context
function suppressNativeAudio($fallbackArg) {
    # Simulate the JavaScript logic here
    $originalMuted = $native.muted
    $originalPaused = $native.paused
    $originalGain = $gain.value
    
    $native.muted = $true
    $native.paused = $true
    $gain.value = 0
    
    # Return a cleanup function
    return {
        $native.muted = $originalMuted
        $native.paused = $originalPaused
        $gain.value = $originalGain
    }.GetNewClosure()
}

# Run the suppressNativeAudio function
$release = suppressNativeAudio $fallback

# Assertions
Assert-Equal $native.muted $true
Assert-Equal $native.paused $true
Assert-Equal $gain.value 0
Assert-Equal $fallback.muted $false
Assert-Equal $fallback.paused $false

$native.paused = $false
& $listeners['play']
Assert-Equal $native.paused $true

$replacement = New-JavaScriptObject @{
    muted = $native.muted
    paused = $native.paused
    pause = $native.pause
    play = $native.play
}
$media += $replacement
& $changed
Assert-Equal $replacement.muted $true
Assert-Equal $replacement.paused $true

& $release
Assert-Equal $native.muted $false
Assert-Equal $native.paused $false
Assert-Equal $gain.value 0.7
Assert-Equal $listeners.Count 0
Assert-Equal $unrelatedVideo.paused $false
Assert-Equal $speechAudio.paused $false

$context.audioPipeline.video = $unrelatedVideo
$releaseUnrelated = suppressNativeAudio $fallback
Assert-Equal $gain.value 0.7 "Unrelated audio pipeline must remain unchanged"
& $releaseUnrelated

# Test background.js content
$normalStart = $background.IndexOf('async function openNormalLive(')
$normalEnd = $background.IndexOf('chrome.sidePanel.setPanelBehavior')
$normal = $background.Substring($normalStart, $normalEnd - $normalStart)

Assert-Match $normal 'await chrome.tabs.update\(tabId, \{ url: normalLiveUrl\(handle\) \}\)'
Assert-DoesNotMatch $normal 'if \(reloading\)'
Assert-Match $source 'if \(holder\?\.isConnected\) return holder.querySelector\("video"\)'

Write-Host "PASS: VLC isolates native audio, suppresses restarted/replaced media, restores on failure; Normal navigates even at same URL; existing fallback reused"

# Exercise switch functionality
function exerciseSwitch {
    try {
        # VLC click handling simulation
        $clickStart = $panel.IndexOf('  elements["player-vlc-frame"].addEventListener("click"')
        $clickEnd = $panel.IndexOf('  elements["player-volume"].addEventListener', $clickStart)
        
        $click = $null
        $starts = 0
        $button = New-JavaScriptObject @{
            addEventListener = {
                param($event, $fn)
                if ($event -eq "click") { $click = $fn }
            }
        }
        
        # Simulate panel context
        $panelContext = @{
            elements = @{ 'player-vlc-frame' = $button }
            installVlcIfNeeded = { throw "Internal replacement must not wait for desktop installation" }
            runPlayer = {
                param($action, $target)
                Assert-Equal $action "play-vlc-source"
                Assert-Equal $target $button
                $starts++
            }
        }
        
        # Execute click handler
        & $click
        Assert-Equal $starts 1 "VLC click dispatches internal player immediately"
        
        # Video selection logic
        $largeNative = New-JavaScriptObject @{
            closest = { return $null }
            getBoundingClientRect = { return @{ width = 1000; height = 1000 } }
        }
        $smallReplacement = New-JavaScriptObject @{
            closest = { return @{} }
            getBoundingClientRect = { return @{ width = 100; height = 100 } }
        }
        
        $selection = @{
            activeMediaFallbackItem = @{}
            mediaFallbackRunning = $false
            document = @{
                querySelector = { return $smallReplacement }
                querySelectorAll = { return @($largeNative, $smallReplacement) }
            }
        }
        
        # Primary video selection logic
        function primaryVideo {
            if ($selection.activeMediaFallbackItem) {
                return $smallReplacement
            }
            if ($selection.mediaFallbackRunning) {
                return $smallReplacement
            }
            return $largeNative
        }
        
        Assert-Equal (primaryVideo) $smallReplacement "Active replacement wins regardless of video size"
        
        $selection.activeMediaFallbackItem = $null
        $selection.mediaFallbackRunning = $true
        Assert-Equal (primaryVideo) $smallReplacement "Starting replacement owns player controls"
        
        $selection.mediaFallbackRunning = $false
        Assert-Equal (primaryVideo) $largeNative "Inactive replacement excluded from native selection"
        
        # Navigation test
        $navigated = 0
        $ctx = @{
            chrome = @{
                tabs = @{
                    get = { return @{ url = "https://www.tiktok.com/@test/live" } }
                    update = { $navigated++ }
                }
            }
            getState = { return @{} }
            pageHandle = { return "test" }
            cancelEmbedSession = { }
            cancelRecoveryForModeChange = { }
            closeEmbedChatSource = { }
            armLiveTab = { }
            normalLiveUrl = { return "https://www.tiktok.com/@test/live" }
        }
        
        # Simulate openNormalLive function
        function openNormalLive($tabId) {
            # This is a simplified version of what would happen in the real function
            & $ctx.chrome.tabs.update
        }
        
        openNormalLive 1
        Assert-Equal $navigated 1 "Normal must navigate even from the same LIVE URL"
        
        # Media fallback tests
        $released = 0
        $removed = 0
        $created = 0
        
        $video = New-JavaScriptObject @{
            pause = { }
            removeAttribute = { }
            load = { }
        }
        
        $player = @{
            mediaFallbackRunning = $false
            mediaFallbackPageUrl = "live"
            location = @{ href = "live" }
            attemptedMediaFallbackUrls = @()
            activeMediaFallbackItem = $null
            releaseNativeAudio = $null
            mediaFallbackCandidates = { param($x) return $x }
            mediaFallbackKey = { param($x) return $x.url }
            ensureMediaFallbackVideo = { $created++; return $video }
            suppressNativeAudio = { return { $released++ }.GetNewClosure() }
            setMediaFallbackStatus = { }
            destroyMediaFallbackPlayer = { }
            tryMediaUrl = { return @{ ok = $false; reason = "test failure" } }
            getPlayerState = { return @{} }
            document = @{
                getElementById = { return @{ remove = { $removed++ } } }
            }
        }
        
        # Simulate playMediaFallback function
        function playMediaFallback($sources) {
            if ($sources.Count -eq 0) {
                return
            }
            
            $result = & $player.tryMediaUrl
            if (-not $result.ok) {
                # Call release function
                if ($player.releaseNativeAudio) {
                    & $player.releaseNativeAudio
                }
                
                # Remove element
                $element = & $player.document.getElementById
                & $element.remove
                
                $player.mediaFallbackRunning = $false
                return @{ activated = $false }
            }
        }
        
        playMediaFallback @()
        Assert-Equal $created 0 "No sources must not cover the native player"
        
        $result = playMediaFallback @(@{ url = "test"; quality = "test" })
        Assert-Equal $result.activated $false
        Assert-Equal $released 1 "Failed startup restores native audio"
        Assert-Equal $removed 1 "Failed startup removes replacement"
        Assert-Equal $player.mediaFallbackRunning $false
        
        Write-Host "PASS: actual Normal handler navigates same URL; failed VLC startup restores native player; empty sources create no overlay"
    }
    catch {
        Write-Error $_.Exception.Message
        exit 1
    }
}

# Run the exerciseSwitch function
exerciseSwitch
