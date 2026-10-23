#!/usr/bin/env pwsh
# test_icon_controls.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_icon_controls.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_icon_controls.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_icon_controls.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_icon_controls.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Join-Path $PSScriptRoot "../browser-extension"
$script = Get-Content -Path (Join-Path $root "icon-controls.js") -Raw

function harness($saved) {
    $elements = @{}
    function element($id) {
        if (-not $elements.ContainsKey($id)) {
            $el = @{
                dataset = @{}
                value = ""
                textContent = switch ($id) {
                    "player-play" { "Play" }
                    "player-mute" { "Mute" }
                    default { "On" }
                }
                handlers = @{}
                attributes = @{}
                classList = @{ add = {} }
                setAttribute = { param($k, $v) $this.attributes[$k] = $v }.GetNewClosure()
                getAttribute = { param($k) $this.attributes[$k] }.GetNewClosure()
                addEventListener = { param($n, $f) $this.handlers[$n] = $f }.GetNewClosure()
                before = { throw "Unexpected decorative control image" }
            }
            $elements[$id] = $el
        }
        return $elements[$id]
    }

    $storage = @{ "tlc-icon-style" = $saved }
    $document = @{
        documentElement = @{ dataset = @{} }
        body = @{}
        getElementById = ${function:element}.GetNewClosure()
        createElement = { element(New-Object System.Object) }.GetNewClosure()
        querySelectorAll = { $elements.Values }
    }

    # PowerShell doesn't have vm.runInNewContext equivalent
    # We'll simulate by executing the script with mocked environment
    $ExecutionContext.InvokeCommand.InvokeScript($script, $true, [System.Management.Automation.Language.ScriptBlock]::Create(""), @($document))

    return @{
        elements = $elements
        document = $document
        storage = $storage
        observer = {}
    }
}

foreach ($style in $null, "invalid", "plastisch", "glass", "linear") {
    $h = harness $style
    $expectedStyle = if (@("plastisch", "glass", "linear") -contains $style) { $style } else { "plastisch" }
    if ($h.document.documentElement.dataset.iconStyle -ne $expectedStyle) {
        throw "Assertion failed: expected '$expectedStyle', got '$($h.document.documentElement.dataset.iconStyle)'"
    }
    
    $picker = $h.elements["icon-style"]
    $picker.value = "glass"
    & $picker.handlers.change
    if ($h.storage["tlc-icon-style"] -ne "glass") {
        throw "Storage assertion failed"
    }
    if ($h.document.documentElement.dataset.iconStyle -ne "glass") {
        throw "Document style assertion failed"
    }
    
    foreach ($playing in $false, $true) {
        foreach ($muted in $false, $true) {
            $h.elements["player-play"].textContent = if ($playing) { "Stop" } else { "Play" }
            $h.elements["player-mute"].textContent = if ($muted) { "Unmute" } else { "Mute" }
            & $h.observer
            
            if ($h.elements["player-play"].dataset.controlIcon -ne $(if ($playing) { "stop" } else { "play" })) {
                throw "Player play icon assertion failed"
            }
            if ($h.elements["player-mute"].dataset.controlIcon -ne $(if ($muted) { "unmute" } else { "mute" })) {
                throw "Player mute icon assertion failed"
            }
        }
    }
}

$manifest = Get-Content -Path (Join-Path $root "icons/manifest.json") | ConvertFrom-Json
if ($manifest.Count -ne 60) {
    throw "Manifest count assertion failed"
}

foreach ($m in $manifest) {
    $bytes = [System.IO.File]::ReadAllBytes((Join-Path $root "icons/$($m.style)/$($m.component).png"))
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes) | ForEach-Object { "{0:x2}" -f $_ } | Join-String -Separator ""
    if ($hash -ne $m.sha256) {
        throw "Hash mismatch for $($m.component)"
    }
}

$h = harness "plastisch"
if ($h.elements["refresh-page-info"].attributes.title -ne "Refresh") {
    throw "Title assertion failed"
}
if ($h.elements["refresh-page-info"].attributes["aria-label"] -ne "Refresh") {
    throw "Aria-label assertion failed"
}

foreach ($id in "chat-count", "player-volume", "speech-volume", "limiter-strength", "recommendation-limit", "auto-chat-refresh-minutes") {
    if ($h.elements.ContainsKey($id)) {
        throw "$id must not receive a decorative icon"
    }
}

foreach ($item in @(
    @{ id = "player-play"; values = @("Play", "Stop") },
    @{ id = "player-mute"; values = @("Mute", "Unmute") },
    @{ id = "toggle-speech"; values = @("On", "Off") },
    @{ id = "toggle-hook"; values = @("On", "Off") }
)) {
    foreach ($value in $item.values) {
        $el = $h.elements[$item.id]
        $el.textContent = $value
        & $h.observer
        if (-not $el.attributes["aria-label"].EndsWith($value)) {
            throw "Aria-label does not end with $value"
        }
        if (-not $el.attributes.title.EndsWith($value)) {
            throw "Title does not end with $value"
        }
    }
}

$css = Get-Content -Path (Join-Path $root "icon-controls.css") -Raw
if ($css -notmatch "button\[data-control-icon\] \{[^}]*font-size:0") {
    throw "CSS pattern not found"
}

$sidepanel = Get-Content -Path (Join-Path $root "sidepanel.js") -Raw
if ($sidepanel -match "von bis zu \$\{requested\}") {
    throw "Invalid string found in sidepanel.js"
}

Write-Host "PASS: defaults, invalid stored style, three styles, persistence, 20 state combinations and 60 packaged asset hashes"
