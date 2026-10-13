#!/usr/bin/env pwsh
# tiktok-get-stream.js — portiert nach powershell
# Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-get-stream.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
TikTok Stream URL Extractor
.DESCRIPTION
Führt zuerst den profilgebundenen Status-Checker aus.
Nur bei bestätigtem Live-Status werden FLV-Netzwerk-URLs erfasst.
Offline wird keine Stream-URL ausgegeben.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Username
)

# Entferne führende @ Zeichen
$Username = $Username -replace '^@+', ''

if (-not $Username) {
    Write-Error "Username must not be empty"
    exit 1
}

function Test-BusyNode {
    $limit = $env:TIKTOK_MAX_LOAD_PER_CPU
    if (-not ($limit -and [double]::TryParse($limit, [ref]$null) -and [double]$limit -gt 0)) {
        return
    }

    $cpuCount = [Math]::Max(1, (Get-CimInstance Win32_Processor).Count)
    $loadAvg = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 5 | 
               Measure-Object -Property CounterSamples -Average).Average / 100
    
    if ($loadAvg -gt [double]$limit) {
        Write-Error "NODE_BUSY normalizedLoad=$([math]::Round($loadAvg, 2)) limit=$limit"
        exit 75
    }
}

Test-BusyNode

function Confirm-LiveStatus {
    param([string]$Username)
    
    $checkerPath = Join-Path $PSScriptRoot "tiktok-check-profile.js"
    try {
        $result = & node $checkerPath $Username 2>$null
        if ($LASTEXITCODE -eq 0) {
            $json = $result | ConvertFrom-Json
            return $json.isLive -eq $true
        }
        return $false
    } catch {
        try {
            $output = $_.Exception.Message
            if ($output) {
                $json = $output | ConvertFrom-Json
                return $json.isLive -eq $true
            }
        } catch { }
        return $false
    }
}

function Get-StreamUrl {
    param([string]$Username)
    
    if (-not (Confirm-LiveStatus $Username)) {
        $errorObj = @{
            username = $Username
            isLive = $false
            error = "User is not currently live."
            timestamp = (Get-Date).ToUniversalTime().ToString("o")
        }
        Write-Error ($errorObj | ConvertTo-Json -Depth 5)
        return $false
    }

    # Starte Browser im Headless-Modus
    $startParams = @{
        Uri = "http://localhost:9222/json/version"
        ErrorAction = "SilentlyContinue"
        TimeoutSec = 5
    }
    
    try {
        # Prüfe ob Chrome bereits läuft
        Invoke-RestMethod @startParams | Out-Null
    } catch {
        # Starte neuen Browserprozess
        $chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
        if (-not (Test-Path $chromePath)) {
            $chromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
        }
        if (-not (Test-Path $chromePath)) {
            Write-Error "Chrome not found"
            return $false
        }
        
        Start-Process -FilePath $chromePath -ArgumentList "--remote-debugging-port=9222", "--headless=new" -WindowStyle Hidden
        Start-Sleep -Seconds 3
    }

    # Verbinde mit dem Browser
    try {
        $versionInfo = Invoke-RestMethod "http://localhost:9222/json/version"
        $websocketUrl = ($versionInfo.webSocketDebuggerUrl -split '/', 4)[0..2] -join '/'
        
        # Öffne neue Seite
        $pageResponse = Invoke-RestMethod "http://localhost:9222/json/new" -Method Post -Body "{}"
        $pageId = $pageResponse.id
        
        # WebSocket Verbindung für Netzwerküberwachung
        $networkRequests = @()
        $ws = New-Object System.Net.WebSockets.ClientWebSocket
        $ct = New-Object System.Threading.CancellationToken
        $ws.ConnectAsync([System.Uri]("http://localhost:9222/devtools/page/$pageId"), $ct).Wait()
        
        # Aktiviere Netzwerküberwachung
        $enableNetworkCmd = '{"id":1,"method":"Network.enable"}'
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($enableNetworkCmd)
        $segment = New-Object System.ArraySegment[Byte] -ArgumentList @(,$buffer)
        $ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait()
        
        # Navigiere zur Live-Seite
        $navigateCmd = @"
{"id":2,"method":"Page.navigate","params":{"url":"https://www.tiktok.com/@$Username/live"}}
"@
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($navigateCmd)
        $segment = New-Object System.ArraySegment[Byte] -ArgumentList @(,$buffer)
        $ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait()
        
        # Warte auf Netzwerkaktivität
        Start-Sleep -Seconds 20
        
        # Schließe WebSocket
        $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "", $ct).Wait()
        
        # Hole Netzwerkanfragen vom Browser
        $requests = Invoke-RestMethod "http://localhost:9222/json/list" | Where-Object {$_.type -eq "page"}
        foreach ($req in $requests) {
            if ($req.url -match "\.flv|pull-flv") {
                $networkRequests += @{
                    url = $req.url
                    type = "Media"
                    timestamp = (Get-Date).ToUniversalTime().ToString("o")
                }
            }
        }
        
        if ($networkRequests.Count -gt 0) {
            # Entferne Duplikate
            $uniqueUrls = $networkRequests | Sort-Object url -Unique
            
            # Sortiere nach Qualität
            $sortedUrls = $uniqueUrls | Sort-Object {
                $quality = 0
                $suffixRanks = @(
                    @('_origin.', 600),
                    @('_uhd_60.', 550),
                    @('_uhd.', 540),
                    @('_hd_60.', 500),
                    @('_hd.', 450),
                    @('_sd.', 350),
                    @('_ld.', 250)
                )
                
                foreach ($rank in $suffixRanks) {
                    if ($_.url.Contains($rank[0])) {
                        $quality = $rank[1]
                        break
                    }
                }
                
                if ($quality -eq 0 -and $_.url -match '(\d+)p') {
                    $quality = [int]$matches[1]
                }
                
                -$quality
            }
            
            $result = @{
                username = $Username
                isLive = $true
                streamCount = $sortedUrls.Count
                streams = $sortedUrls
                vlcCommand = "vlc `"$($sortedUrls[0].url)`""
                timestamp = (Get-Date).ToUniversalTime().ToString("o")
            }
            
            Write-Output ($result | ConvertTo-Json -Depth 5)
            return $true
        } else {
            $errorObj = @{
                username = $Username
                isLive = $false
                error = "No stream URLs found - user may not be live"
                timestamp = (Get-Date).ToUniversalTime().ToString("o")
            }
            Write-Error ($errorObj | ConvertTo-Json -Depth 5)
            return $false
        }
        
    } catch {
        $errorObj = @{
            error = $true
            message = $_.Exception.Message
            timestamp = (Get-Date).ToUniversalTime().ToString("o")
        }
        Write-Error ($errorObj | ConvertTo-Json -Depth 5)
        return $false
    }
}

try {
    $success = Get-StreamUrl $Username
    if ($success) {
        exit 0
    } else {
        exit 1
    }
} catch {
    $errorObj = @{
        error = $true
        message = $_.Exception.Message
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
    }
    Write-Error ($errorObj | ConvertTo-Json -Depth 5)
    exit 1
}
