#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "8bbd122acd060c8c696afd47344269fc8988188ac10127a973d6a7480445e056", "source_sha256": "9c8abc93c198b77f804a6837db7baf1e85c902dc35a853c8086222a89f83fc89", "target_language": "powershell"}
# transcribe.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/openai-whisper-api/scripts/transcribe.sh
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

param(
    [string]$Path = "",
    [string]$Model = "whisper-1",
    [string]$Out = "",
    [string]$Language = "",
    [string]$Prompt = "",
    [switch]$Json,
    [switch]$Help
)

function Show-Usage {
    Write-Error @"
Usage:
  transcribe.ps1 <audio-file> [-Model whisper-1] [-Out /path/to/out.txt] [-Language en] [-Prompt `"hint`"] [-Json]
"@
    exit 2
}

if ($Help -or $Path -eq "") {
    Show-Usage
}

if (!(Test-Path $Path)) {
    Write-Error "File not found: $Path"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)) {
    Write-Error "Missing OPENAI_API_KEY"
    exit 1
}

$responseFormat = if ($Json) { "json" } else { "text" }

if ([string]::IsNullOrWhiteSpace($Out)) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $dir = [System.IO.Path]::GetDirectoryName($Path)
    if ([string]::IsNullOrWhiteSpace($dir)) { $dir = "." }
    if ($responseFormat -eq "json") {
        $Out = [System.IO.Path]::Combine($dir, "$base.json")
    } else {
        $Out = [System.IO.Path]::Combine($dir, "$base.txt")
    }
}

$parentDir = [System.IO.Path]::GetDirectoryName($Out)
if (![string]::IsNullOrWhiteSpace($parentDir)) {
    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
}

$apiBase = $env:OPENAI_BASE_URL ?? "https://api.openai.com/v1"
$apiBase = $apiBase.TrimEnd('/')

$uri = "$apiBase/audio/transcriptions"

$headers = @{
    Authorization = "Bearer $env:OPENAI_API_KEY"
    Accept = "application/json"
}

$form = @{
    file = Get-Item $Path
    model = $Model
    response_format = $responseFormat
}

if (![string]::IsNullOrWhiteSpace($Language)) {
    $form["language"] = $Language
}

if (![string]::IsNullOrWhiteSpace($Prompt)) {
    $form["prompt"] = $Prompt
}

try {
    $response = Invoke-WebRequest -Uri $uri -Method Post -Headers $headers -Form $form -OutFile $Out
    Write-Output $Out
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
