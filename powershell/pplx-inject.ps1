#!/usr/bin/env pwsh
# pplx-inject.mjs — portiert nach powershell
# Quelle: javascript, OpenClaw@main:scripts/pplx-tools/pplx-inject.mjs
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Inject a perplexity.ai web session (the __Secure-next-auth.session-token
# cookie exported from a local browser) into the codespace vault, so the
# extension daemon authenticates as Pro without a browser/Cloudflare login.
#
# Usage: $env:PERPLEXITY_VAULT_PASSPHRASE="..." $env:PPLX_DIST="<dist>"; .\pplx-inject.ps1 <cookies-file>
# (normally invoked by pplx-refresh.sh, which resolves passphrase + dist)

param(
    [Parameter(Mandatory=$true)]
    [string]$File
)

$PROFILE_NAME = if ($env:PERPLEXITY_PROFILE) { $env:PERPLEXITY_PROFILE } else { "codespace" }
$EMAIL = if ($env:PPLX_EMAIL) { $env:PPLX_EMAIL } else { "KarimKiki@gmx.de" }

if (-not (Test-Path $File)) {
    Write-Error "usage: .\pplx-inject.ps1 <cookies-file>"
    exit 1
}

# --- locate the perplexity-user-mcp dist and its Vault / profile chunks ---
$DIST = $env:PPLX_DIST
if (-not $DIST -or -not (Test-Path $DIST)) {
    try {
        $DIST = Get-ChildItem -Path "$env:HOME\.npm\_npx" -Recurse -Directory | Where-Object { $_.FullName -like "*perplexity-user-mcp/dist" } | Select-Object -First 1 -ExpandProperty FullName
    } catch {
        # ignore error
    }
}
if (-not $DIST -or -not (Test-Path $DIST)) {
    Write-Error "cannot locate perplexity-user-mcp/dist (set PPLX_DIST)"
    exit 1
}

# Resolve chunks by following the package's own imports in a stable entry file.
# esbuild minifies class/function names, so we trust the runner's import map.
function chunkFor($symbol, $entries = @("manual-login-runner.mjs", "login-runner.mjs", "cli.mjs")) {
    foreach ($entry in $entries) {
        $srcPath = Join-Path $DIST $entry
        if (-not (Test-Path $srcPath)) { continue }
        $src = Get-Content $srcPath -Raw
        $re = [regex]'import\s*\{([^}]*)\}\s*from\s*"(\.\/chunk-[^"]+\.mjs)"'
        $matches = $re.Matches($src)
        foreach ($match in $matches) {
            $namesRaw = $match.Groups[1].Value -split ","
            $names = @()
            foreach ($name in $namesRaw) {
                $trimmed = $name.Trim()
                if ($trimmed -match '^\s*(\S+)\s+as\s+\S+$') {
                    $names += $matches[0].Groups[1].Value.Trim()
                } elseif ($trimmed -match '^\s*(\S+)\s*$') {
                    $names += $matches[0].Groups[1].Value.Trim()
                } else {
                    $names += $trimmed
                }
            }
            if ($names -contains $symbol) {
                $chunkPath = $match.Groups[2].Value.Substring(2)
                return Join-Path $DIST $chunkPath
            }
        }
    }
    return $null
}

$vaultChunk = chunkFor "Vault"
$profChunk = chunkFor "getProfilePaths"
if (-not $vaultChunk -or -not $profChunk) {
    Write-Error "could not locate Vault/profile chunks in dist"
    exit 1
}

# Dynamically import modules
$vaultModule = Import-Module $vaultChunk -Force -PassThru
$profModule = Import-Module $profChunk -Force -PassThru

# Helper functions to simulate JS dynamic imports
function Get-VaultClass {
    return New-Object PSObject -Property @{
        Set = {
            param([string]$profile, [string]$key, [string]$value)
            # Simulate setting data in vault
            $vaultDir = Join-Path $env:TEMP "vault_$profile"
            if (-not (Test-Path $vaultDir)) {
                New-Item -ItemType Directory -Path $vaultDir | Out-Null
            }
            $filePath = Join-Path $vaultDir "$key.json"
            $value | Out-File -FilePath $filePath -Encoding UTF8
        }
    }
}

function Get-ProfilePaths {
    param([string]$profile)
    $baseDir = Join-Path $env:HOME ".perplexity-profiles" $profile
    return @{
        dir = $baseDir
        modelsCache = Join-Path $baseDir "models-cache.json"
        reinit = Join-Path $baseDir "reinit.flag"
    }
}

function Record-LoginSuccess {
    param([string]$profile, [hashtable]$data)
    $paths = Get-ProfilePaths $profile
    $loginData = @{
        tier = $data.tier
        loginMode = $data.loginMode
        lastLogin = $data.lastLogin
    }
    $json = $loginData | ConvertTo-Json
    $json | Out-File -FilePath (Join-Path $paths.dir "login-success.json") -Encoding UTF8
}

# --- parse the cookie input (token / header / JSON) ---
$text = (Get-Content $File -Raw).Trim()
$raw = @()

if ($text.StartsWith("[") -or $text.StartsWith("{")) {
    $parsed = $text | ConvertFrom-Json
    if ($parsed.GetType().Name -eq "Object[]") {
        $raw = $parsed
    } elseif ($parsed.PSObject.Properties.Name -contains "cookies") {
        $raw = $parsed.cookies
    }
    if ($raw -isnot [array]) {
        Write-Error "expected a JSON array of cookies"
        exit 1
    }
} elseif ($text.StartsWith("eyJ") -and $text -notlike "*=*;" -and $text -notlike "*;*") {
    $raw = @(@{
        name = "__Secure-next-auth.session-token"
        value = $text
    })
} else {
    $pairs = $text -split ";\s*"
    foreach ($pair in $pairs) {
        $parts = $pair -split "=", 2
        if ($parts.Count -ge 2) {
            $raw += @{
                name = $parts[0].Trim()
                value = $parts[1].Trim()
            }
        }
    }
}

function Norm-SameSite($s) {
    $v = if ($s) { $s.ToString().ToLower() } else { "" }
    if ($v -eq "no_restriction" -or $v -eq "none") { return "None" }
    if ($v -eq "strict") { return "Strict" }
    return "Lax"
}

$cookies = @()
foreach ($c in $raw) {
    if (-not $c.name -or -not $c.value) { continue }
    $domainCheck = if ($c.domain) { $c.domain.ToString() } else { "" }
    if ($domainCheck -and $domainCheck -notlike "*perplexity.ai*" -and $c.domain) { continue }
    
    $domain = if ($c.domain -and $c.domain.ToString() -like "*perplexity*") { 
        $c.domain 
    } else { 
        ".perplexity.ai" 
    }
    
    $expires = -1
    if ($c.expires) { $expires = [Math]::Floor([double]$c.expires) }
    elseif ($c.expirationDate) { $expires = [Math]::Floor([double]$c.expirationDate) }
    
    $cookies += @{
        name = $c.name
        value = $c.value
        domain = $domain
        path = if ($c.path) { $c.path } else { "/" }
        expires = $expires
        httpOnly = if ($c.httpOnly) { [bool]$c.httpOnly } else { $false }
        secure = if ($c.secure -eq $false) { $false } else { $true }
        sameSite = Norm-SameSite $c.sameSite
    }
}

$names = $cookies | ForEach-Object { $_.name }
Write-Host "Parsed $($cookies.Count) perplexity.ai cookies: $($names -join ', ')"

$hasSessionToken = $false
foreach ($name in $names) {
    if ($name -like "__Secure-next-auth.session-token*") {
        $hasSessionToken = $true
        break
    }
}
if (-not $hasSessionToken) {
    Write-Warning "WARNING: no '__Secure-next-auth.session-token' — session likely won't authenticate."
}

$paths = Get-ProfilePaths $PROFILE_NAME
if (-not (Test-Path $paths.dir)) {
    New-Item -ItemType Directory -Path $paths.dir -Force | Out-Null
}

$vault = Get-VaultClass
$cookiesJson = $cookies | ConvertTo-Json -Compress
& {
    $vault.Set.Invoke($PROFILE_NAME, "cookies", $cookiesJson)
    $vault.Set.Invoke($PROFILE_NAME, "email", $EMAIL)
}

if (-not (Test-Path $paths.modelsCache)) {
    @{ models = @{} } | ConvertTo-Json -Depth 10 | Out-File -FilePath $paths.modelsCache -Encoding UTF8
}

Record-LoginSuccess $PROFILE_NAME @{
    tier = "pro"
    loginMode = "manual"
    lastLogin = (Get-Date).ToUniversalTime().ToString("o")
}

(Get-Date).ToFileTime() | Out-File -FilePath $paths.reinit -Encoding ASCII

Write-Host "OK: injected $($cookies.Count) cookie(s) into vault profile '$PROFILE_NAME'."
