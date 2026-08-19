#!/usr/bin/env pwsh
# git_publish.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/git-publish-agent/scripts/git_publish.py
# auch in: OpenClaw@gateway2:skills/git-publish-agent/scripts/git_publish.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Git Publish Agent - Automatisierte Skill-Veröffentlichung

.DESCRIPTION
Dieses Skript ermöglicht das automatische Committen und Veröffentlichen von Skills.
#>

param(
    [string]$Skill,
    [switch]$All,
    [switch]$NoPublish,
    [string]$Message
)

$SKILLS_DIR = Join-Path $env:USERPROFILE ".openclaw" "workspace" "skills"

function Invoke-GitCommit {
    param(
        [string]$SkillPath,
        [string]$CommitMessage
    )
    
    if (-not $CommitMessage) {
        $timestamp = Get-Date -Format "o"
        $skillName = Split-Path $SkillPath -Leaf
        $CommitMessage = "[skill] Auto-update $skillName - $timestamp"
    }
    
    Push-Location (Split-Path $SKILLS_DIR -Parent)
    try {
        git add $SkillPath
        $result = git commit -m $CommitMessage 2>&1
        return $LASTEXITCODE -eq 0
    }
    finally {
        Pop-Location
    }
}

function Invoke-ClawHubPublish {
    param([string]$SkillName)
    
    $skillPath = Join-Path $SKILLS_DIR $SkillName
    $result = clawhub publish $skillPath --slug $SkillName --version "1.0.0" 2>&1
    return $LASTEXITCODE -eq 0, ($result -join "`n")
}

function Invoke-BatchPublish {
    $result = git status --short $SKILLS_DIR 2>&1
    $changed = @()
    
    foreach ($line in ($result -split "`n")) {
        if ($line.Trim() -and $line.Contains("skills/")) {
            $parts = $line.Split("skills/", 2)[1].Split("/")[0]
            if ($parts -notin $changed) {
                $changed += $parts
            }
        }
    }
    
    Write-Host "Changed skills: $($changed -join ', ')"
    
    # Begrenzen auf max. 5 Skills pro Batch
    $batch = $changed | Select-Object -First 5
    
    for ($i = 0; $i -lt $batch.Count; $i++) {
        $skill = $batch[$i]
        if ($i -gt 0) {
            Write-Host "Waiting 15min for rate limit..."
            # In real: Start-Sleep -Seconds 900
        }
        
        Write-Host "Publishing $skill..."
        $commitOk = Invoke-GitCommit -SkillPath (Join-Path $SKILLS_DIR $skill)
        if ($commitOk) {
            if (-not $NoPublish) {
                $pubResult = Invoke-ClawHubPublish -SkillName $skill
                $pubOk = $pubResult[0]
                $output = $pubResult[1]
                $symbol = if ($pubOk) { "✓" } else { "✗" }
                Write-Host "  $symbol $output"
            }
        }
    }
}

function Main {
    if ($Skill) {
        $skillPath = Join-Path $SKILLS_DIR $Skill
        if ($NoPublish) {
            Invoke-GitCommit -SkillPath $skillPath -CommitMessage $Message
        }
        else {
            Invoke-GitCommit -SkillPath $skillPath -CommitMessage $Message
            if (-not $?) { return }
            Invoke-ClawHubPublish -SkillName $Skill
        }
    }
    elseif ($All) {
        Invoke-BatchPublish
    }
    else {
        Write-Host "Use --skill <name> or --all"
    }
}

Main
