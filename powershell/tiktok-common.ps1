#!/usr/bin/env pwsh
# tiktok-common.js — portiert nach powershell
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.js
# Erzeugt: 2026-10-25 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Shared TikTok LIVE safety contract: handle normalization, per-CPU load
preflight, exact account LIVE selectors, strict HTTPS TikTok-CDN FLV
validation, and normalized extractor statuses.
#>

$DEFAULT_MAX_LOAD_PER_CPU = 1.5
$USERNAME_PATTERN = '^[A-Za-z0-9._]{1,24}$'
$FAILURE_STATUSES = @('offline', 'restricted', 'overloaded', 'dependency_missing', 'technical_error')

function Normalize-Username {
    param(
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        [object]$Raw
    )
    
    $username = if ($null -eq $Raw) { '' } else { "$Raw" }
    $username = $username.Trim().TrimStart('@')
    if ($username -notmatch $USERNAME_PATTERN) {
        throw "Invalid TikTok username; expected 1-24 letters, digits, dots, or underscores"
    }
    return $username
}

function Get-LoadState {
    param(
        [hashtable]$EnvVars = $env:PSItem
    )
    
    $cpuCount = [Math]::Max(1, (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors)
    $loadAvg = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue / 100
    
    $observed = if ($null -eq $EnvVars['TIKTOK_TEST_LOAD_PER_CPU']) {
        $loadAvg / $cpuCount
    } else {
        [double]$EnvVars['TIKTOK_TEST_LOAD_PER_CPU']
    }
    
    $maximum = if ($null -eq $EnvVars['TIKTOK_MAX_LOAD_PER_CPU']) {
        $DEFAULT_MAX_LOAD_PER_CPU
    } else {
        [double]$EnvVars['TIKTOK_MAX_LOAD_PER_CPU']
    }
    
    if (-not [double]::IsFinite($observed) -or -not [double]::IsFinite($maximum) -or $maximum -le 0) {
        throw "Invalid TikTok load configuration"
    }
    
    return @{
        Overloaded = $observed -gt $maximum
        LoadPerCpu = $observed
        Maximum = $maximum
    }
}

function Enforce-LoadLimit {
    param(
        [string]$Method
    )
    
    $state = Get-LoadState
    if (-not $state.Overloaded) {
        return $state
    }
    
    $output = @{
        status = 'overloaded'
        method = $Method
        loadPerCpu = [Math]::Round($state.LoadPerCpu, 3)
        maximum = $state.Maximum
        message = 'Host is overloaded; retry on another node or later'
    }
    
    [Console]::Error.WriteLine(($output | ConvertTo-Json -Compress))
    exit 75
}

function Get-LiveHrefSelectors {
    param(
        [string]$Username
    )
    
    $href = "/@$Username/live"
    return @("a[href=`"$href`"]", "a[href^=`"$href?`"]")
}

function Test-AllowedStreamUrl {
    param(
        [string]$Value
    )
    
    try {
        $url = [System.Uri]$Value
        $hostname = $url.Host.ToLower()
        return $url.Scheme -eq 'https' -and 
               $url.LocalPath.ToLower().Contains('.flv') -and
               $hostname -match '(^|\.)tiktokcdn(-[a-z0-9-]+)?\.com$'
    } catch {
        return $false
    }
}

function Test-SuccessfulStreamResponse {
    param(
        [int]$Status,
        [string]$Value
    )
    
    return ($Status -ge 200 -and $Status -lt 300) -and (Test-AllowedStreamUrl -Value $Value)
}

# Order matters: longer keys first so `_uhd_60` never matches as `hd_60`/`hd`.
$QUALITY_URL_PATTERN = '_((uhd_60)|(hd_60)|(origin)|(hd)|(sd)|(ld)|(ao))\.(flv|m3u8)'

function Get-QualityKeyFromUrl {
    param(
        [string]$Value
    )
    
    try {
        $url = [System.Uri]$Value
        $match = [regex]::Match($url.LocalPath.ToLower(), $QUALITY_URL_PATTERN)
        return if ($match.Success) { $match.Groups[1].Value } else { $null }
    } catch {
        return $null
    }
}

function Normalize-ExtractorResult {
    param(
        [object]$Value,
        [string]$Method,
        [string]$Username
    )
    
    $technicalError = @{
        success = $false
        status = 'technical_error'
        method = $Method
        username = $Username
        message = 'invalid extractor result'
    }
    
    if ($null -eq $Value -or $Value.GetType().Name -ne 'PSCustomObject' -or $Value -is [array]) {
        return $technicalError
    }
    
    if ($Value.success -eq $true) {
        if ($Value.status -ne 'live' -or -not (Test-AllowedStreamUrl -Value $Value.url)) {
            return $technicalError
        }
        return $Value.PSObject.Copy()
    }
    
    if ($Value.success -ne $false) {
        return $technicalError
    }
    
    $result = $Value.PSObject.Copy()
    $result | Add-Member -NotePropertyName 'success' -NotePropertyValue $false -Force
    $result | Add-Member -NotePropertyName 'status' -NotePropertyValue (
        if ($FAILURE_STATUSES -contains $Value.status) { $Value.status } else { 'technical_error' }
    ) -Force
    $result | Add-Member -NotePropertyName 'method' -NotePropertyValue (
        if ($Value.method -is [string]) { $Value.method } else { $Method }
    ) -Force
    $result | Add-Member -NotePropertyName 'username' -NotePropertyValue (
        if ($Value.username -is [string]) { $Value.username } else { $Username }
    ) -Force
    
    $result.PSObject.Properties.Remove('url')
    $result.PSObject.Properties.Remove('streams')
    $result.PSObject.Properties.Remove('allUrls')
    
    return $result
}

function Get-ClassifyFinalFailure {
    param(
        [array]$Results
    )
    
    $statuses = @()
    foreach ($result in $Results) {
        if ($result -and $FAILURE_STATUSES -contains $result.status) {
            $statuses += $result.status
        }
    }
    $statuses = $statuses | Sort-Object -Unique
    
    if ($statuses -contains 'overloaded') { return 'overloaded' }
    if ($statuses -contains 'restricted') { return 'restricted' }
    if ($statuses -contains 'technical_error') { return 'technical_error' }
    if ($statuses -contains 'offline') { return 'offline' }
    if ($statuses -contains 'dependency_missing') { return 'dependency_missing' }
    return 'technical_error'
}

function Get-ExitCodeForResult {
    param(
        [object]$Result
    )
    
    if ($Result -and $Result.success -eq $true -and $Result.status -eq 'live') { return 0 }
    if ($Result -and $Result.status -eq 'overloaded') { return 75 }
    if ($Result -and @('offline', 'restricted').Contains($Result.status)) { return 1 }
    return 2
}

function Get-ClassifyDirectLiveState {
    param(
        [hashtable]$Params
    )
    
    $username = $Params.username
    $currentPath = $Params.currentPath
    $title = $Params.title
    $bodyText = $Params.bodyText
    $successfulStreamResponse = $Params.successfulStreamResponse
    
    $expectedPath = "/@$username/live"
    if ($currentPath -ne $expectedPath) {
        return @{ status = 'offline'; reason = 'target live page redirected' }
    }
    if ($successfulStreamResponse) {
        return @{ status = 'live'; reason = 'successful TikTok CDN stream response' }
    }
    
    $normalizedBody = if ($bodyText) { ($bodyText -replace '\s+', ' ').ToLower() } else { '' }
    $normalizedTitle = if ($title) { $title.ToLower() } else { '' }
    $accountLiveTitle = $normalizedTitle.Contains("(@$($username.ToLower())) is live")
    
    $endedMarkers = @(
        'live has ended'
        'das live ist beendet'
        'live wurde beendet'
        'dieses live ist beendet'
        'stream has ended'
    )
    
    foreach ($marker in $endedMarkers) {
        if ($normalizedBody.Contains($marker)) {
            return @{ status = 'offline'; reason = 'target live page reports ended stream' }
        }
    }
    
    $restrictionMarkers = @(
        'dieses live enthält themen, die von einigen als unangenehm empfunden werden könnten'
        'melde dich an, um das beste aus deiner tiktok-erfahrung herauszuholen'
        'bei tiktok anmelden'
        'melde dich an für das volle live-erlebnis'
        'melde dich an für das vollständige erlebnis'
        'this live may contain content that could be uncomfortable'
        'log in to tiktok'
        'log in for the full live experience'
        'mature content'
        'age-restricted'
        'viewer discretion'
    )
    
    foreach ($marker in $restrictionMarkers) {
        if ($accountLiveTitle -and $normalizedBody.Contains($marker)) {
            return @{ status = 'restricted'; reason = 'target live page requires authentication' }
        }
    }
    
    if ($accountLiveTitle) {
        return @{
            status = 'restricted'
            reason = 'target is live but no accessible media response was available'
        }
    }
    
    return @{ status = 'offline'; reason = 'no account-specific live signal' }
}

function Test-ForcedOffline {
    param(
        [string]$Method,
        [string]$Username
    )
    
    if ($env:TIKTOK_TEST_OFFLINE -ne '1') {
        return $false
    }
    
    $output = @{
        success = $false
        status = 'offline'
        method = $Method
        username = $Username
        message = 'forced offline test mode'
    }
    
    [Console]::Error.WriteLine(($output | ConvertTo-Json -Compress))
    return $true
}

Export-ModuleMember -Function @(
    'Get-ClassifyDirectLiveState',
    'Get-ClassifyFinalFailure',
    'Enforce-LoadLimit',
    'Get-ExitCodeForResult',
    'Test-ForcedOffline',
    'Test-AllowedStreamUrl',
    'Test-SuccessfulStreamResponse',
    'Get-LiveHrefSelectors',
    'Get-LoadState',
    'Normalize-ExtractorResult',
    'Normalize-Username',
    'Get-QualityKeyFromUrl'
)
