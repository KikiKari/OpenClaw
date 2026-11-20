#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "e1776681e795292c2012e966eccb5d6c8775fa05356bfc4b4090348798b876bf", "source_sha256": "2cdcdc862375b173b06398d139b611f6f002e0435191f56d26d3e48a3cef02cf", "target_language": "powershell"}
# ios-beta-archive.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-archive.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

function Show-Usage {
    Write-Output @"
Usage:
  scripts/ios-beta-archive.sh [--build-number 7]

Archives and exports a beta-release IPA locally without uploading.
"@
}

$BUILD_NUMBER = $env:IOS_BETA_BUILD_NUMBER ?? ""

# Get the script's directory and resolve the root path
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ROOT_DIR = Resolve-Path (Join-Path $ScriptDir "..")

# Parse command line arguments
$Arguments = $args
$Index = 0

while ($Index -lt $Arguments.Count) {
    $Arg = $Arguments[$Index]
    
    switch ($Arg) {
        "--" {
            $Index++
        }
        "--build-number" {
            if ($Index + 1 -lt $Arguments.Count) {
                $BUILD_NUMBER = $Arguments[$Index + 1]
                $Index += 2
            } else {
                Write-Error "Missing value for --build-number"
                Show-Usage
                exit 1
            }
        }
        "-h" {
            Show-Usage
            exit 0
        }
        "--help" {
            Show-Usage
            exit 0
        }
        default {
            Write-Error "Unknown argument: $Arg"
            Show-Usage
            exit 1
        }
    }
}

# Change to the iOS directory and execute fastlane
try {
    Push-Location (Join-Path $ROOT_DIR "apps/ios")
    $env:IOS_BETA_BUILD_NUMBER = $BUILD_NUMBER
    fastlane ios beta_archive
} finally {
    Pop-Location
}
