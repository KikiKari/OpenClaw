#!/usr/bin/env pwsh
# test_sidepanel_player_guard.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_sidepanel_player_guard.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# PowerShell does not have direct equivalents for node:vm
# We'll simulate the behavior using script blocks and custom objects

# Read the source file
$sourcePath = Join-Path $PSScriptRoot "../browser-extension/sidepanel.js"
$source = Get-Content -Path $sourcePath -Raw -Encoding UTF8

# Extract the relevant function code
$start = $source.IndexOf("  async function refreshPlayer()")
$end = $source.IndexOf("  function setButtonBusy", $start)
if ($start -lt 0 -or $end -le $start) {
    throw "Could not find refreshPlayer function boundaries"
}

# Define a mock context object
$context = New-Object PSObject -Property @{
    activeTabId = 1
    activeIsTikTok = $true
    playerContextGeneration = 0
    send = $null
    renderPlayer = $null
}

# Variables to track state
$reply = $null
$calls = 0
$rendered = @()

# Define the mock send function
$context.send = {
    $script:calls++
    return [System.Threading.Tasks.Task]::Run({
        param($resolve)
        $script:reply = $resolve
    })
}.GetNewClosure()

# Define the mock renderPlayer function
$context.renderPlayer = {
    param($state)
    $script:rendered += $state
}.GetNewClosure()

# Extract and modify the function code to work in PowerShell
$functionCode = $source.Substring($start, $end - $start)

# Replace JavaScript syntax with PowerShell equivalents
$functionCode = $functionCode -replace "async function refreshPlayer\(\)", "function refreshPlayer()"
$functionCode = $functionCode -replace "await ", ""
$functionCode = $functionCode -replace "send\(\)", "& `$context.send"
$functionCode = $functionCode -replace "renderPlayer\(", "& `$context.renderPlayer ("

# Create a script block from the modified code
$scriptBlock = [ScriptBlock]::Create($functionCode)

try {
    # Execute the function in the context
    $pending = & $scriptBlock
    
    $context.activeTabId = 2
    & $reply @{response = @{playerState = @{playing = $true}}}
    
    # Wait for the task to complete
    if ($pending -is [System.Threading.Tasks.Task]) {
        $pending.Wait()
    }
    
    if ($rendered.Count -ne 0) {
        throw "Old tab response must be ignored"
    }
    
    $context.activeIsTikTok = $false
    & $scriptBlock
    
    if ($calls -ne 1) {
        throw "Non-TikTok tabs must not be polled"
    }
    
    $context.activeIsTikTok = $true
    $pending = & $scriptBlock
    & $reply @{response = @{playerState = @{playing = $true}}}
    
    if ($pending -is [System.Threading.Tasks.Task]) {
        $pending.Wait()
    }
    
    if ($rendered.Count -ne 1) {
        throw "Current tab response must render"
    }
    
    $pending = & $scriptBlock
    $context.activeTabId = 3
    $context.playerContextGeneration++
    $context.activeTabId = 2
    $context.playerContextGeneration++
    & $reply @{response = @{playerState = @{playing = $false}}}
    
    if ($pending -is [System.Threading.Tasks.Task]) {
        $pending.Wait()
    }
    
    if ($rendered.Count -ne 1) {
        throw "Returning to the same tab must not revive an old response"
    }
    
    if ($source -notmatch "async function refresh\(\)\s*\{\s*playerContextGeneration\+\+;") {
        throw "Context invalidation must precede asynchronous tab lookup"
    }
    
    Write-Host "PASS: stale tab response ignored, non-TikTok polling skipped, current response rendered"
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
