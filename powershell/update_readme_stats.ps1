#!/usr/bin/env pwsh
# update_readme_stats.py — portiert nach powershell
# Quelle: python, OpenClaw@main:scripts/update_readme_stats.py
# Erzeugt: 2026-08-24 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Fetch ClawHub stats and update README.md download counts and security status.
#>

$API_BASE = "https://clawhub.ai/api/v1"
$TOKEN = $env:CLAWHUB_TOKEN

$SKILLS = @(
    @("Cluster Gateway",           "cluster-gateway"),
    @("MCP Tool Utils",            "mcp-tool-utils"),
    @("Reports Creator",           "reports-creator"),
    @("Relay Node",                "relay-node"),
    @("JSON Utils",                "json-utils"),
    @("Log Collector",             "log-collector"),
    @("TikTok Live Monitor",       "tiktok-live-monitor"),
    @("Doc Scraper",               "doc-scraper"),
    @("Workspace Database Manager","workspace-database-manager"),
    @("Scripting Utils",           "scripting-utils")
)

function Fetch-Skill {
    param (
        [string]$Slug
    )
    
    $url = "$API_BASE/skills/$Slug"
    $headers = @{
        "Accept" = "application/json"
    }
    
    if ($TOKEN) {
        $headers["Authorization"] = "Bearer $TOKEN"
    }
    
    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 10
        return $response
    }
    catch {
        throw $_
    }
}

function Parse-Skill {
    param (
        [object]$Data
    )
    
    $skill = $Data.skill | ? { $_ } | % { $_ } | Select-Object -First 1
    if (-not $skill) { $skill = @{} }
    
    $stats = $skill.stats | ? { $_ } | % { $_ } | Select-Object -First 1
    if (-not $stats) { $stats = @{} }
    
    $latestVersion = $Data.latestVersion | ? { $_ } | % { $_ } | Select-Object -First 1
    if (-not $latestVersion) { $latestVersion = @{ version = "1.0.0" } }
    
    $mod = $Data.moderation
    
    $downloads = $stats.downloads | ? { $_ } | % { $_ } | Select-Object -First 1
    if (-not $downloads) { $downloads = 0 }
    
    if ($null -eq $mod) {
        $security = "✅ Pass"
    }
    elseif ($mod.isMalwareBlocked) {
        $security = "🚫 Blocked"
    }
    else {
        $security = "🔍 Review"
    }
    
    $version = $latestVersion.version | ? { $_ } | % { $_ } | Select-Object -First 1
    if (-not $version) { $version = "1.0.0" }
    
    if (-not $version.StartsWith("v")) {
        $version = "v$version"
    }
    
    return @{
        downloads = $downloads
        version   = $version
        security  = $security
    }
}

function Main {
    $stats = @{}
    $errors = 0
    
    foreach ($skill in $SKILLS) {
        $name = $skill[0]
        $slug = $skill[1]
        
        try {
            $data = Fetch-Skill -Slug $slug
            $s = Parse-Skill -Data $data
            $stats[$slug] = $s
            Write-Host "  OK  $slug`: $($s.downloads) downloads, $($s.version), $($s.security)"
        }
        catch {
            Write-Error "  ERR $slug`: $_"
            $errors++
        }
    }
    
    if ($stats.Count -eq 0) {
        Write-Error "No data fetched - aborting."
        exit 1
    }
    
    $content = Get-Content -Path "README.md" -Raw -Encoding UTF8
    
    foreach ($skill in $SKILLS) {
        $name = $skill[0]
        $slug = $skill[1]
        
        if (-not $stats.ContainsKey($slug)) {
            continue
        }
        
        $dl = $stats[$slug].downloads
        $pattern = "\|\s*\[?$([regex]::Escape($name))\]?[^|]*\|[^|]*\|\s*\d+\s*\|"
        $replacement = "`${0}" -replace "\|\s*\d+\s*\|$", "| $dl |"
        
        $newContent = $content -replace $pattern, $replacement
        
        if ($newContent -ne $content) {
            $content = $newContent
            Write-Host "  Updated: $name -> $dl"
        }
    }
    
    Set-Content -Path "README.md" -Value $content -Encoding UTF8
    Write-Host "Done: $($stats.Count) skills, $errors errors."
}

Main
