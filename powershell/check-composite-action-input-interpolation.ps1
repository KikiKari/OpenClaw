#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "7e193c525c1f191df17922e1d6a7fde51847e9b0c334ceba0563bd3d4032eeea", "source_sha256": "00c9566941995c9087b6e678da6c1d9714313ba570c7e02eeada841de0f8ddde", "target_language": "powershell"}
# check-composite-action-input-interpolation.py — portiert nach powershell
# Quelle: python, workspace@local:skills/github-clones/openclaw/scripts/check-composite-action-input-interpolation.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

$INPUT_INTERPOLATION_RE = [regex] '\$\{\{\s*inputs\.'
$RUN_LINE_RE = [regex] '^\s*run:\s*(.*)$'
$USING_COMPOSITE_RE = [regex] '^\s*using:\s*composite\s*$'

function Get-Indentation {
    param(
        [string]$Line
    )
    return $Line.Length - $Line.TrimStart().Length
}

function Scan-File {
    param(
        [System.IO.FileInfo]$Path
    )
    
    $Text = [System.IO.File]::ReadAllText($Path.FullName, [System.Text.Encoding]::UTF8)
    if (-not $USING_COMPOSITE_RE.IsMatch($Text)) {
        return @()
    }
    
    $Lines = $Text -split "`n"
    $Violations = @()
    $LineCount = $Lines.Count
    $Index = 0
    
    while ($Index -lt $LineCount) {
        $Line = $Lines[$Index]
        $Match = $RUN_LINE_RE.Match($Line)
        if (-not $Match.Success) {
            $Index++
            continue
        }
        
        $RunIndent = $Match.Groups[1].Value.Length
        $RunValue = $Match.Groups[2].Value.Trim()
        $LineNo = $Index + 1
        
        if ($RunValue -and $RunValue[0] -notin @('|', '>')) {
            if ($INPUT_INTERPOLATION_RE.IsMatch($RunValue)) {
                $Violations += ,@($LineNo, $Line.Trim())
            }
            $Index++
            continue
        }
        
        $Index++
        while ($Index -lt $LineCount) {
            $ScriptLine = $Lines[$Index]
            if ($ScriptLine.Trim() -eq "") {
                $Index++
                continue
            }
            if ((Get-Indentation $ScriptLine) -le $RunIndent) {
                break
            }
            if ($INPUT_INTERPOLATION_RE.IsMatch($ScriptLine)) {
                $Violations += ,@($Index + 1, $ScriptLine.Trim())
            }
            $Index++
        }
    }
    
    return $Violations
}

function Main {
    $Root = [System.IO.DirectoryInfo]".github/actions"
    if (-not $Root.Exists) {
        Write-Host "No .github/actions directory found."
        return 0
    }
    
    $Files = Get-ChildItem -Path $Root.FullName -Recurse -Name "action.y*ml" | 
             Sort-Object FullName
    
    $AllViolations = @()
    
    foreach ($FilePath in $Files) {
        $FullFilePath = [System.IO.Path]::Combine($Root.FullName, $FilePath)
        $FileViolations = Scan-File -Path ([System.IO.FileInfo]$FullFilePath)
        foreach ($Violation in $FileViolations) {
            $AllViolations += ,@([System.IO.Path]::GetRelativePath(".", $FullFilePath), $Violation[0], $Violation[1])
        }
    }
    
    if ($AllViolations.Count -gt 0) {
        Write-Host "Disallowed direct inputs interpolation in composite run blocks:"
        foreach ($Violation in $AllViolations) {
            Write-Host "- $($Violation[0]):$($Violation[1]): $($Violation[2])"
        }
        Write-Host "Use env: and reference shell variables instead."
        return 1
    }
    
    Write-Host "No direct inputs interpolation found in composite run blocks."
    return 0
}

exit (Main)
