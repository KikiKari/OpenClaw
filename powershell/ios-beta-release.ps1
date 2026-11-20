#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "117e66fac5bfc6d851bcac20e4f4ea42ac87e944de45ea6de91cf3e6bcefe04c", "source_sha256": "74168ccc75bdca2481fb7bf1298fad30cea4e5fdd917205e7f1815e86948ca0c", "target_language": "powershell"}
# ios-beta-release.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-release.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

function Show-Usage {
    Write-Output @"
Usage:
  scripts/ios-beta-release.sh [--build-number 7]

Archives and uploads a beta-release IPA to TestFlight locally.
"@
}

$BUILD_NUMBER = $env:IOS_BETA_BUILD_NUMBER
$ROOT_DIR = Join-Path $PSScriptRoot ".." | Resolve-Path

$i = 0
while ($i -lt $args.Count) {
    switch ($args[$i]) {
        "--" {
            $i++
        }
        "--build-number" {
            if (($i + 1) -lt $args.Count) {
                $BUILD_NUMBER = $args[$i + 1]
                $i += 2
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
        Default {
            Write-Error "Unknown argument: $($args[$i])"
            Show-Usage
            exit 1
        }
    }
}

Push-Location (Join-Path $ROOT_DIR "apps/ios")
try {
    $env:IOS_BETA_BUILD_NUMBER = $BUILD_NUMBER
    fastlane ios beta
} finally {
    Pop-Location
}
