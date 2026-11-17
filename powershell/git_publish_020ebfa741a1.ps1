#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "d9ebb65c8f36c23b0cd5e97486a40a5b2a682a71301871e7cb26e6a24ed5d970", "source_sha256": "4c10c6b6fd911cb95da119f761f402073d1a836cab6b40a9f3b989536d5df5ec", "target_language": "powershell"}
# git_publish.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/git-publish-agent/scripts/git_publish.py
# auch in: OpenClaw@gateway2:skills/git-publish-agent/scripts/git_publish.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

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

$SKILLS_DIR = Join-Path $env:USERPROFILE ".openclaw/workspace/skills"

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
    
    Push-Location (Split-Path $SKILLS_DIR)
    try {
        git add $SkillPath
        $result = git commit -m $CommitMessage 2>&1
        return $LASTEXITCODE -eq 0
    } finally {
        Pop-Location
    }
}

function Invoke-ClawHubPublish {
    param([string]$SkillName)
    
    $skillPath = Join-Path $SKILLS_DIR $SkillName
    $result = & clawhub publish $skillPath --slug $SkillName --version "1.0.0" 2>&1
    return @{
        Success = ($LASTEXITCODE -eq 0)
        Output = ($result -join "`n")
    }
}

function Invoke-BatchPublish {
    Push-Location (Split-Path $SKILLS_DIR)
    try {
        $statusOutput = git status --short $SKILLS_DIR 2>&1
        $changed = @()
        
        foreach ($line in $statusOutput) {
            if ($line.Trim() -and $line.Contains("skills/")) {
                $parts = $line.Split("skills/", 2)
                if ($parts.Count -gt 1) {
                    $skill = ($parts[1].Split("/"))[0]
                    if ($skill -notin $changed) {
                        $changed += $skill
                    }
                }
            }
        }
        
        Write-Host "Changed skills: $($changed -join ', ')"
        
        # Nur die ersten 5 Skills veröffentlichen
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
                $pubResult = Invoke-ClawHubPublish -SkillName $skill
                $symbol = if ($pubResult.Success) { "✓" } else { "✗" }
                Write-Host "  $symbol $($pubResult.Output)"
            }
        }
    } finally {
        Pop-Location
    }
}

function Main {
    if ($Skill) {
        $skillPath = Join-Path $SKILLS_DIR $Skill
        if ($NoPublish) {
            Invoke-GitCommit -SkillPath $skillPath -CommitMessage $Message
        } else {
            Invoke-GitCommit -SkillPath $skillPath -CommitMessage $Message
            Invoke-ClawHubPublish -SkillName $Skill
        }
    } elseif ($All) {
        Invoke-BatchPublish
    } else {
        Write-Host "Use --Skill <name> or --All"
    }
}

Main
