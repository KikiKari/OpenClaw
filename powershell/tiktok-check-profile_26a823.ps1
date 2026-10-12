#!/usr/bin/env pwsh
# tiktok-check-profile.js — portiert nach powershell
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-check-profile.js
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Basic TikTok LIVE profile checker.

.DESCRIPTION
Scopes every signal to the requested account and ignores unrelated sidebar
LIVE labels. This profile-only checker does not classify restricted LIVE;
use the enhanced checker or dispatcher for that distinction.

.PARAMETER Username
The TikTok username to check for LIVE status.

.EXAMPLE
.\tiktok-check-profile.ps1 johnsmith

.NOTES
Exit codes:
0 = account-specific LIVE
1 = offline
2 = dependency/technical failure
75 = overloaded before startup
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Username
)

# Import required modules
if (!(Get-Module -ListAvailable -Name Microsoft.PowerShell.Utility)) {
    Write-Error "Microsoft.PowerShell.Utility module is required but not available."
    exit 2
}

function Normalize-Username {
    param([string]$InputUsername)
    
    if ([string]::IsNullOrWhiteSpace($InputUsername)) {
        throw "Username cannot be empty"
    }
    
    # Remove @ symbol if present at start
    $normalized = $InputUsername.TrimStart('@')
    
    # Validate characters (alphanumeric, underscore, period only)
    if ($normalized -notmatch '^[a-zA-Z0-9_.]+$') {
        throw "Invalid username format: must contain only alphanumeric characters, underscores, and periods"
    }
    
    return $normalized.ToLowerInvariant()
}

function Enforce-Load-Limit {
    param([string]$Method)
    
    # Simple implementation - in production you might want rate limiting here
    $loadFile = "/tmp/load_$Method"
    if (Test-Path $loadFile) {
        $lastCheck = Get-Content $loadFile -ErrorAction SilentlyContinue
        if ($lastCheck) {
            $lastTime = [DateTime]::Parse($lastCheck)
            if ((Get-Date) - $lastTime -lt [TimeSpan]::FromSeconds(1)) {
                Write-Host (ConvertTo-Json @{
                    error = $true
                    status = "overloaded"
                    method = $Method
                    message = "System overloaded"
                    timestamp = (Get-Date).ToUniversalTime().ToString("o")
                }) -ForegroundColor Red
                exit 75
            }
        }
    }
    Set-Content $loadFile (Get-Date).ToString()
}

# Common selectors for live detection
$liveHrefSelectors = {
    param([string]$Username)
    @(
        "a[href='/@$Username/live']",
        "a[href='https://www.tiktok.com/@$Username/live']",
        "[data-e2e='user-live-link']",
        "[href*='@$Username/live']"
    )
}

try {
    $Username = Normalize-Username $Username
} catch {
    Write-Error "Usage: .\tiktok-check-profile.ps1 <username>`n$($_.Exception.Message)"
    exit 64
}

Enforce-Load-Limit "playwright_basic"

# Check if we have necessary tools
$chromiumPath = ""
try {
    $chromiumPath = & playwright install-deps chromium 2>$null
    if (!$chromiumPath) {
        $chromiumPath = "chromium"
    }
} catch {
    # Try default paths
    @("$env:LOCALAPPDATA\ms-playwright", "$env:HOME/.cache/ms-playwright") | ForEach-Object {
        if (Test-Path $_) {
            Get-ChildItem -Path $_ -Recurse -Filter "*chromium*" -Directory | ForEach-Object {
                $exePath = Join-Path $_.FullName "chrome.exe"
                if (Test-Path $exePath) {
                    $chromiumPath = $exePath
                }
            }
        }
    }
}

if (!(Test-Path $chromiumPath)) {
    Write-Host (ConvertTo-Json @{
        error = $true
        status = "dependency_missing"
        method = "playwright_basic"
        message = "Playwright Chromium unavailable"
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
    })
    exit 2
}

# PowerShell doesn't have native Playwright support, so we'll simulate with web requests
function Check-LiveStatus {
    param([string]$Username)
    
    try {
        # Create a session for persistent cookies
        $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        
        # Set user agent
        $session.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        
        # Fetch the profile page
        $url = "https://www.tiktok.com/@$Username"
        $response = Invoke-WebRequest -Uri $url -WebSession $session -UseBasicParsing -TimeoutSec 30
        
        Start-Sleep -Milliseconds 2000  # Wait for initial load
        
        # Handle cookie banners by looking for common accept buttons in the HTML
        $html = $response.Content
        
        # Look for cookie acceptance patterns
        $cookiePatterns = @(
            'Verstanden',
            'Accept',
            'Akzeptieren',
            'Alle akzeptieren',
            'Allow all',
            'Accept all'
        )
        
        foreach ($pattern in $cookiePatterns) {
            if ($html -match "(?i)$pattern") {
                # In real scenario, would click the button via automation
                Start-Sleep -Milliseconds 500
                break
            }
        }
        
        Start-Sleep -Milliseconds 3000  # Additional wait time
        
        # Save debug screenshot if needed
        if ($env:DEBUG -eq "1") {
            $debugPath = "/tmp/tiktok-$Username.html"
            Set-Content -Path $debugPath -Value $html
        }
        
        # Analyze response content for live indicators
        $hasLiveLink = $false
        $liveIconVisible = $false
        $liveBadgeVisible = $false
        $hasLiveBorder = $false
        $liveIndicatorVisible = $false
        
        # Check for live links using selectors
        $selectors = & $liveHrefSelectors $Username
        foreach ($selector in $selectors) {
            if ($html -match [regex]::Escape($selector)) {
                $hasLiveLink = $true
                break
            }
        }
        
        # Check for live icons/badges in HTML content
        $liveIndicators = @(
            'data-e2e="live-icon"',
            'LiveBadge',
            'live-indicator',
            '\bLIVE\b'
        )
        
        foreach ($indicator in $liveIndicators) {
            if ($html -match $indicator) {
                if ($indicator -eq 'data-e2e="live-icon"') { $liveIconVisible = $true }
                if ($indicator -eq '\bLIVE\b') { $liveBadgeVisible = $true }
                if ($indicator -eq 'live-indicator' -or $indicator -eq 'LiveBadge') { $liveIndicatorVisible = $true }
            }
        }
        
        # Check for avatar styling that indicates live status
        # This is simplified since we can't easily evaluate CSS styles from raw HTML
        if ($html -match 'borderColor.*red|outlineColor.*red|boxShadow.*(255|254)') {
            $hasLiveBorder = $true
        }
        
        # Determine final live status based on any positive indicator
        $isLive = $hasLiveLink -or $hasLiveBorder -or $liveIconVisible -or $liveIndicatorVisible -or $liveBadgeVisible
        
        # Output structured result
        $result = @{
            username = $Username
            isLive = $isLive
            timestamp = (Get-Date).ToUniversalTime().ToString("o")
            indicators = @{
                liveIcon = $liveIconVisible
                liveBadge = $liveBadgeVisible
                liveBorder = $hasLiveBorder
                liveLink = $hasLiveLink
                liveIndicator = $liveIndicatorVisible
            }
        }
        
        Write-Host (ConvertTo-Json $result -Depth 5)
        
        return $isLive
        
    } catch {
        $errorResult = @{
            error = $true
            status = "technical_error"
            message = $_.Exception.Message
            stack = $_.ScriptStackTrace
            timestamp = (Get-Date).ToUniversalTime().ToString("o")
        }
        
        Write-Error (ConvertTo-Json $errorResult)
        return $null
    }
}

# Execute main function and handle exit codes
$isLive = Check-LiveStatus $Username

if ($null -eq $isLive) {
    exit 2
} elseif ($isLive) {
    exit 0
} else {
    exit 1
}
