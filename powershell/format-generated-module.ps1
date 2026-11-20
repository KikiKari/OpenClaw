#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "8879bf80c48c20ab2e4f083539d8b89bc1155d4b15be1ad8f5743f0812d821cb", "source_sha256": "5826d57477404d40d10bccd3a144f22f3f46ce4897073fa71d1d3868edfe8719", "target_language": "powershell"}
# format-generated-module.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/format-generated-module.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

function Format-GeneratedModule {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Source,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Options
    )
    
    $repoRoot = $Options.repoRoot
    $outputPath = $Options.outputPath
    $errorLabel = $Options.errorLabel
    
    $resolvedRepoRoot = Resolve-Path -Path $repoRoot
    $relativePath = $outputPath
    if ([System.IO.Path]::IsPathRooted($outputPath)) {
        $relativePath = Resolve-Path -Path $outputPath -RelativeBasePath $resolvedRepoRoot
    }
    $resolvedOutputPath = Join-Path $resolvedRepoRoot $relativePath
    
    $directFormatterPath = Join-Path $resolvedRepoRoot "node_modules" ".bin" "oxfmt"
    $useDirectFormatter = $false
    if ($env:OS -notlike "Windows*" -and (Test-Path $directFormatterPath)) {
        $useDirectFormatter = $true
    }
    
    $command = "pnpm"
    if ($useDirectFormatter) {
        $command = $directFormatterPath
    }
    
    $tempDir = New-TemporaryFile | % { 
        Remove-Item $_ -Force
        New-Item -ItemType Directory -Path (Join-Path $_.DirectoryName "openclaw-generated-format-$([System.Guid]::NewGuid().ToString())")
    }
    $tempOutputPath = Join-Path $tempDir ([System.IO.Path]::GetFileName($resolvedOutputPath))
    
    try {
        Set-Content -Path $tempOutputPath -Value $Source -Encoding UTF8
        
        $args = @()
        if ($useDirectFormatter) {
            $args = @("--write", $tempOutputPath)
        } else {
            $args = @("exec", "oxfmt", "--write", $tempOutputPath)
        }
        
        $startParams = @{
            FilePath = $command
            ArgumentList = $args
            WorkingDirectory = $resolvedRepoRoot
            Wait = $true
            NoNewWindow = $true
            PassThru = $true
        }
        
        # Windows requires a shell to launch package-manager shim scripts reliably.
        if ($env:OS -like "Windows*") {
            $startParams.UseShellExecute = $false
        }
        
        $formatter = Start-Process @startParams
        
        if ($formatter.ExitCode -ne 0) {
            $details = ""
            if ($formatter.StandardError -and $formatter.StandardError.Trim()) {
                $details = $formatter.StandardError.Trim()
            } elseif ($formatter.StandardOutput -and $formatter.StandardOutput.Trim()) {
                $details = $formatter.StandardOutput.Trim()
            } elseif ($formatter.Error) {
                $details = $formatter.Error.Message
            } else {
                $details = "unknown formatter failure"
            }
            throw "failed to format generated $errorLabel`: $details"
        }
        
        return Get-Content -Path $tempOutputPath -Raw -Encoding UTF8
    }
    finally {
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
}
