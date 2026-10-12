#!/usr/bin/env pwsh
# tiktok-check-profile.js — portiert nach powershell
# Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-check-profile.js
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
TikTok Live Status Checker
.DESCRIPTION
Prüft ausschließlich profilgebundene Live-Indikatoren.
Der allgemeine TikTok-Navigationspunkt "LIVE" ist kein Statussignal.
Unterstützt @handle-Normalisierung und optionalen Node-Lastschutz
via TIKTOK_MAX_LOAD_PER_CPU (Exit-Code 75 bei NODE_BUSY).
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Username
)

$rawUsername = $Username
if (-not $rawUsername) {
    Write-Error "Usage: tiktok-check-profile.ps1 <username>"
    exit 1
}
$username = $rawUsername -replace '^@+', ''
if (-not $username) {
    Write-Error "Username must not be empty"
    exit 1
}

function Test-BusyNode {
    $limit = $env:TIKTOK_MAX_LOAD_PER_CPU
    if (-not ($limit -as [double]) -or [double]$limit -le 0) { return }

    $cpuCount = [Math]::Max(1, (Get-CimInstance Win32_Processor).Count)
    $normalizedLoad = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue / 100
    if ($normalizedLoad -gt $limit) {
        Write-Error "NODE_BUSY normalizedLoad=$([math]::Round($normalizedLoad, 2)) limit=$limit"
        exit 75
    }
}

Test-BusyNode

function Check-LiveStatus {
    param([string]$username)
    
    try {
        # Start Chrome with Playwright-like behavior using Selenium
        $chromeOptions = New-Object OpenQA.Selenium.Chrome.ChromeOptions
        $chromeOptions.AddArgument("--headless=new")
        $chromeOptions.AddArgument("--no-sandbox")
        $chromeOptions.AddArgument("--disable-dev-shm-usage")
        $chromeOptions.AddArgument("--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        $chromeOptions.AddArgument("--window-size=1920,1080")
        
        $driver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($chromeOptions)
        $driver.Manage().Timeouts().PageLoad = [System.TimeSpan]::FromSeconds(30)
        
        try {
            # Navigate to profile
            $driver.Navigate().GoToUrl("https://www.tiktok.com/@$username")
            
            # Wait for initial page build
            Start-Sleep -Seconds 2
            
            # Close GDPR banner - try multiple variants
            # Variant 1: "Verstanden" button (German)
            $verstandenButton = $null
            try {
                $verstandenButton = $driver.FindElementByCssSelector('button:has-text("Verstanden"), [data-e2e="cookie-banner-accept"], button:has-text("Accept")')
                if ($verstandenButton) {
                    $verstandenButton.Click()
                    Start-Sleep -Milliseconds 1000
                }
            } catch {}
            
            # Variant 2: Other cookie buttons
            $cookieSelectors = @(
                'button:has-text("Akzeptieren")',
                'button:has-text("Alle akzeptieren")',
                'button:has-text("Allow all")',
                'button:has-text("Accept all")',
                'button.TUXButton:has-text("Accept")',
                '[data-testid="cookie-policy-banner-accept"]'
            )
            
            foreach ($selector in $cookieSelectors) {
                try {
                    $btn = $driver.FindElementByCssSelector($selector)
                    if ($btn) {
                        $btn.Click()
                        Start-Sleep -Milliseconds 500
                        break
                    }
                } catch {}
            }
            
            # Wait for complete loading ("Erneute Veröffentlichungen" tab)
            Start-Sleep -Seconds 3
            
            # Additional wait for network idle state
            try {
                # This is a simplified version as Selenium doesn't have exact equivalent
                Start-Sleep -Seconds 2
            } catch {}
            
            # Additional wait for TikTok's live status check
            Start-Sleep -Seconds 2
            
            # Screenshot for debugging (optional, only if DEBUG=1)
            if ($env:DEBUG -eq '1') {
                $driver.GetScreenshot().SaveAsFile("/tmp/tiktok-$username.png", [OpenQA.Selenium.ScreenshotImageFormat]::Png)
            }
            
            # Check for LIVE indicators
            # Method 1: data-e2e="live-icon"
            $profileScopeElements = $driver.FindElementsByCssSelector('[data-e2e="creator-page-header"], [data-e2e="profile-avatar"]')
            $liveIconVisible = $false
            if ($profileScopeElements.Count -gt 0) {
                try {
                    $liveIcon = $profileScopeElements[0].FindElementByCssSelector('[data-e2e="live-icon"]')
                    $liveIconVisible = $liveIcon.Displayed
                } catch {}
            }
            
            # Method 2: LIVE text/badge (scoped to profile header/avatar)
            $liveBadgeVisible = $false
            if ($profileScopeElements.Count -gt 0) {
                try {
                    $liveBadges = $profileScopeElements[0].FindElementsByXPath(".//*[contains(text(), 'LIVE')]")
                    foreach ($badge in $liveBadges) {
                        if ($badge.Text -match "^LIVE$") {
                            $liveBadgeVisible = $badge.Displayed
                            break
                        }
                    }
                } catch {}
            }
            
            # Method 3: Red border around profile image - multiple selectors
            $profileSelectors = @(
                'img[data-e2e="avatar"]',
                'div[data-e2e="profile-avatar"] img',
                '[data-e2e="creator-page-header"] img[alt*="profile"]'
            )
            
            $hasLiveBorder = $false
            foreach ($selector in $profileSelectors) {
                try {
                    $profileImg = $driver.FindElementByCssSelector($selector)
                    if ($profileImg) {
                        # In PowerShell/Selenium we can't directly get computed styles like in JS
                        # We'll use a workaround by checking element attributes and classes
                        $elementClass = $profileImg.GetAttribute("class")
                        $parentClass = ""
                        if ($profileImg.FindElementByXPath("..")) {
                            $parentClass = $profileImg.FindElementByXPath("..").GetAttribute("class")
                        }
                        
                        # Check for known live indicator classes or patterns
                        if ($elementClass -match "live|red|border" -or $parentClass -match "live|red|border") {
                            $hasLiveBorder = $true
                            break
                        }
                    }
                } catch {}
            }
            
            # Method 4: Check for Live link or Live button
            $hasLiveLink = $false
            try {
                $liveLink = $driver.FindElementByCssSelector("a[href*='/@$username/live']")
                $hasLiveLink = $null -ne $liveLink
            } catch {}
            
            # Method 5: Check for pulsing red dot (Live indicator)
            $liveIndicatorVisible = $false
            if ($profileScopeElements.Count -gt 0) {
                try {
                    $liveIndicators = $profileScopeElements[0].FindElementsByCssSelector('[class*="live-indicator"], div[class*="LiveBadge"]')
                    if ($liveIndicators.Count -gt 0) {
                        $liveIndicatorVisible = $liveIndicators[0].Displayed
                    }
                } catch {}
            }
            
            $isLive = $liveIconVisible -or $liveBadgeVisible -or $hasLiveBorder -or $hasLiveLink -or $liveIndicatorVisible
            
            $result = @{
                username = $username
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
            
            Write-Output (ConvertTo-Json $result -Depth 5)
            
            return $isLive
            
        } finally {
            $driver.Quit()
        }
        
    } catch {
        $errorResult = @{
            error = $true
            message = $_.Exception.Message
            stack = $_.ScriptStackTrace
            timestamp = (Get-Date).ToUniversalTime().ToString("o")
        }
        Write-Error (ConvertTo-Json $errorResult -Depth 5)
        exit 1
    }
}

try {
    $isLive = Check-LiveStatus -username $username
    if ($isLive) {
        exit 0
    } else {
        exit 1
    }
} catch {
    $errorResult = @{
        error = $true
        message = $_.Exception.Message
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
    }
    Write-Error (ConvertTo-Json $errorResult -Depth 5)
    exit 1
}
