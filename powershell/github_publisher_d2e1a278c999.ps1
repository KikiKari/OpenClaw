#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "18b2ee6c2f0538534ef5e99b1b491f3f0b525b07959140fff2592eeb5e5325a0", "source_sha256": "b7508c3367d6d569a8c1beb0e8ada0a36433c0484d97610776744335d50c4f6f", "target_language": "powershell"}
# github_publisher.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Publish queued, provenance-checked artifacts without staging unrelated files.
#>

function Queue-Artifact {
    param(
        [hashtable]$State,
        [string]$Root,
        [string]$Path
    )

    $rootPath = Resolve-Path $Root
    $artifactPath = Get-Item $Path -ErrorAction Stop
    
    if ($artifactPath.LinkType -eq "SymbolicLink") {
        throw "artifact must not be a symlink"
    }
    
    $resolvedPath = Resolve-Path $Path -ErrorAction Stop
    $relativePath = Resolve-Path $resolvedPath -Relative -ErrorAction Stop
    $relativePath = $relativePath -replace "^\.\\", ""
    
    $parts = $relativePath -split "[\\/]"
    if (-not $parts[0] -or $parts[0] -notin @("perl5", "powershell", "perl6", "tcl", "javascript", "ruby", "python", "lua", "shell", "go")) {
        throw "artifact is outside a language directory"
    }
    
    $content = Get-Content $Path -Raw -AsByteStream -ErrorAction Stop
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($content)
    $hexHash = [BitConverter]::ToString($hash) -replace "-", ""
    
    if (-not $State.ContainsKey("ausstehende_veroeffentlichungen")) {
        $State["ausstehende_veroeffentlichungen"] = @{}
    }
    $State["ausstehende_veroeffentlichungen"][$relativePath] = $hexHash.ToLower()
}

function Publish-Pending {
    param(
        [string]$Root,
        [hashtable]$State,
        [scriptblock]$Save,
        [string]$Token
    )

    $pending = $State["ausstehende_veroeffentlichungen"]
    if ($null -eq $pending) { $pending = @{} }
    
    if ($pending.GetType().Name -ne "Hashtable") {
        throw "invalid publication queue"
    }
    
    if ($pending.Count -eq 0) {
        return $true
    }
    
    if ([string]::IsNullOrWhiteSpace($Token)) {
        return $false
    }
    
    $rootPath = Resolve-Path $Root
    $headers = @{
        Authorization = "Bearer $Token"
        Accept = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
        "User-Agent" = "abstractions-manager"
    }
    
    $success = $true
    
    $pendingClone = @{}
    foreach ($key in $pending.Keys) {
        $pendingClone[$key] = $pending[$key]
    }
    
    foreach ($item in $pendingClone.GetEnumerator()) {
        $name = $item.Key
        $expected = $item.Value
        
        try {
            $path = Join-Path $rootPath $name
            
            $artifactInfo = Get-Item $path -ErrorAction Stop
            if ($artifactInfo.LinkType -eq "SymbolicLink") {
                throw "invalid queued path"
            }
            
            $resolvedPath = Resolve-Path $path -ErrorAction Stop
            $relativePath = Resolve-Path $resolvedPath -Relative -ErrorAction Stop
            $relativePath = $relativePath -replace "^\.\\", ""
            
            if ($relativePath -ne $name) {
                throw "invalid queued path"
            }
            
            $data = Get-Content $path -Raw -AsByteStream -ErrorAction Stop
            $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($data)
            $actualHexHash = [BitConverter]::ToString($hash) -replace "-", ""
            
            if ($actualHexHash.ToLower() -ne $expected) {
                throw "queued artifact changed"
            }
            
            function Lookup-RemoteFile($remoteName) {
                $encodedName = [Uri]::EscapeDataString($remoteName)
                $endpoint = "https://api.github.com/repos/KikiKari/OpenClaw/contents/$encodedName"
                $uri = "$endpoint?ref=gateway1-abstractions"
                
                try {
                    $response = Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 60 -ErrorAction Stop
                    return $endpoint, $response
                }
                catch {
                    if ($_.Exception.Response.StatusCode -eq 404) {
                        return $endpoint, $null
                    }
                    else {
                        throw
                    }
                }
            }
            
            function Test-SameContent($existing, $fileData) {
                return ($null -ne $existing -and 
                       $existing.encoding -eq "base64" -and
                       [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($existing.content)) -eq [System.Text.Encoding]::UTF8.GetString($fileData))
            }
            
            $endpoint, $existing = Lookup-RemoteFile -remoteName $name
            
            if ($null -ne $existing -and -not (Test-SameContent -existing $existing -fileData $data)) {
                $candidate = [System.IO.Path]::GetDirectoryName($name)
                if ([string]::IsNullOrEmpty($candidate)) { $candidate = "." }
                $fileName = [System.IO.Path]::GetFileNameWithoutExtension($name)
                $extension = [System.IO.Path]::GetExtension($name)
                $alternate = Join-Path $candidate "$fileName_$($expected.Substring(0, 12))$extension"
                $alternate = $alternate -replace "\\", "/"
                
                $endpoint, $existing = Lookup-RemoteFile -remoteName $alternate
                
                if ($null -ne $existing -and -not (Test-SameContent -existing $existing -fileData $data)) {
                    throw "remote artifact conflict"
                }
            }
            
            if ($null -eq $existing) {
                $base64Content = [Convert]::ToBase64String($data)
                $body = @{
                    message = "Publish script abstraction"
                    branch = "gateway1-abstractions"
                    content = $base64Content
                } | ConvertTo-Json -Compress
                
                $requestParams = @{
                    Uri = $endpoint
                    Method = "PUT"
                    Headers = $headers
                    Body = $body
                    ContentType = "application/json"
                    TimeoutSec = 60
                }
                
                Invoke-RestMethod @requestParams -ErrorAction Stop | Out-Null
            }
            
            $pending.Remove($name)
            & $Save $State
        }
        catch {
            $success = $false
        }
    }
    
    return $success
}
