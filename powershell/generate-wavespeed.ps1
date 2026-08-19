#!/usr/bin/env pwsh
# generate-wavespeed.mjs — portiert nach powershell
# Quelle: javascript, Onboarding@main:scripts/generate-wavespeed.mjs
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

$key = $env:WAVESPEED_API_KEY
if (-not $key) {
    throw "WAVESPEED_API_KEY fehlt."
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$jobsPath = Join-Path $scriptDir "..\media-production\wavespeed-jobs.json"
$rawDir = Join-Path $scriptDir "..\media-production\raw"
$publicDir = Join-Path $scriptDir "..\public\media"
$resultPath = Join-Path $scriptDir "..\media-production\wavespeed-results.json"

$jobs = Get-Content $jobsPath | ConvertFrom-Json
New-Item -ItemType Directory -Path $rawDir -Force | Out-Null
New-Item -ItemType Directory -Path $publicDir -Force | Out-Null

$log = if (Test-Path $resultPath) {
    Get-Content $resultPath | ConvertFrom-Json
} else {
    @()
}

foreach ($job in $jobs) {
    $rawPath = Join-Path $rawDir "$($job.id).png"
    $targetPath = Join-Path $publicDir "$($job.output).png"
    
    if (Test-Path $rawPath) {
        if (-not ($log | Where-Object { $_.id -eq $job.id })) {
            $entry = [PSCustomObject]@{
                id = $job.id
                requestId = "completed-before-resume"
                model = "google/nano-banana-2/edit"
                resolution = "4k"
                plannedCostUsd = 0.14
                output = Split-Path $targetPath -Leaf
            }
            $log += $entry
            $log | ConvertTo-Json -Depth 10 | Set-Content $resultPath
        }
        Write-Host "Übersprungen: $($job.id) ist bereits vorhanden."
        continue
    }
    
    $images = @()
    foreach ($image in $job.images) {
        if ($image -match "^https?:|^data:") {
            $images += $image
        } else {
            $imagePath = Resolve-Path (Join-Path $scriptDir "..\$image")
            $bytes = [System.IO.File]::ReadAllBytes($imagePath)
            $base64 = [Convert]::ToBase64String($bytes)
            $images += "data:image/png;base64,$base64"
        }
    }
    
    $body = @{
        prompt = $job.prompt
        images = $images
        aspect_ratio = $job.aspectRatio
        resolution = "4k"
        output_format = "png"
        enable_web_search = $false
        enable_image_search = $false
        enable_sync_mode = $false
        enable_base64_output = $false
    } | ConvertTo-Json -Depth 10
    
    $headers = @{
        Authorization = "Bearer $key"
        "Content-Type" = "application/json"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.wavespeed.ai/api/v3/google/nano-banana-2/edit" -Method POST -Headers $headers -Body $body
    } catch {
        throw "WaveSpeed submit fehlgeschlagen: $($_.Exception.Message)"
    }
    
    $requestId = if ($response.data.id) { $response.data.id } else { $response.id }
    $result = $null
    
    for ($attempt = 0; $attempt -lt 90; $attempt++) {
        Start-Sleep -Seconds 4
        try {
            $poll = Invoke-RestMethod -Uri "https://api.wavespeed.ai/api/v3/predictions/$requestId/result" -Headers @{Authorization="Bearer $key"}
            $result = $poll
            if ($result.data.status -eq "completed") { break }
            if ($result.data.status -eq "failed") { 
                throw "WaveSpeed job fehlgeschlagen: $($job.id)" 
            }
        } catch {
            # Continue polling on error
        }
    }
    
    $url = $result.data.outputs[0]
    if (-not $url) {
        throw "Kein Output für $($job.id)"
    }
    
    try {
        $bytes = Invoke-WebRequest -Uri $url -UseBasicParsing
        [System.IO.File]::WriteAllBytes($rawPath, $bytes.Content)
        [System.IO.File]::WriteAllBytes($targetPath, $bytes.Content)
    } catch {
        throw "Fehler beim Herunterladen des Outputs für $($job.id): $($_.Exception.Message)"
    }
    
    $entry = [PSCustomObject]@{
        id = $job.id
        requestId = $requestId
        model = "google/nano-banana-2/edit"
        resolution = "4k"
        plannedCostUsd = 0.14
        output = Split-Path $targetPath -Leaf
    }
    $log += $entry
    $log | ConvertTo-Json -Depth 10 | Set-Content $resultPath
    Write-Host "Abgeschlossen: $($job.id)"
}

$log | ConvertTo-Json -Depth 10 | Set-Content $resultPath
$totalCost = $log.Count * 0.14
Write-Host "WaveSpeed abgeschlossen: $($log.Count) Assets, geplante Basiskosten `$$('{0:F2}' -f $totalCost)."
