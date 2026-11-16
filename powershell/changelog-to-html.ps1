#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "5e80faa5f008f5650e6165f1fec95e0c8fe0e6f1a66a9be72e70922a126b9b79", "source_sha256": "13f974bf78b140bc88bd9f3afe27c500660ef59498ed533c38c18bca0c6f6331", "target_language": "powershell"}
# changelog-to-html.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/changelog-to-html.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

param(
    [string]$Version = "",
    [string]$ChangelogFile = ""
)

if (-not $Version) {
    Write-Error "Usage: $((Get-Item $MyInvocation.MyCommand.Path).Name) <version> [changelog_file]"
    exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ChangelogFile) {
    if (Test-Path "$ScriptDir/../CHANGELOG.md") {
        $ChangelogFile = "$ScriptDir/../CHANGELOG.md"
    } elseif (Test-Path "CHANGELOG.md") {
        $ChangelogFile = "CHANGELOG.md"
    } elseif (Test-Path "../CHANGELOG.md") {
        $ChangelogFile = "../CHANGELOG.md"
    } else {
        Write-Error "Error: Could not find CHANGELOG.md"
        exit 1
    }
}

if (-not (Test-Path $ChangelogFile)) {
    Write-Error "Error: Changelog file '$ChangelogFile' not found"
    exit 1
}

function Extract-VersionSection {
    param(
        [string]$Version,
        [string]$File
    )
    
    $content = Get-Content $File
    $found = $false
    $result = @()
    
    foreach ($line in $content) {
        if ($line -match "^## ") {
            if ($line -match "^##[[:space:]]+$Version([[:space:]].*|`$)") {
                $found = $true
                continue
            }
            if ($found) {
                break
            }
        }
        if ($found) {
            $result += $line
        }
    }
    
    return ($result -join "`n")
}

function Convert-MarkdownToHtml {
    param([string]$Text)
    
    $text = $Text -replace '^##### (.*)$', '<h5>$1</h5>'
    $text = $text -replace '^#### (.*)$', '<h4>$1</h4>'
    $text = $text -replace '^### (.*)$', '<h3>$1</h3>'
    $text = $text -replace '^## (.*)$', '<h2>$1</h2>'
    $text = $text -replace '^- \*\*([^*]*)\*\*(.*)$', '<li><strong>$1</strong>$2</li>'
    $text = $text -replace '^- ([^*].*)$', '<li>$1</li>'
    $text = $text -replace '\*\*([^*]*)\*\*', '<strong>$1</strong>'
    $text = $text -replace '`([^`]*)`', '<code>$1</code>'
    $text = $text -replace '\[([^\]]*)\]\(([^)]*)\)', '<a href="$2">$1</a>'
    
    return $text
}

$versionContent = Extract-VersionSection $Version $ChangelogFile
if (-not $versionContent) {
    Write-Output "<h2>OpenClaw $Version</h2>"
    Write-Output "<p>Latest OpenClaw update.</p>"
    Write-Output "<p><a href=`"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md`">View full changelog</a></p>"
    exit 0
}

Write-Output "<h2>OpenClaw $Version</h2>"

$inList = $false
$lines = $versionContent -split "`n"
foreach ($line in $lines) {
    if ($line -match "^-") {
        if (-not $inList) {
            Write-Output "<ul>"
            $inList = $true
        }
        Convert-MarkdownToHtml $line
    } else {
        if ($inList) {
            Write-Output "</ul>"
            $inList = $false
        }
        if ($line -match "\S") {
            Convert-MarkdownToHtml $line
        }
    }
}

if ($inList) {
    Write-Output "</ul>"
}

Write-Output "<p><a href=`"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md`">View full changelog</a></p>"
