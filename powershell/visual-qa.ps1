#!/usr/bin/env pwsh
# visual-qa.mjs — portiert nach powershell
# Quelle: javascript, Onboarding@main:scripts/visual-qa.mjs
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Visual-QA-Tool der Sandbox — rendert eine laufende Seite in echten Browsern
bei mehreren Auflösungen und legt Screenshots ab, damit Claude das Ergebnis
SELBST betrachten kann, bevor es weiterverwendet wird.

.DESCRIPTION
Warum echtes Chrome: Der Playwright-Bundle-Chromium hat keine proprietären
Codecs (H.264/AAC) → Videos bleiben schwarz. Google Chrome Stable
(channel/executablePath) dekodiert die MP4-Hero-Videos korrekt.

.PARAMETER Url
Die URL zur Seite, die getestet werden soll

.PARAMETER Engines
Liste der zu verwendenden Browser-Engines (chrome,firefox,webkit)

.PARAMETER OutDir
Ausgabeverzeichnis für Screenshots

.PARAMETER Click
ARIA-Name des Buttons, der geklickt werden soll

.PARAMETER Wait
Wartezeit in Millisekunden vor dem Screenshot

.PARAMETER Full
Vollständige Seiten-Screenshots erstellen

.EXAMPLE
visual-qa.ps1 http://localhost:3000 -Engines @("chrome","firefox") -OutDir "C:\temp\screens"
#>

param(
    [string]$Url = "http://localhost:3000",
    [string[]]$Engines = @("chrome"),
    [string]$OutDir = "$env:TEMP\visual-qa",
    [int]$Wait = 3500,
    [string]$Click,
    [switch]$Full
)

# Prüfe ob Playwright installiert ist
try {
    $playwrightModule = Get-Module -ListAvailable -Name "Playwright"
    if (-not $playwrightModule) {
        Write-Host "Installing Playwright module..."
        Install-Module -Name "Playwright" -Scope CurrentUser -Force
    }
    Import-Module "Playwright"
} catch {
    Write-Error "Playwright module could not be loaded: $_"
    exit 1
}

$RESOLUTIONS = @(
    @{ Name = "desktop-1920"; Width = 1920; Height = 1080 },
    @{ Name = "desktop-1366"; Width = 1366; Height = 768 },
    @{ Name = "laptop-1440"; Width = 1440; Height = 900 },
    @{ Name = "tablet-1024"; Width = 1024; Height = 768 },
    @{ Name = "mobile-390"; Width = 390; Height = 844 }
)

$CHROME_PATHS = @(
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
)

function Find-ChromePath {
    foreach ($path in $CHROME_PATHS) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

function Launch-Browser([string]$Engine) {
    $launchOptions = @{
        Headless = $true
    }

    if ($Engine -eq "chrome") {
        $chromePath = Find-ChromePath
        if ($chromePath) {
            $launchOptions.Add("ExecutablePath", $chromePath)
        }

        $proxy = $env:HTTPS_PROXY ?? $env:https_proxy
        if ($proxy) {
            # Proxy-Einstellungen müssen über Umgebungsvariablen oder Browserargumente erfolgen
            $launchOptions.Add("Args", @(
                "--autoplay-policy=no-user-gesture-required",
                "--ssl-version-max=tls1.2"
            ))
        } else {
            $launchOptions.Add("Args", @("--autoplay-policy=no-user-gesture-required"))
        }
        
        return New-PlaywrightBrowser -BrowserName Chromium @launchOptions
    }
    
    if ($Engine -eq "firefox") {
        return New-PlaywrightBrowser -BrowserName Firefox @launchOptions
    }
    
    if ($Engine -eq "webkit") {
        return New-PlaywrightBrowser -BrowserName WebKit @launchOptions
    }
    
    throw "Unbekannte Engine: $Engine"
}

# Erstelle Ausgabeverzeichnis
if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

$manifest = @()

foreach ($engine in $Engines) {
    try {
        $browser = Launch-Browser -Engine $engine
    } catch {
        Write-Error "[${engine}] Start fehlgeschlagen: $($_.Exception.Message)"
        continue
    }

    foreach ($res in $RESOLUTIONS) {
        $context = $null
        try {
            $context = $browser.NewContext(@{
                Viewport = @{ 
                    Width = $res.Width
                    Height = $res.Height
                }
                DeviceScaleFactor = 1
            })
            
            $page = $context.NewPage()
            
            # Navigiere zur Seite
            $page.GotoAsync($Url, @{ 
                WaitUntil = "networkidle"
                Timeout = 60000 
            }).GetAwaiter().GetResult()
            
            Start-Sleep -Milliseconds $Wait
            
            # Klicke ggf. auf Button
            if ($Click) {
                try {
                    $button = $page.GetByRole("button", @{ Name = $Click }).First
                    $button.ClickAsync(@{ Timeout = 8000 }).GetAwaiter().GetResult()
                    Start-Sleep -Milliseconds 2000
                } catch {
                    Write-Error "[${engine}/$($res.Name)] Klick '$Click' fehlgeschlagen: $($_.Exception.Message)"
                }
            }
            
            # Erstelle Screenshot
            $fileName = "${engine}-$($res.Name).png"
            $filePath = Join-Path $OutDir $fileName
            
            $screenshotOptions = @{ Path = $filePath }
            if ($Full) { $screenshotOptions.FullPage = $true }
            
            $page.ScreenshotAsync($screenshotOptions).GetAwaiter().GetResult()
            
            # Ermittle Phase (falls vorhanden)
            $phaseElement = $page.Locator("[data-pond-phase]")
            $phase = ""
            try {
                $phase = $phaseElement.GetAttributeAsync("data-pond-phase").GetAwaiter().GetResult()
            } catch {
                $phase = $null
            }
            
            $manifest += [PSCustomObject]@{
                Engine = $engine
                Res = $res.Name
                File = $filePath
                Phase = $phase
            }
            
            Write-Host ("OK  {0,-8} {1,-13} phase={2,-6}  {3}" -f $engine, $res.Name, ($phase ?? "-"), $filePath)
            
        } catch {
            Write-Error "ERR ${engine}/$($res.Name): $($_.Exception.Message)"
        } finally {
            if ($context) {
                $context.CloseAsync().GetAwaiter().GetResult()
            }
        }
    }
    
    if ($browser) {
        $browser.CloseAsync().GetAwaiter().GetResult()
    }
}

Write-Host "`n$($manifest.Count) Screenshots in $OutDir"
