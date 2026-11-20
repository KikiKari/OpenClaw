#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "d766c13d82cf323c6da44f01ae8ed67d32adf63bc9898ab247dc17fa96b626f0", "source_sha256": "f198925e5c21dc828628def1707ba79512014dafa5a425580bbf80881a4b0ed7", "target_language": "powershell"}
# ghsa-patch.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/ghsa-patch.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

function Show-Usage {
    Write-Error @(
        "Usage:"
        "  pwsh ghsa-patch.ps1 --ghsa <GHSA-id-or-url> [--repo owner/name]"
        "    --summary <text> --severity <low|medium|high|critical>"
        "    --description-file <path>"
        "    --vulnerable-version-range <range>"
        "    --patched-versions <range-or-null>"
        "    [--package openclaw] [--ecosystem npm] [--cvss <vector>]"
    ) -ErrorAction Stop
}

function Fail-WithMessage($message) {
    Write-Error $message -ErrorAction Stop
}

function Parse-Arguments($argv) {
    $out = @{}
    for ($i = 0; $i -lt $argv.Count; $i++) {
        $arg = $argv[$i]
        if (-not $arg.StartsWith("--")) {
            Fail-WithMessage "Unexpected argument: $arg"
        }
        $key = $arg.Substring(2)
        $value = $argv[$i + 1]
        if ([string]::IsNullOrWhiteSpace($value) -or $value.StartsWith("--")) {
            Fail-WithMessage "Missing value for --$key"
        }
        $out[$key] = $value
        $i++
    }
    return $out
}

function Invoke-GhCommand($arguments) {
    $proc = Start-Process -FilePath "gh" -ArgumentList $arguments -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$env:TEMP\stdout.txt" -RedirectStandardError "$env:TEMP\stderr.txt"
    $stdout = Get-Content "$env:TEMP\stdout.txt" -Raw
    $stderr = Get-Content "$env:TEMP\stderr.txt" -Raw
    Remove-Item "$env:TEMP\stdout.txt", "$env:TEMP\stderr.txt" -Force -ErrorAction SilentlyContinue
    
    if ($proc.ExitCode -ne 0) {
        $errorOutput = $stderr.Trim()
        if ([string]::IsNullOrWhiteSpace($errorOutput)) {
            $errorOutput = $stdout.Trim()
        }
        if ([string]::IsNullOrWhiteSpace($errorOutput)) {
            $errorOutput = "gh $($arguments -join ' ') failed"
        }
        Fail-WithMessage $errorOutput
    }
    return $stdout
}

function Derive-RepoFromOrigin {
    try {
        $remote = git remote get-url origin 2>&1 | Out-String
        $remote = $remote.Trim()
        $httpsMatch = [regex]::Match($remote, 'github\.com[/:]([^/]+)/([^/.]+)(?:\.git)?$')
        if (-not $httpsMatch.Success) {
            Fail-WithMessage "Could not parse origin remote: $remote"
        }
        return "$($httpsMatch.Groups[1].Value)/$($httpsMatch.Groups[2].Value)"
    } catch {
        Fail-WithMessage "Failed to execute git command: $_"
    }
}

function Parse-GhsaId($value) {
    $match = [regex]::Match($value, 'GHSA-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) {
        Fail-WithMessage "Could not parse GHSA id from: $value"
    }
    return $match.Value
}

function Write-TempJson($data) {
    $guid = [System.Guid]::NewGuid().ToString()
    $file = Join-Path $env:TEMP "ghsa-patch-$guid.json"
    $json = $data | ConvertTo-Json -Depth 10
    Set-Content -Path $file -Value "$json`n" -Encoding UTF8
    return $file
}

# Main script execution starts here
$argsHash = Parse-Arguments $args

if (-not $argsHash.ContainsKey("ghsa") -or 
    -not $argsHash.ContainsKey("summary") -or 
    -not $argsHash.ContainsKey("severity") -or 
    -not $argsHash.ContainsKey("description-file")) {
    Show-Usage
    exit 1
}

$repo = if ($argsHash.ContainsKey("repo")) { $argsHash["repo"] } else { Derive-RepoFromOrigin }
$ghsaId = Parse-GhsaId $argsHash["ghsa"]
$advisoryPath = "/repos/$repo/security-advisories/$ghsaId"
$descriptionPath = Resolve-Path $argsHash["description-file"]

if (-not (Test-Path $descriptionPath)) {
    Fail-WithMessage "Description file does not exist: $descriptionPath"
}

$current = Invoke-GhCommand @("api", "-H", "X-GitHub-Api-Version: 2022-11-28", $advisoryPath) | ConvertFrom-Json
$restoredCvss = if ($argsHash.ContainsKey("cvss")) { $argsHash["cvss"] } elseif ($current.PSObject.Properties.Name -contains "cvss" -and $current.cvss.vector_string) { $current.cvss.vector_string } else { $null }

$ecosystem = if ($argsHash.ContainsKey("ecosystem")) { $argsHash["ecosystem"] } else { "npm" }
$packageName = if ($argsHash.ContainsKey("package")) { $argsHash["package"] } else { "openclaw" }
$vulnerableRange = $argsHash["vulnerable-version-range"]
$patchedVersionsRaw = $argsHash["patched-versions"]

if (-not $vulnerableRange) {
    Fail-WithMessage "Missing --vulnerable-version-range"
}
if ($null -eq $patchedVersionsRaw) {
    Fail-WithMessage "Missing --patched-versions"
}

$patchedVersions = if ($patchedVersionsRaw -eq "null") { $null } else { $patchedVersionsRaw }
$description = Get-Content -Path $descriptionPath -Raw -Encoding UTF8

$payload = @{
    summary = $argsHash["summary"]
    severity = $argsHash["severity"]
    description = $description
    vulnerabilities = @(
        @{
            package = @{
                ecosystem = $ecosystem
                name = $packageName
            }
            vulnerable_version_range = $vulnerableRange
            patched_versions = $patchedVersions
            vulnerable_functions = @()
        }
    )
}

$patchFile = Write-TempJson $payload
Invoke-GhCommand @("api", "-H", "X-GitHub-Api-Version: 2022-11-28", "-X", "PATCH", $advisoryPath, "--input", $patchFile)

if ($restoredCvss) {
    Invoke-GhCommand @("api", "-H", "X-GitHub-Api-Version: 2022-11-28", "-X", "PATCH", $advisoryPath, "-f", "cvss_vector_string=$restoredCvss")
}

$refreshed = Invoke-GhCommand @("api", "-H", "X-GitHub-Api-Version: 2022-11-28", $advisoryPath) | ConvertFrom-Json

$result = @{
    html_url = $refreshed.html_url
    state = $refreshed.state
    severity = $refreshed.severity
    summary = $refreshed.summary
    vulnerabilities = $refreshed.vulnerabilities
    cvss = $refreshed.cvss
    updated_at = $refreshed.updated_at
}

Write-Output ($result | ConvertTo-Json -Depth 10)
