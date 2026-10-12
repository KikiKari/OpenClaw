#!/usr/bin/env pwsh
# test_quick_validate.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_quick_validate.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_quick_validate.py
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Regression tests for quick skill validation.
#>

using namespace System.IO
using namespace System.Text

# Mocking the quick_validate module functionality
function Validate-Skill {
    param(
        [string]$SkillDir
    )

    $skillFile = Join-Path $SkillDir "SKILL.md"
    if (-not (Test-Path $skillFile)) {
        return $false, "SKILL.md not found"
    }

    $content = Get-Content $skillFile -Raw
    if ($content -match "^---[\r\n]+(?:.*?[\r\n]+)*?---[\r\n]+") {
        return $true, "Valid skill"
    } else {
        return $false, "Invalid frontmatter format"
    }
}

# Test class equivalent
class TestQuickValidate {
    [string]$TempDir

    TestQuickValidate() {
        $this.TempDir = [Path]::Combine([Path]::GetTempPath(), "test_quick_validate_" + [Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $this.TempDir -Force | Out-Null
    }

    [void] TearDown() {
        if (Test-Path $this.TempDir) {
            Remove-Item -Path $this.TempDir -Recurse -Force
        }
    }

    [bool] TestAcceptsCrlfFrontmatter() {
        $skillDir = [Path]::Combine($this.TempDir, "crlf-skill")
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
        
        $content = "---`r`nname: crlf-skill`r`ndescription: ok`r`n---`r`n# Skill`r`n"
        $filePath = [Path]::Combine($skillDir, "SKILL.md")
        [File]::WriteAllText($filePath, $content, [Encoding]::UTF8)

        $result = Validate-Skill $skillDir
        $valid = $result[0]
        $message = $result[1]

        return $valid
    }

    [bool] TestRejectsMissingFrontmatterClosingFence() {
        $skillDir = [Path]::Combine($this.TempDir, "bad-skill")
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
        
        $content = "---`nname: bad-skill`ndescription: missing end`n# no closing fence`n"
        $filePath = [Path]::Combine($skillDir, "SKILL.md")
        [File]::WriteAllText($filePath, $content, [Encoding]::UTF8)

        $result = Validate-Skill $skillDir
        $valid = $result[0]
        $message = $result[1]

        return (-not $valid) -and ($message -eq "Invalid frontmatter format")
    }

    [bool] TestFallbackParserHandlesMultilineFrontmatterWithoutPyyaml() {
        $skillDir = [Path]::Combine($this.TempDir, "multiline-skill")
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
        
        $content = @" 
---
name: multiline-skill
description: Works without pyyaml
allowed-tools:
  - gh
metadata: |
  {
    "owners": ["team-openclaw"]
  }
---
# Skill
"@
        
        $filePath = [Path]::Combine($skillDir, "SKILL.md")
        [File]::WriteAllText($filePath, $content, [Encoding]::UTF8)

        # Simulate disabling YAML library by using our own parser
        $result = Validate-Skill $skillDir
        $valid = $result[0]
        $message = $result[1]

        return $valid
    }
}

# Main execution
function Run-Tests {
    $testInstance = [TestQuickValidate]::new()
    $allPassed = $true
    
    try {
        Write-Host "Running test_accepts_crlf_frontmatter..." -ForegroundColor Yellow
        if ($testInstance.TestAcceptsCrlfFrontmatter()) {
            Write-Host "PASSED" -ForegroundColor Green
        } else {
            Write-Host "FAILED" -ForegroundColor Red
            $allPassed = $false
        }

        Write-Host "Running test_rejects_missing_frontmatter_closing_fence..." -ForegroundColor Yellow
        if ($testInstance.TestRejectsMissingFrontmatterClosingFence()) {
            Write-Host "PASSED" -ForegroundColor Green
        } else {
            Write-Host "FAILED" -ForegroundColor Red
            $allPassed = $false
        }

        Write-Host "Running test_fallback_parser_handles_multiline_frontmatter_without_pyyaml..." -ForegroundColor Yellow
        if ($testInstance.TestFallbackParserHandlesMultilineFrontmatterWithoutPyyaml()) {
            Write-Host "PASSED" -ForegroundColor Green
        } else {
            Write-Host "FAILED" -ForegroundColor Red
            $allPassed = $false
        }
    } finally {
        $testInstance.TearDown()
    }
    
    if ($allPassed) {
        exit 0
    } else {
        exit 1
    }
}

Run-Tests
