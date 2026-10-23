#!/usr/bin/env pwsh
# verify-downloads.py — portiert nach powershell
# Quelle: python, Projects@TikTok-Live-Companion:site/scripts/verify-downloads.py
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:site/scripts/verify-downloads.py
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Verify the candidate's actual HTTP downloads against committed files.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$BaseUrl,
    
    [Parameter(Mandatory=$true)]
    [System.IO.FileInfo]$Report
)

$scriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
$root = Resolve-Path "$scriptRoot/../.."
$checksumPath = Join-Path $root "public/downloads/tiktok-live-companion-0.8.2-SHA256.txt"
$results = @()

Get-Content $checksumPath | ForEach-Object {
    $line = $_.Trim()
    if (-not $line) { return }
    
    $parts = $line -split "  ", 2
    $expected = $parts[0]
    $name = $parts[1]
    
    $url = "$($BaseUrl.TrimEnd('/'))/downloads/$name"
    
    try {
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 30
        $data = $response.Content
    } catch {
        throw "Failed to download $url : $($_.Exception.Message)"
    }
    
    $actual = (Get-FileHash -InputStream ([System.IO.MemoryStream]::New([byte[]][char[]]$data)) -Algorithm SHA256).Hash.ToLower()
    
    if ($actual -ne $expected) {
        throw "HTTP artifact hash mismatch: $name"
    }
    
    $localFilePath = Join-Path $root "public/downloads/$name"
    if (-not (Test-Path $localFilePath)) {
        throw "Local file not found: $localFilePath"
    }
    
    $localBytes = [System.IO.File]::ReadAllBytes($localFilePath)
    if (-not [System.Linq.Enumerable]::SequenceEqual([byte[]][char[]]$data, $localBytes)) {
        throw "HTTP artifact content mismatch: $name"
    }
    
    # Verify ZIP integrity
    $memoryStream = [System.IO.MemoryStream]::New([byte[]][char[]]$data)
    try {
        $archive = [System.IO.Compression.ZipArchive]::New($memoryStream, [System.IO.Compression.ZipArchiveMode]::Read)
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName -and $entry.Length -gt 0) {
                $entryStream = $entry.Open()
                $entryStream.Dispose()
            }
        }
        
        if ($name -like "*-extension-*") {
            $manifestEntry = $archive.GetEntry("manifest.json")
            if ($manifestEntry) {
                $manifestStream = $manifestEntry.Open()
                $manifestReader = [System.IO.StreamReader]::New($manifestStream)
                $manifestContent = $manifestReader.ReadToEnd()
                $manifestReader.Close()
                $manifestStream.Close()
                
                $manifest = ConvertFrom-Json $manifestContent
                if ($manifest.version -ne "0.8.2") {
                    throw "Wrong extension version in $name"
                }
            }
            
            $sourceFiles = @("background.js", "content.js", "sidepanel.js", "sidepanel.html")
            foreach ($source in $sourceFiles) {
                $sourceEntry = $archive.GetEntry($source)
                if ($sourceEntry) {
                    $sourceStream = $sourceEntry.Open()
                    $sourceMemoryStream = [System.IO.MemoryStream]::New()
                    $sourceStream.CopyTo($sourceMemoryStream)
                    $sourceBytes = $sourceMemoryStream.ToArray()
                    $sourceStream.Close()
                    $sourceMemoryStream.Close()
                    
                    $sourcePath = Join-Path $root "../plugin-source/browser-extension/$source"
                    if (Test-Path $sourcePath) {
                        $expectedSourceBytes = [System.IO.File]::ReadAllBytes($sourcePath)
                        if (-not [System.Linq.Enumerable]::SequenceEqual($sourceBytes, $expectedSourceBytes)) {
                            throw "Extension source mismatch: $source"
                        }
                    } else {
                        throw "Expected source file not found: $sourcePath"
                    }
                } else {
                    throw "Missing source file in archive: $source"
                }
            }
        }
        
        $archive.Dispose()
    } finally {
        $memoryStream.Close()
    }
    
    $results += @{
        name = $name
        sha256 = $actual
        bytes = $data.Length
        verified = $true
    }
}

$output = @{
    base_url = $BaseUrl
    artifacts = $results
}

$outputJson = ConvertTo-Json $output -Depth 10
[System.IO.File]::WriteAllText($Report.FullName, $outputJson, [System.Text.Encoding]::UTF8)

Write-Output (ConvertTo-Json $results -Depth 10)
