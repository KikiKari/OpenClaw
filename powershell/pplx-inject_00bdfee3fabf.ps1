#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "32262cbcc4f5a2d486ef097d22844f1aa244dc536c049e195e35e8af8e0aa7d8", "source_sha256": "9e1571035b3437fe4d1a830b7a20217de22a01508d7fc92bfed5fd58b7738b33", "target_language": "powershell"}
# pplx-inject.mjs — portiert nach powershell
# Quelle: javascript, OpenClaw@main:scripts/pplx-tools/pplx-inject.mjs
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Inject a perplexity.ai web session (the __Secure-next-auth.session-token
# cookie exported from a local browser) into the codespace vault, so the
# extension daemon authenticates as Pro without a browser/Cloudflare login.
#
# Usage: $env:PERPLEXITY_VAULT_PASSPHRASE=...; $env:PPLX_DIST=<dist>; ./pplx-inject.ps1 <cookies-file>
# (normally invoked by pplx-refresh.sh, which resolves passphrase + dist)
#
# Input file may be: a bare JWT token, a raw "Cookie:" header string, or a
# JSON array (Cookie-Editor / Playwright export).

param(
    [Parameter(Mandatory=$true)]
    [string]$File
)

$PROFILE = if ($env:PERPLEXITY_PROFILE) { $env:PERPLEXITY_PROFILE } else { "codespace" }
$EMAIL = if ($env:PPLX_EMAIL) { $env:PPLX_EMAIL } else { "KarimKiki@gmx.de" }

# --- locate the perplexity-user-mcp dist and its Vault / profile chunks ---
$DIST = $env:PPLX_DIST
if (-not $DIST -or -not (Test-Path $DIST)) {
    try {
        $DIST = (Get-ChildItem -Path "$HOME/.npm/_npx" -Recurse -Directory -Filter "*perplexity-user-mcp/dist" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
    } catch {}
}
if (-not $DIST -or -not (Test-Path $DIST)) { Write-Error "cannot locate perplexity-user-mcp/dist (set PPLX_DIST)"; exit 1 }

# Resolve chunks by following the package's own imports in a stable entry file.
# esbuild minifies class/function names, so we trust the runner's import map.
function Get-ChunkFor {
    param(
        [string]$Symbol,
        [string[]]$Entries = @("manual-login-runner.mjs", "login-runner.mjs", "cli.mjs")
    )
    
    foreach ($entry in $Entries) {
        $entryPath = Join-Path $DIST $entry
        if (-not (Test-Path $entryPath)) { continue }
        
        $src = Get-Content $entryPath -Raw
        $matches = [regex]::Matches($src, 'import\s*\{([^}]*)\}\s*from\s*"(\.\/chunk-[^"]+\.mjs)"')
        
        foreach ($match in $matches) {
            $names = $match.Groups[1].Value -split ',' | ForEach-Object { 
                ($_.Trim() -split '\s+as\s+')[0].Trim() 
            }
            if ($names -contains $Symbol) {
                return Join-Path $DIST $match.Groups[2].Value.Substring(2)
            }
        }
    }
    return $null
}

$vaultChunk = Get-ChunkFor "Vault"
$profChunk = Get-ChunkFor "getProfilePaths"
if (-not $vaultChunk -or -not $profChunk) { Write-Error "could not locate Vault/profile chunks in dist"; exit 1 }

# Import the required modules using Node.js
$nodeScript = @"
const { Vault } = await import('$vaultChunk');
const { getProfilePaths, recordLoginSuccess } = await import('$profChunk');
console.log(JSON.stringify({ Vault, getProfilePaths, recordLoginSuccess }));
"@

$imported = $nodeScript | node - | ConvertFrom-Json
$Vault = $imported.Vault
$getProfilePaths = $imported.getProfilePaths
$recordLoginSuccess = $imported.recordLoginSuccess

# --- parse the cookie input (token / header / JSON) ---
$text = (Get-Content $File -Raw).Trim()
$raw = @()

if ($text.StartsWith("[") -or $text.StartsWith("{")) {
    $parsed = $text | ConvertFrom-Json
    if ($parsed -is [array]) {
        $raw = $parsed
    } elseif ($parsed.cookies -is [array]) {
        $raw = $parsed.cookies
    } else {
        Write-Error "expected a JSON array of cookies"; exit 1
    }
} elseif ($text.StartsWith("eyJ") -and -not $text.Contains("=") -and -not $text.Contains(";")) {
    $raw = @(@{ name = "__Secure-next-auth.session-token"; value = $text })
} else {
    $raw = $text -split ';\s*' | ForEach-Object {
        if ($_.Contains("=")) {
            $parts = $_ -split '=', 2
            @{ name = $parts[0].Trim(); value = $parts[1].Trim() }
        }
    }
}

function Normalize-SameSite {
    param([string]$s)
    $v = ($s ?? "").ToLower()
    if ($v -eq "no_restriction" -or $v -eq "none") { return "None" }
    if ($v -eq "strict") { return "Strict" }
    return "Lax"
}

$cookies = $raw | Where-Object { $_ -and $_.name -and $_.value } | Where-Object {
    (-not $_.domain) -or ($_.domain -and $_.domain -match "perplexity\.ai")
} | ForEach-Object {
    $domain = if ($_.domain -and $_.domain -match "perplexity") { $_.domain } else { ".perplexity.ai" }
    $expires = if ($_.expires) { [math]::Floor($_.expires) } elseif ($_.expirationDate) { [math]::Floor($_.expirationDate) } else { -1 }
    
    @{
        name = $_.name
        value = $_.value
        domain = $domain
        path = if ($_.path) { $_.path } else { "/" }
        expires = $expires
        httpOnly = [bool]($_.httpOnly)
        secure = if ($_.secure -eq $false) { $false } else { $true }
        sameSite = Normalize-SameSite $_.sameSite
    }
}

$names = $cookies | ForEach-Object { $_.name }
Write-Host "Parsed $($cookies.Count) perplexity.ai cookies: $($names -join ', ')"
if (-not ($names | Where-Object { $_.StartsWith("__Secure-next-auth.session-token") })) {
    Write-Warning "WARNING: no '__Secure-next-auth.session-token' — session likely won't authenticate."
}

$paths = $getProfilePaths.Invoke($PROFILE)
if (-not (Test-Path $paths.dir)) { New-Item -Path $paths.dir -ItemType Directory -Force | Out-Null }

$vaultInstance = New-Object $Vault
await $vaultInstance.set($PROFILE, "cookies", ($cookies | ConvertTo-Json -Compress))
await $vaultInstance.set($PROFILE, "email", $EMAIL)

if (-not (Test-Path $paths.modelsCache)) {
    @{ models = @{} } | ConvertTo-Json -Depth 2 | Set-Content $paths.modelsCache
}

$recordLoginSuccess.Invoke($PROFILE, @{ tier = "pro"; loginMode = "manual"; lastLogin = [DateTime]::Now.ToString("o") })
[DateTime]::Now.Ticks.ToString() | Set-Content $paths.reinit
Write-Host "OK: injected $($cookies.Count) cookie(s) into vault profile '$PROFILE'."
