#!/usr/bin/env pwsh
# browser-session.mjs — portiert nach powershell
# Quelle: javascript, Onboarding@main:scripts/browser-session.mjs
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Persistente Browser-Sitzung der Sandbox.

.DESCRIPTION
Zweck: Plattformen ohne (nutzbare) API — WaveSpeed-Konsole, Perplexity,
Canva, Stock-Portale — erfordern einen echten Web-Login. Diese Sitzung
speichert Cookies/LocalStorage DAUERHAFT in einem user-data-dir, akzeptiert
Cookie-Banner automatisch und bleibt über Skript-Läufe hinweg angemeldet.

Profil-Verzeichnis: <repo>/.browser-profile (gitignored — enthält Secrets).

Nutzung (immer unter Xvfb, damit echtes Chrome mit Codecs läuft):
  xvfb-run -a pwsh scripts/browser-session.ps1 open <URL>          # öffnen, Cookies akzeptieren, Screenshot
  xvfb-run -a pwsh scripts/browser-session.ps1 login <URL> [--user-field ..] [--pass-field ..] [--env-user X] [--env-pass Y]
  xvfb-run -a pwsh scripts/browser-session.ps1 shot <URL> [--out file.png] [--wait ms] [--full]
  xvfb-run -a pwsh scripts/browser-session.ps1 state                 # gespeicherte Cookies auflisten (Domains)

Die Sitzung wird NICHT geschlossen-und-verworfen: das Profil bleibt auf Platte.
#>

param(
    [string]$Command,
    [string]$Target,
    [string[]]$RestArgs
)

# Hilfsfunktionen für Flag-Parsing
function Get-FlagValue {
    param([string]$Name, [string]$Default = $null)
    
    $index = [System.Array]::IndexOf($RestArgs, "--$Name")
    if ($index -ge 0 -and ($index + 1) -lt $RestArgs.Count) {
        return $RestArgs[$index + 1]
    }
    return $Default
}

function Test-HasFlag {
    param([string]$Name)
    return ($RestArgs -contains "--$Name")
}

# Pfad-Konfiguration
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RepoRoot = Join-Path $ScriptDir ".."
$ProfileDir = if ($env:BROWSER_PROFILE_DIR) { $env:BROWSER_PROFILE_DIR } else { Join-Path $RepoRoot ".browser-profile" }
$ChromePath = @("/usr/bin/google-chrome-stable", "/usr/bin/google-chrome") | Where-Object { Test-Path $_ } | Select-Object -First 1

# Sicherstellen, dass das Profilverzeichnis existiert
if (!(Test-Path $ProfileDir)) {
    New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
}

# .env laden (nur für login-Credentials; nichts wird geloggt)
function Load-EnvironmentFile {
    $envFile = Join-Path $RepoRoot ".env"
    $result = @{}
    
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^\s*([A-Z0-9_]+)\s*=\s*"?([^"]*)"?') {
                $result[$matches[1]] = $matches[2]
            }
        }
    }
    
    return $result
}

# Häufige Cookie-Consent-Buttons klicken (mehrsprachig, best effort)
function Accept-Cookies {
    param([object]$Page)
    
    $labels = @(
        "Accept all", "Accept All", "Alle akzeptieren", "Accept all cookies",
        "Alle Cookies akzeptieren", "I agree", "Ich stimme zu", "Zustimmen",
        "Allow all", "Akzeptieren", "Accept", "Got it", "Agree"
    )
    
    foreach ($name in $labels) {
        try {
            $btn = $Page | Invoke-PlaywrightMethod -Name "getByRole" -Arguments @("button", @{ name = $name; exact = $false })
            $firstBtn = $btn | Invoke-PlaywrightMethod -Name "first"
            
            if ($firstBtn | Invoke-PlaywrightMethod -Name "isVisible" -Arguments @(@{ timeout = 800 })) {
                $firstBtn | Invoke-PlaywrightMethod -Name "click" -Arguments @(@{ timeout = 1500 })
                return $name
            }
        } catch {
            # weiter
        }
    }
    
    # Generische Consent-IDs
    $selectors = @("#onetrust-accept-btn-handler", "[aria-label*='accept' i]", "button[title*='accept' i]")
    foreach ($sel in $selectors) {
        try {
            $el = $Page | Invoke-PlaywrightMethod -Name "locator" -Arguments @($sel)
            $firstEl = $el | Invoke-PlaywrightMethod -Name "first"
            
            if ($firstEl | Invoke-PlaywrightMethod -Name "isVisible" -Arguments @(@{ timeout = 500 })) {
                $firstEl | Invoke-PlaywrightMethod -Name "click" -Arguments @(@{ timeout = 1500 })
                return $sel
            }
        } catch {
            # weiter
        }
    }
    
    return $null
}

# Hauptlogik
try {
    # Proxy-Konfiguration
    $socks = Get-FlagValue -Name "socks" -Default $null
    $proxyServer = if ($socks) {
        "socks5://$socks"
    } else {
        $env:HTTPS_PROXY ?? $env:https_proxy ?? $null
    }
    
    # Browser-Kontext erstellen
    $launchArgs = @(
        "--no-sandbox",
        "--autoplay-policy=no-user-gesture-required",
        "--disable-blink-features=AutomationControlled"
    )
    
    if ($proxyServer) {
        $launchArgs += "--ssl-version-max=tls1.2"
    }
    
    $contextOptions = @{
        headless = $false
        executablePath = $ChromePath
        viewport = @{ width = 1440; height = 900 }
        acceptDownloads = $true
        ignoreHTTPSErrors = (Test-HasFlag -Name "insecure")
        args = $launchArgs
    }
    
    if ($proxyServer) {
        $contextOptions.proxy = @{
            server = $proxyServer
            bypass = "localhost,127.0.0.1,::1"
        }
    }
    
    # Starte den persistenten Kontext
    Import-Module Playwright
    $context = New-PlaywrightBrowserContext -BrowserType Chromium -UserDataDir $ProfileDir @contextOptions
    $pages = $context | Invoke-PlaywrightMethod -Name "pages"
    $page = if ($pages.Count -gt 0) { $pages[0] } else { $context | Invoke-PlaywrightMethod -Name "newPage" }
    
    switch ($Command) {
        "state" {
            $cookies = $context | Invoke-PlaywrightMethod -Name "cookies"
            $domains = $cookies | ForEach-Object { $_.domain } | Sort-Object -Unique
            
            Write-Output "Profil: $ProfileDir"
            Write-Output "$($cookies.Count) Cookies über $($domains.Count) Domains:"
            $domains | ForEach-Object { Write-Output "  $_" }
        }
        
        {($_ -eq "open") -or ($_ -eq "shot")} {
            if (-not $Target) {
                throw "URL fehlt"
            }
            
            $page | Invoke-PlaywrightMethod -Name "goto" -Arguments @($Target, @{ waitUntil = "domcontentloaded"; timeout = 60000 })
            $waitTime = [int](Get-FlagValue -Name "wait" -Default "2500")
            Start-Sleep -Milliseconds $waitTime
            
            $accepted = Accept-Cookies -Page $page
            if ($accepted) {
                Write-Output "Cookie-Consent bestätigt via: $accepted"
            }
            
            Start-Sleep -Milliseconds 1000
            
            $outFile = Get-FlagValue -Name "out" -Default (Join-Path "/tmp" "browser-$([DateTimeOffset]::Now.ToUnixTimeMilliseconds()).png")
            $screenshotOptions = @{ path = $outFile }
            if (Test-HasFlag -Name "full") {
                $screenshotOptions.fullPage = $true
            }
            
            $page | Invoke-PlaywrightMethod -Name "screenshot" -Arguments @($screenshotOptions)
            Write-Output "Screenshot: $outFile"
            
            $finalUrl = $page | Invoke-PlaywrightMethod -Name "url"
            Write-Output "URL final: $finalUrl"
        }
        
        "login" {
            if (-not $Target) {
                throw "URL fehlt"
            }
            
            $envVars = Load-EnvironmentFile
            $user = $envVars[(Get-FlagValue -Name "env-user" -Default "")] ?? (Get-FlagValue -Name "user" -Default "")
            $pass = $envVars[(Get-FlagValue -Name "env-pass" -Default "")] ?? (Get-FlagValue -Name "pass" -Default "")
            
            $page | Invoke-PlaywrightMethod -Name "goto" -Arguments @($Target, @{ waitUntil = "domcontentloaded"; timeout = 60000 })
            Start-Sleep -Milliseconds 2500
            
            Accept-Cookies -Page $page | Out-Null
            
            if ($user) {
                $userField = Get-FlagValue -Name "user-field" -Default "input[type=email], input[name=email], input[name=username], input[id*=email i]"
                $userLocator = $page | Invoke-PlaywrightMethod -Name "locator" -Arguments @($userField)
                $firstUserLocator = $userLocator | Invoke-PlaywrightMethod -Name "first"
                $firstUserLocator | Invoke-PlaywrightMethod -Name "fill" -Arguments @($user, @{ timeout = 8000 })
            }
            
            if ($pass) {
                $passField = Get-FlagValue -Name "pass-field" -Default "input[type=password]"
                $passLocator = $page | Invoke-PlaywrightMethod -Name "locator" -Arguments @($passField)
                $firstPassLocator = $passLocator | Invoke-PlaywrightMethod -Name "first"
                $firstPassLocator | Invoke-PlaywrightMethod -Name "fill" -Arguments @($pass, @{ timeout = 8000 })
            }
            
            $outFile = Get-FlagValue -Name "out" -Default (Join-Path "/tmp" "login-$([DateTimeOffset]::Now.ToUnixTimeMilliseconds()).png")
            $page | Invoke-PlaywrightMethod -Name "screenshot" -Arguments @(@{ path = $outFile })
            
            Write-Output "Login-Formular ausgefüllt (user=$(if ($user) { 'gesetzt' } else { '-' }), pass=$(if ($pass) { 'gesetzt' } else { '-' })). Screenshot: $outFile"
            Write-Output "Absenden bewusst NICHT automatisch — nächster Schritt nach Sichtprüfung."
        }
        
        default {
            Write-Output "Befehle: open <URL> | shot <URL> | login <URL> | state"
        }
    }
}
finally {
    if ($context) {
        $context | Invoke-PlaywrightMethod -Name "close"
        # Profil (Cookies) bleibt auf Platte erhalten
    }
}
