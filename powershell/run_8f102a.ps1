#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "3f994baf24743ec382bfff3bd2504c3c1c608b5d1c34b5bf40faf9c713fd9ff6", "source_sha256": "8f102a03732002cacc77d2ffc6fb4210aabf44652bfa80af3f96aab371d0679c", "target_language": "powershell"}
# run.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-smoke/run.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$INSTALL_URL = if ($env:OPENCLAW_INSTALL_URL) { $env:OPENCLAW_INSTALL_URL } else { "https://openclaw.bot/install.sh" }
$SMOKE_MODE = if ($env:OPENCLAW_INSTALL_SMOKE_MODE) { $env:OPENCLAW_INSTALL_SMOKE_MODE } else { "install" }
$SMOKE_PREVIOUS_VERSION = if ($env:OPENCLAW_INSTALL_SMOKE_PREVIOUS) { $env:OPENCLAW_INSTALL_SMOKE_PREVIOUS } else { "" }
$SKIP_PREVIOUS = if ($env:OPENCLAW_INSTALL_SMOKE_SKIP_PREVIOUS) { $env:OPENCLAW_INSTALL_SMOKE_SKIP_PREVIOUS } else { "0" }
$DEFAULT_PACKAGE = "openclaw"
$PACKAGE_NAME = if ($env:OPENCLAW_INSTALL_PACKAGE) { $env:OPENCLAW_INSTALL_PACKAGE } else { $DEFAULT_PACKAGE }
$FRESH_VERSION = if ($env:OPENCLAW_INSTALL_FRESH_VERSION) { $env:OPENCLAW_INSTALL_FRESH_VERSION } else { "" }
$FRESH_TAG_URL = if ($env:OPENCLAW_INSTALL_FRESH_TAG_URL) { $env:OPENCLAW_INSTALL_FRESH_TAG_URL } else { "" }
$UPDATE_BASELINE_VERSION = if ($env:OPENCLAW_INSTALL_UPDATE_BASELINE) { $env:OPENCLAW_INSTALL_UPDATE_BASELINE } else { "2026.4.10" }
$UPDATE_BASELINE_TAG_URL = if ($env:OPENCLAW_INSTALL_UPDATE_BASELINE_TAG_URL) { $env:OPENCLAW_INSTALL_UPDATE_BASELINE_TAG_URL } else { "" }
$UPDATE_EXPECT_VERSION = if ($env:OPENCLAW_INSTALL_UPDATE_EXPECT_VERSION) { $env:OPENCLAW_INSTALL_UPDATE_EXPECT_VERSION } else { "" }
$UPDATE_TAG_URL = if ($env:OPENCLAW_INSTALL_UPDATE_TAG_URL) { $env:OPENCLAW_INSTALL_UPDATE_TAG_URL } else { "" }

$SCRIPT_DIR = Split-Path $MyInvocation.MyCommand.Path -Parent

# Source cli-verify.sh equivalent
. "$SCRIPT_DIR/../install-sh-common/cli-verify.sh"

function quiet_npm {
    $output = npm @args 2>$null
    return $output
}

function verify_installed_cli {
    param($packageName, $expectedVersion)
    
    # Implementation of verify_installed_cli from sourced script
    # This would need to be properly implemented based on the original cli-verify.sh
    # For now we'll just check if the package exists and has correct version
    
    try {
        $installedVersion = npm list -g $packageName --depth=0 2>$null | Select-String "$packageName@" | ForEach-Object { ($_ -split '@')[-1] }
        if ($installedVersion -ne $expectedVersion) {
            throw "Expected version $expectedVersion but found $installedVersion"
        }
    } catch {
        throw "Failed to verify installed CLI: $_"
    }
}

function run_install_smoke {
    if ($FRESH_VERSION -and $FRESH_TAG_URL) {
        Write-Host "package=$PACKAGE_NAME latest=$FRESH_VERSION source=$FRESH_TAG_URL"
        Write-Host "==> Install latest release tarball"
        quiet_npm install -g --omit=optional "$FRESH_TAG_URL"

        Write-Host "==> Verify installed version"
        if ($env:OPENCLAW_INSTALL_LATEST_OUT) {
            Set-Content -Path $env:OPENCLAW_INSTALL_LATEST_OUT -Value $FRESH_VERSION
        }
        verify_installed_cli $PACKAGE_NAME $FRESH_VERSION

        Write-Host "OK"
        return 0
    }

    Write-Host "==> Resolve npm versions"
    if ($SKIP_PREVIOUS -eq "1") {
        $LATEST_VERSION = quiet_npm view "$PACKAGE_NAME" version
        $PREVIOUS_VERSION = $LATEST_VERSION
    } elseif ($SMOKE_PREVIOUS_VERSION) {
        $LATEST_VERSION = quiet_npm view "$PACKAGE_NAME" version
        $PREVIOUS_VERSION = $SMOKE_PREVIOUS_VERSION
    } else {
        $LATEST_VERSION = quiet_npm view "$PACKAGE_NAME" dist-tags.latest
        $VERSIONS_JSON = quiet_npm view "$PACKAGE_NAME" versions --json
        
        $nodeScript = @"
const latest = String(process.env.LATEST_VERSION || """");
const raw = process.env.VERSIONS_JSON || ""[];
let versions;
try {
  versions = JSON.parse(raw);
} catch {
  versions = raw ? [raw] : [];
}
if (!Array.isArray(versions)) {
  versions = [versions];
}
if (versions.length === 0 || latest.length === 0) {
  process.exit(1);
}
const latestIndex = versions.lastIndexOf(latest);
if (latestIndex <= 0) {
  process.stdout.write(latest);
  process.exit(0);
}
process.stdout.write(String(versions[latestIndex - 1] ?? latest));
"@
        
        $PREVIOUS_VERSION = node -e $nodeScript
    }

    Write-Host "package=$PACKAGE_NAME latest=$LATEST_VERSION previous=$PREVIOUS_VERSION"

    if ($SKIP_PREVIOUS -eq "1") {
        Write-Host "==> Skip preinstall previous (OPENCLAW_INSTALL_SMOKE_SKIP_PREVIOUS=1)"
    } else {
        Write-Host "==> Preinstall previous (forces installer upgrade path)"
        quiet_npm install -g "${PACKAGE_NAME}@${PREVIOUS_VERSION}"
    }

    Write-Host "==> Run official installer one-liner"
    Invoke-Expression "(curl -fsSL $INSTALL_URL) | bash -s -- --no-prompt"

    Write-Host "==> Verify installed version"
    if ($env:OPENCLAW_INSTALL_LATEST_OUT) {
        Set-Content -Path $env:OPENCLAW_INSTALL_LATEST_OUT -Value $LATEST_VERSION
    }
    verify_installed_cli $PACKAGE_NAME $LATEST_VERSION

    Write-Host "OK"
}

function run_update_smoke {
    if (-not $UPDATE_EXPECT_VERSION) {
        Write-Error "ERROR: OPENCLAW_INSTALL_UPDATE_EXPECT_VERSION is required for update mode"
        return 1
    }
    if (-not $UPDATE_TAG_URL) {
        Write-Error "ERROR: OPENCLAW_INSTALL_UPDATE_TAG_URL is required for update mode"
        return 1
    }

    Write-Host "package=$PACKAGE_NAME baseline=$UPDATE_BASELINE_VERSION target=$UPDATE_EXPECT_VERSION"
    Write-Host "==> Install baseline release"
    if ($UPDATE_BASELINE_TAG_URL) {
        quiet_npm install -g --omit=optional "$UPDATE_BASELINE_TAG_URL"
    } else {
        quiet_npm install -g --omit=optional "${PACKAGE_NAME}@${UPDATE_BASELINE_VERSION}"
    }
    verify_installed_cli $PACKAGE_NAME $UPDATE_BASELINE_VERSION

    Write-Host "==> Run openclaw update from host-served tgz"
    $update_stderr_file = [System.IO.Path]::GetTempFileName()
    $env:update_status = $LASTEXITCODE
    try {
        $env:NPM_CONFIG_OMIT = "optional"
        $UPDATE_JSON = npm openclaw update --tag "$UPDATE_TAG_URL" --yes --json 2>$update_stderr_file
        $update_status = $LASTEXITCODE
    } finally {
        $env:NPM_CONFIG_OMIT = $null
    }
    
    $update_stderr = Get-Content $update_stderr_file -Raw
    Remove-Item $update_stderr_file -Force
    Write-Output $UPDATE_JSON
    if ($update_stderr) {
        Write-Error $update_stderr
    }
    if ($update_status -ne 0) {
        Write-Error "ERROR: openclaw update failed with exit code $update_status"
        return $update_status
    }

    $nodeScript = @"
const payload = JSON.parse(process.env.UPDATE_JSON || "{}");
const expectedVersion = String(process.env.UPDATE_EXPECT_VERSION || "");
const baselineVersion = String(process.env.UPDATE_BASELINE_VERSION || "");
const expectedUrl = String(process.env.UPDATE_TAG_URL || "");
if (payload.status !== "ok") {
  throw new Error(`expected update status ok, got ${JSON.stringify(payload.status)}`);
}
if ((payload.before?.version ?? null) !== baselineVersion) {
  throw new Error(
    `expected before.version ${baselineVersion}, got ${JSON.stringify(payload.before?.version)}`,
  );
}
if ((payload.after?.version ?? null) !== expectedVersion) {
  throw new Error(
    `expected after.version ${expectedVersion}, got ${JSON.stringify(payload.after?.version)}`,
  );
}
if (payload.reason != null) {
  throw new Error(`expected no failure reason, got ${JSON.stringify(payload.reason)}`);
}
const steps = Array.isArray(payload.steps) ? payload.steps : [];
const updateStep = steps.find((step) => step?.name === "global update");
if (!updateStep) {
  throw new Error("missing global update step in update JSON");
}
if (Number(updateStep.exitCode ?? 1) !== 0) {
  throw new Error(`global update step failed: ${JSON.stringify(updateStep)}`);
}
if (typeof updateStep.command !== "string" || !updateStep.command.includes(expectedUrl)) {
  throw new Error(`global update step missing expected tgz URL: ${JSON.stringify(updateStep)}`);
}
"@
    
    node -e $nodeScript

    Write-Host "==> Verify updated version"
    verify_installed_cli $PACKAGE_NAME $UPDATE_EXPECT_VERSION

    Write-Host "OK"
}

switch ($SMOKE_MODE) {
    "install" {
        run_install_smoke
        break
    }
    "update" {
        run_update_smoke
        break
    }
    default {
        Write-Error "ERROR: unsupported OPENCLAW_INSTALL_SMOKE_MODE=$SMOKE_MODE"
        exit 1
        break
    }
}
