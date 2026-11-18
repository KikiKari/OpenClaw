#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "0ca13b2afa68a1f7451028d14832cf611895375956b2220c126e82e1695de24d", "source_sha256": "f290101073ee6a167f46edadda164d2c88affc03c554135fe101a4e422c44c22", "target_language": "powershell"}
# package_skill.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/package_skill.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/package_skill.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Skill Packager - Creates a distributable .skill file of a skill folder

.DESCRIPTION
Packages a skill folder into a .skill file (zip format) with validation

.PARAMETER SkillPath
Path to the skill folder

.PARAMETER OutputDirectory
Optional output directory for the .skill file (defaults to current directory)

.EXAMPLE
./package_skill.ps1 skills/public/my-skill
./package_skill.ps1 skills/public/my-skill ./dist
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SkillPath,
    
    [Parameter()]
    [string]$OutputDirectory
)

function Test-PathWithinRoot {
    param(
        [string]$Path,
        [string]$RootPath
    )
    
    $pathItem = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    $rootItem = Get-Item -LiteralPath $RootPath -ErrorAction SilentlyContinue
    
    if (-not $pathItem -or -not $rootItem) {
        return $false
    }
    
    $pathFull = $pathItem.FullName
    $rootFull = $rootItem.FullName
    
    return $pathFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)
}

function Package-Skill {
    param(
        [string]$SkillPath,
        [string]$OutputDir
    )
    
    $skillPathItem = Get-Item -LiteralPath $SkillPath -ErrorAction SilentlyContinue
    
    # Validate skill folder exists
    if (-not $skillPathItem) {
        Write-Error "[ERROR] Skill folder not found: $SkillPath"
        return $null
    }
    
    if (-not $skillPathItem.PSIsContainer) {
        Write-Error "[ERROR] Path is not a directory: $SkillPath"
        return $null
    }
    
    # Validate SKILL.md exists
    $skillMdPath = Join-Path $skillPathItem.FullName "SKILL.md"
    if (-not (Test-Path -LiteralPath $skillMdPath -PathType Leaf)) {
        Write-Error "[ERROR] SKILL.md not found in $($skillPathItem.FullName)"
        return $null
    }
    
    # Run validation before packaging
    Write-Host "Validating skill..."
    $validationResult = & "$PSScriptRoot/quick_validate.ps1" $skillPathItem.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Error "[ERROR] Validation failed: $validationResult"
        Write-Error "   Please fix the validation errors before packaging."
        return $null
    }
    Write-Host "[OK] $validationResult`n"
    
    # Determine output location
    $skillName = $skillPathItem.Name
    if ($OutputDir) {
        $outputPathItem = Get-Item -LiteralPath $OutputDir -ErrorAction SilentlyContinue
        if (-not $outputPathItem) {
            New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
            $outputPathItem = Get-Item -LiteralPath $OutputDir
        }
        $outputPath = $outputPathItem.FullName
    } else {
        $outputPath = Get-Location
    }
    
    $skillFilename = Join-Path $outputPath "$skillName.skill"
    
    $excludedDirs = @(".git", ".svn", ".hg", "__pycache__", "node_modules")
    
    # Create the .skill file (zip format)
    try {
        # Remove existing zip file if it exists
        if (Test-Path -LiteralPath $skillFilename) {
            Remove-Item -LiteralPath $skillFilename -Force
        }
        
        # Create temporary directory structure for compression
        $tempDir = Join-Path $env:TEMP "skill_package_$(Get-Random)"
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        
        try {
            # Copy files to temporary directory, excluding unwanted directories
            Get-ChildItem -Path $skillPathItem.FullName -Recurse -File | ForEach-Object {
                $relativePath = $_.FullName.Substring($skillPathItem.FullName.Length + 1)
                $pathParts = $relativePath -split [System.IO.Path]::DirectorySeparatorChar
                
                $shouldExclude = $false
                foreach ($part in $pathParts) {
                    if ($excludedDirs -contains $part) {
                        $shouldExclude = $true
                        break
                    }
                }
                
                if (-not $shouldExclude) {
                    $targetPath = Join-Path $tempDir $skillName $relativePath
                    $targetDir = [System.IO.Path]::GetDirectoryName($targetPath)
                    
                    if (-not (Test-Path -LiteralPath $targetDir)) {
                        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                    }
                    
                    Copy-Item -LiteralPath $_.FullName -Destination $targetPath
                    Write-Host "  Added: $skillName/$relativePath"
                }
            }
            
            # Create the zip file
            $compressPath = Join-Path $tempDir $skillName
            Compress-Archive -Path $compressPath -DestinationPath $skillFilename -CompressionLevel Optimal -Force
            
            Write-Host "`n[OK] Successfully packaged skill to: $skillFilename"
            return $skillFilename
            
        } finally {
            # Clean up temporary directory
            Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
    } catch {
        Write-Error "[ERROR] Error creating .skill file: $($_.Exception.Message)"
        return $null
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Packaging skill: $SkillPath"
    if ($OutputDirectory) {
        Write-Host "   Output directory: $OutputDirectory"
    }
    Write-Host ""
    
    $result = Package-Skill -SkillPath $SkillPath -OutputDir $OutputDirectory
    
    if ($result) {
        exit 0
    } else {
        exit 1
    }
}
