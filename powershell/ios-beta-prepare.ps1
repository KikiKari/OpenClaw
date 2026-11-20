#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "8e08d3ab1a00c11813269725271ada1eb72043f15bdf6c4bcff1e2fc1367326e", "source_sha256": "2ca708f3e5a694b78eb83d1e37cf5eefe3e601ebec3e31d771a7ebd4246aa33c", "target_language": "powershell"}
# ios-beta-prepare.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-prepare.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

function usage {
  Write-Output @"
Usage:
  `$env:OPENCLAW_PUSH_RELAY_BASE_URL = 'https://relay.example.com'
  .\scripts\ios-beta-prepare.ps1 -BuildNumber 7 [-TeamId TEAMID]

Prepares local beta-release inputs without touching local signing overrides:
- reads apps/ios/version.json and writes apps/ios/build/Version.xcconfig
- writes apps/ios/build/BetaRelease.xcconfig with canonical bundle IDs
- configures the beta build for relay-backed APNs registration
- regenerates apps/ios/OpenClaw.xcodeproj via xcodegen
"@
}

$scriptPath = $MyInvocation.MyCommand.Path
$ROOT_DIR = Join-Path (Split-Path (Split-Path $scriptPath)) ".." | Resolve-Path
$IOS_DIR = Join-Path $ROOT_DIR "apps" "ios"
$BUILD_DIR = Join-Path $IOS_DIR "build"
$BETA_XCCONFIG = Join-Path $BUILD_DIR "BetaRelease.xcconfig"
$TEAM_HELPER = Join-Path $ROOT_DIR "scripts" "ios-team-id.sh"
$VERSION_HELPER = Join-Path $ROOT_DIR "scripts" "ios-write-version-xcconfig.sh"
$IOS_VERSION_HELPER = Join-Path $ROOT_DIR "scripts" "ios-version.ts"
$VERSION_SYNC_HELPER = Join-Path $ROOT_DIR "scripts" "ios-sync-versioning.ts"

$BUILD_NUMBER = ""
$TEAM_ID = if ($env:IOS_DEVELOPMENT_TEAM) { $env:IOS_DEVELOPMENT_TEAM } else { "" }
$PUSH_RELAY_BASE_URL = if ($env:OPENCLAW_PUSH_RELAY_BASE_URL) { $env:OPENCLAW_PUSH_RELAY_BASE_URL } elseif ($env:IOS_PUSH_RELAY_BASE_URL) { $env:IOS_PUSH_RELAY_BASE_URL } else { "" }
$PUSH_RELAY_BASE_URL_XCCONFIG = ""
$IOS_VERSION = ""

function prepare_build_dir {
  if (Test-Path -Path $BUILD_DIR -PathType Leaf) {
    Write-Error "Refusing to use symlinked build directory: $BUILD_DIR"
    exit 1
  }

  if (!(Test-Path -Path $BUILD_DIR)) {
    New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null
  }
}

function write_generated_file($output_path, $content) {
  if (Test-Path -Path $output_path -PathType Leaf) {
    $item = Get-Item $output_path
    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
      Write-Error "Refusing to overwrite symlinked file: $output_path"
      exit 1
    }
  }

  $tmp_file = [System.IO.Path]::GetTempFileName()
  Set-Content -Path $tmp_file -Value $content
  Move-Item -Path $tmp_file -Destination $output_path -Force
}

function validate_push_relay_base_url($value) {
  if ($value -match "\s") {
    Write-Error "Invalid OPENCLAW_PUSH_RELAY_BASE_URL: whitespace is not allowed."
    exit 1
  }

  if ($value -match '[$()]|=' ) {
    Write-Error "Invalid OPENCLAW_PUSH_RELAY_BASE_URL: contains forbidden xcconfig characters."
    exit 1
  }

  $pattern = '^https://[A-Za-z0-9.\-]+(:([0-9]{1,5}))?(/[A-Za-z0-9._~!&*+,;:@%/\-\?]*)?$'
  if (-not ($value -match $pattern)) {
    Write-Error "Invalid OPENCLAW_PUSH_RELAY_BASE_URL: expected https://host[:port][/path]."
    exit 1
  }

  if ($matches[2]) {
    $port = [int]$matches[2]
    if ($port -lt 1 -or $port -gt 65535) {
      Write-Error "Invalid OPENCLAW_PUSH_RELAY_BASE_URL: port must be between 1 and 65535."
      exit 1
    }
  }
}

# Parse arguments
$arguments = $args.Clone()
$i = 0
while ($i -lt $arguments.Count) {
  $arg = $arguments[$i]
  switch ($arg) {
    "--" {
      $i++
    }
    "--build-number" {
      $BUILD_NUMBER = if ($i + 1 -lt $arguments.Count) { $arguments[$i+1] } else { "" }
      $i += 2
    }
    "--team-id" {
      $TEAM_ID = if ($i + 1 -lt $arguments.Count) { $arguments[$i+1] } else { "" }
      $i += 2
    }
    "-h" {
      usage
      exit 0
    }
    "--help" {
      usage
      exit 0
    }
    Default {
      Write-Error "Unknown argument: $arg"
      usage
      exit 1
    }
  }
}

if ([string]::IsNullOrEmpty($BUILD_NUMBER)) {
  Write-Error "Missing required --build-number."
  usage
  exit 1
}

if ([string]::IsNullOrEmpty($TEAM_ID)) {
  $env:IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK = "1"
  $TEAM_ID = & bash $TEAM_HELPER
}

if ([string]::IsNullOrEmpty($TEAM_ID)) {
  Write-Error "Could not resolve Apple Team ID. Set IOS_DEVELOPMENT_TEAM or sign into Xcode."
  exit 1
}

if ([string]::IsNullOrEmpty($PUSH_RELAY_BASE_URL)) {
  Write-Error "Missing OPENCLAW_PUSH_RELAY_BASE_URL (or IOS_PUSH_RELAY_BASE_URL) for beta relay registration."
  exit 1
}

validate_push_relay_base_url $PUSH_RELAY_BASE_URL

# `.xcconfig` treats `//` as a comment opener. Break the URL with a helper setting
# so Xcode still resolves it back to `https://...` at build time.
$PUSH_RELAY_BASE_URL_XCCONFIG = $PUSH_RELAY_BASE_URL -replace '//', '$(OPENCLAW_URL_SLASH)$(OPENCLAW_URL_SLASH)'

prepare_build_dir

Push-Location $ROOT_DIR
try {
  & node --import tsx $VERSION_SYNC_HELPER --check
} finally {
  Pop-Location
}

Push-Location $ROOT_DIR
try {
  $IOS_VERSION = & node --import tsx $IOS_VERSION_HELPER --field canonicalVersion
} finally {
  Pop-Location
}

if ([string]::IsNullOrEmpty($IOS_VERSION)) {
  Write-Error "Unable to resolve iOS version from $ROOT_DIR/apps/ios/version.json."
  exit 1
}

& bash $VERSION_HELPER --build-number $BUILD_NUMBER

$config_content = @"
// Auto-generated by scripts/ios-beta-prepare.ps1.
// Local beta-release override; do not commit.
OPENCLAW_CODE_SIGN_STYLE = Automatic
OPENCLAW_DEVELOPMENT_TEAM = $TEAM_ID
OPENCLAW_IOS_SELECTED_TEAM = $TEAM_ID
OPENCLAW_APP_BUNDLE_ID = ai.openclaw.client
OPENCLAW_SHARE_BUNDLE_ID = ai.openclaw.client.share
OPENCLAW_ACTIVITY_WIDGET_BUNDLE_ID = ai.openclaw.client.activitywidget
OPENCLAW_WATCH_APP_BUNDLE_ID = ai.openclaw.client.watchkitapp
OPENCLAW_WATCH_EXTENSION_BUNDLE_ID = ai.openclaw.client.watchkitapp.extension
OPENCLAW_APP_PROFILE =
OPENCLAW_SHARE_PROFILE =
OPENCLAW_PUSH_TRANSPORT = relay
OPENCLAW_PUSH_DISTRIBUTION = official
OPENCLAW_URL_SLASH = /
OPENCLAW_PUSH_RELAY_BASE_URL = $PUSH_RELAY_BASE_URL_XCCONFIG
OPENCLAW_PUSH_APNS_ENVIRONMENT = production
"@

write_generated_file $BETA_XCCONFIG $config_content

Push-Location $IOS_DIR
try {
  & xcodegen generate
} finally {
  Pop-Location
}

Write-Output "Prepared iOS beta release: version=$IOS_VERSION build=$BUILD_NUMBER team=$TEAM_ID"
Write-Output "XCODE_XCCONFIG_FILE=$BETA_XCCONFIG"
