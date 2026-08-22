#!/usr/bin/env pwsh
# package_skill.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/package_skill.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/package_skill.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Skill Packager - Creates a distributable .skill file of a skill folder

.DESCRIPTION
This script packages a skill folder into a .skill file (which is essentially a ZIP archive).
It validates the skill first and then creates the archive excluding certain directories.

.PARAMETER SkillPath
The path to the skill folder to be packaged.

.PARAMETER OutputDirectory
Optional output directory for the .skill file. Defaults to current directory.

.EXAMPLE
.\package_skill.ps1 skills/public/my-skill
.\package_skill.ps1 skills/public/my-skill -OutputDirectory ./dist
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SkillPath,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDirectory
)

# Import the validation function from quick_validate.ps1
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$validateScriptPath = Join-Path $scriptPath "quick_validate.ps1"

if (-not (Test-Path $validateScriptPath)) {
    Write-Error "[ERROR] quick_validate.ps1 not found at: $validateScriptPath"
    exit 1
}

. $validateScriptPath

function Test-IsWithin {
    param(
        [System.IO.FileInfo]$Path,
        [System.IO.DirectoryInfo]$Root
    )
    
    try {
        $relativePath = Resolve-Path -Path $Path.FullName -Relative -BasePath $Root.FullName
        return $true
    }
    catch {
        return $false
    }
}

function Package-Skill {
    param(
        [string]$SkillPath,
        [string]$OutputDir
    )
    
    $skillPathInfo = Get-Item $SkillPath -ErrorAction SilentlyContinue
    
    # Validate skill folder exists
    if (-not $skillPathInfo) {
        Write-Host "[ERROR] Skill folder not found: $SkillPath"
        return $null
    }
    
    if (-not $skillPathInfo.PSIsContainer) {
        Write-Host "[ERROR] Path is not a directory: $SkillPath"
        return $null
    }
    
    # Validate SKILL.md exists
    $skillMd = Join-Path $skillPathInfo.FullName "SKILL.md"
    if (-not (Test-Path $skillMd)) {
        Write-Host "[ERROR] SKILL.md not found in $($skillPathInfo.FullName)"
        return $null
    }
    
    # Run validation before packaging
    Write-Host "Validating skill..."
    $validationResult = Validate-Skill $skillPathInfo.FullName
    
    if (-not $validationResult.Valid) {
        Write-Host "[ERROR] Validation failed: $($validationResult.Message)"
        Write-Host "   Please fix the validation errors before packaging."
        return $null
    }
    
    Write-Host "[OK] $($validationResult.Message)`n"
    
    # Determine output location
    $skillName = $skillPathInfo.Name
    if ($OutputDir) {
        $outputPathInfo = New-Item -ItemType Directory -Path $OutputDir -Force -ErrorAction Stop
    }
    else {
        $outputPathInfo = Get-Location
    }
    
    $skillFilename = Join-Path $outputPathInfo.FullName "$skillName.skill"
    
    $excludedDirs = @(".git", ".svn", ".hg", "__pycache__", "node_modules")
    
    # Create the .skill file (zip format)
    try {
        # Remove existing file if it exists
        if (Test-Path $skillFilename) {
            Remove-Item $skillFilename -Force
        }
        
        # Create temporary directory for files to be zipped
        $tempDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())) -ErrorAction Stop
        
        try {
            # Copy files to temp directory maintaining structure
            Get-ChildItem -Path $skillPathInfo.FullName -Recurse | ForEach-Object {
                # Security: never follow or package symlinks.
                if ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                    Write-Host "[WARN] Skipping symlink: $($_.FullName)"
                    return
                }
                
                $relParts = $_.FullName.Substring($skillPathInfo.FullName.Length + 1).Split([System.IO.Path]::DirectorySeparatorChar)
                if ($relParts | Where-Object { $excludedDirs -contains $_ }) {
                    return
                }
                
                if (-not $_.PSIsContainer) {
                    $resolvedFile = Resolve-Path $_.FullName -ErrorAction Stop
                    if (-not (Test-IsWithin -Path $resolvedFile -Root $skillPathInfo)) {
                        Write-Host "[ERROR] File escapes skill root: $($_.FullName)"
                        return $null
                    }
                    
                    # If output lives under skill_path, avoid writing archive into itself.
                    if ((Resolve-Path $skillFilename -ErrorAction SilentlyContinue) -and 
                        ($resolvedFile.FullName -eq (Resolve-Path $skillFilename).Path)) {
                        Write-Host "[WARN] Skipping output archive: $($_.FullName)"
                        return
                    }
                    
                    # Calculate the relative path within the zip.
                    $relativePath = $_.FullName.Substring($skillPathInfo.FullName.Length + 1)
                    $destPath = Join-Path $tempDir.FullName $skillName $relativePath
                    
                    # Ensure parent directory exists
                    $parentDir = Split-Path $destPath -Parent
                    if (-not (Test-Path $parentDir)) {
                        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                    }
                    
                    Copy-Item $_.FullName $destPath
                    Write-Host "  Added: $(Join-Path $skillName $relativePath)"
                }
            }
            
            # Create ZIP archive
            Add-Type -Assembly System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir.FullName, $skillFilename)
            
            Write-Host "`n[OK] Successfully packaged skill to: $skillFilename"
            return $skillFilename
        }
        finally {
            # Clean up temp directory
            if (Test-Path $tempDir.FullName) {
                Remove-Item $tempDir.FullName -Recurse -Force
            }
        }
    }
    catch {
        Write-Host "[ERROR] Error creating .skill file: $($_.Exception.Message)"
        return $null
    }
}

Write-Host "Packaging skill: $SkillPath"
if ($OutputDirectory) {
    Write-Host "   Output directory: $OutputDirectory"
}
Write-Host ""

$result = Package-Skill -SkillPath $SkillPath -OutputDir $OutputDirectory

if ($result) {
    exit 0
}
else {
    exit 1
}
