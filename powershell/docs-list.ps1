#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "91be179b113ae9683567bf961477bf4aa652e28114db80befbcbbbeb8cc65cda", "source_sha256": "d8cfbb58894cc82e4e8ba7def8f5bcc6b6c011986e853dba0f1c96ca81a4b49e", "target_language": "powershell"}
# docs-list.js — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/docs-list.js
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# Handle broken pipe gracefully
 trap {
    if ($_.Exception.GetType().Name -eq "PipeStoppedException") {
        exit 0
    }
    throw $_
}

$DOCS_DIR = Join-Path $PWD "docs"
if (-not (Test-Path $DOCS_DIR)) {
    Write-Error "docs:list: missing docs directory. Run from repo root."
    exit 1
}
if (-not (Get-Item $DOCS_DIR).PSIsContainer) {
    Write-Error "docs:list: docs path is not a directory."
    exit 1
}

$EXCLUDED_DIRS = @("archive", "research")

function Compact-Strings($values) {
    $result = @()
    foreach ($value in $values) {
        if ($null -eq $value) {
            continue
        }
        $normalized = $null
        if ($value -is [string]) {
            $normalized = $value.Trim()
        } elseif ($value -is [int] -or $value -is [bool]) {
            $normalized = $value.ToString().Trim()
        }

        if ($null -ne $normalized -and $normalized.Length -gt 0) {
            $result += $normalized
        }
    }
    return $result
}

function Walk-MarkdownFiles($dir, $base = $dir) {
    $entries = Get-ChildItem -Path $dir -Force
    $files = @()
    foreach ($entry in $entries) {
        if ($entry.Name.StartsWith(".")) {
            continue
        }
        $fullPath = $entry.FullName
        if ($entry.PSIsContainer) {
            if ($EXCLUDED_DIRS -contains $entry.Name) {
                continue
            }
            $files += Walk-MarkdownFiles -dir $fullPath -base $base
        } elseif ($entry.Extension -eq ".md") {
            $relPath = Resolve-Path -Path $fullPath -RelativeBasePath $base
            # Remove leading .\ on Windows or ./ on Unix
            if ($relPath.StartsWith(".\")) {
                $relPath = $relPath.Substring(2)
            } elseif ($relPath.StartsWith("./")) {
                $relPath = $relPath.Substring(2)
            }
            $files += $relPath
        }
    }
    return $files | Sort-Object
}

function Extract-Metadata($fullPath) {
    $content = Get-Content -Path $fullPath -Raw -Encoding UTF8

    if (-not $content.StartsWith("---")) {
        return @{ summary = $null; readWhen = @(); error = "missing front matter" }
    }

    $endIndex = $content.IndexOf("`n---", 3)
    if ($endIndex -eq -1) {
        return @{ summary = $null; readWhen = @(); error = "unterminated front matter" }
    }

    $frontMatter = $content.Substring(3, $endIndex - 3).Trim()
    $lines = $frontMatter -split "`n"

    $summaryLine = $null
    $readWhen = @()
    $collectingField = $null

    foreach ($rawLine in $lines) {
        $line = $rawLine.Trim()

        if ($line.StartsWith("summary:")) {
            $summaryLine = $line
            $collectingField = $null
            continue
        }

        if ($line.StartsWith("read_when:")) {
            $collectingField = "read_when"
            $inline = $line.Substring("read_when:".Length).Trim()
            if ($inline.StartsWith("[") -and $inline.EndsWith("]")) {
                try {
                    # Replace single quotes with double quotes for valid JSON
                    $json = $inline.Replace("'", '"')
                    $parsed = $json | ConvertFrom-Json
                    if ($parsed -is [array]) {
                        $readWhen += Compact-Strings($parsed)
                    }
                } catch {
                    # ignore malformed inline arrays
                }
            }
            continue
        }

        if ($collectingField -eq "read_when") {
            if ($line.StartsWith("- ")) {
                $hint = $line.Substring(2).Trim()
                if ($hint) {
                    $readWhen += $hint
                }
            } elseif ($line -eq "") {
                # allow blank lines inside the list
            } else {
                $collectingField = $null
            }
        }
    }

    if (-not $summaryLine) {
        return @{ summary = $null; readWhen = $readWhen; error = "summary key missing" }
    }

    $summaryValue = $summaryLine.Substring("summary:".Length).Trim()
    # Remove surrounding quotes and normalize whitespace
    $normalized = $summaryValue -replace '^["'']|["'']$', '' -replace '\s+', ' '.Trim()

    if (-not $normalized) {
        return @{ summary = $null; readWhen = $readWhen; error = "summary is empty" }
    }

    return @{ summary = $normalized; readWhen = $readWhen }
}

Write-Output "Listing all markdown files in docs folder:"

$markdownFiles = Walk-MarkdownFiles -dir $DOCS_DIR

foreach ($relativePath in $markdownFiles) {
    $fullPath = Join-Path $DOCS_DIR $relativePath
    $metadata = Extract-Metadata -fullPath $fullPath
    $summary = $metadata.summary
    $readWhen = $metadata.readWhen
    $error = $metadata.error

    if ($summary) {
        Write-Output "$relativePath - $summary"
        if ($readWhen.Count -gt 0) {
            Write-Output "  Read when: $($readWhen -join '; ')"
        }
    } else {
        $reason = ""
        if ($error) {
            $reason = " - [$error]"
        }
        Write-Output "$relativePath$reason"
    }
}

Write-Output ""
Write-Output "Reminder: keep docs up to date as behavior changes. When your task matches any `"Read when`" hint above (React hooks, cache directives, database work, tests, etc.), read that doc before coding, and suggest new coverage when it is missing."
