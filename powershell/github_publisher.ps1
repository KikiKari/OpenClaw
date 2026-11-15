#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "d96b3e09b145c59dc830c7551bf4045f62b40d7b9989148db0f8b7cf929a7459", "source_sha256": "b7508c3367d6d569a8c1beb0e8ada0a36433c0484d97610776744335d50c4f6f", "target_language": "powershell"}
# github_publisher.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

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
    $artifactPath = [System.IO.Path]::GetFullPath($Path)
    
    if (Test-Path -Path $artifactPath -PathType SymbolicLink) {
        throw "artifact must not be a symlink"
    }
    
    $resolvedPath = Resolve-Path -Path $artifactPath -ErrorAction Stop
    $relativePath = Get-RelativePath -From $rootPath.Path -To $resolvedPath.Path
    
    $validLanguages = @("perl5", "powershell", "perl6", "tcl", "javascript", "ruby", "python", "lua", "shell", "go")
    $firstPart = ($relativePath -split '[\/\\]')[0]
    
    if (-not $firstPart -or $validLanguages -notcontains $firstPart) {
        throw "artifact is outside a language directory"
    }
    
    if (-not $State.ContainsKey("ausstehende_veroeffentlichungen")) {
        $State["ausstehende_veroeffentlichungen"] = @{}
    }
    
    $fileContent = [System.IO.File]::ReadAllBytes($artifactPath)
    $hash = Get-SHA256Hash -Data $fileContent
    $State["ausstehende_veroeffentlichungen"][$relativePath] = $hash
}

function Publish-Pending {
    param(
        [string]$Root,
        [hashtable]$State,
        [scriptblock]$Save,
        [string]$Token,
        [scriptblock]$Opener = ${function:Invoke-WebRequest}
    )

    $pending = $State["ausstehende_veroeffentlichungen"]
    if ($null -eq $pending -or $pending.GetType().Name -ne "Hashtable") {
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
        "Authorization" = "Bearer $($Token.Trim())"
        "Accept" = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
        "User-Agent" = "abstractions-manager"
    }
    
    $success = $true
    
    $pendingItems = @()
    foreach ($key in $pending.Keys) {
        $pendingItems += @{ Name = $key; Expected = $pending[$key] }
    }
    
    foreach ($item in $pendingItems) {
        $name = $item.Name
        $expected = $item.Expected
        
        try {
            $path = Join-Path $rootPath.Path $name
            
            if (Test-Path -Path $path -PathType SymbolicLink) {
                throw "invalid queued path"
            }
            
            $resolvedPath = Resolve-Path -Path $path -ErrorAction Stop
            $relativePath = Get-RelativePath -From $rootPath.Path -To $resolvedPath.Path
            
            if ($relativePath -ne $name) {
                throw "invalid queued path"
            }
            
            $data = [System.IO.File]::ReadAllBytes($path)
            $actualHash = Get-SHA256Hash -Data $data
            
            if ($actualHash -ne $expected) {
                throw "queued artifact changed"
            }
            
            function Lookup-RemoteFile($remoteName) {
                $endpoint = "https://api.github.com/repos/KikiKari/OpenClaw/contents/$([System.Uri]::EscapeDataString($remoteName))?ref=gateway1-abstractions"
                try {
                    $response = & $Opener -Uri $endpoint -Headers $headers -TimeoutSec 60
                    return @{ Endpoint = $endpoint; Content = $response.Content | ConvertFrom-Json }
                }
                catch {
                    if ($_ -match "404") {
                        return @{ Endpoint = $endpoint; Content = $null }
                    }
                    throw
                }
            }
            
            function Test-SameContent($existing, $dataBytes) {
                return ($null -ne $existing -and 
                       $existing.encoding -eq "base64" -and
                       [Convert]::FromBase64String($existing.content) -ceq $dataBytes)
            }
            
            $lookupResult = Lookup-RemoteFile -remoteName $name
            $endpoint = $lookupResult.Endpoint
            $existing = $lookupResult.Content
            
            if ($null -ne $existing -and -not (Test-SameContent -existing $existing -dataBytes $data)) {
                $candidate = [System.IO.Path]::GetFileNameWithoutExtension($name)
                $extension = [System.IO.Path]::GetExtension($name)
                $directory = Split-Path $name -Parent
                if ([string]::IsNullOrEmpty($directory)) {
                    $alternate = "$candidate_$($expected.Substring(0, 12))$extension"
                } else {
                    $alternate = Join-Path $directory "$candidate_$($expected.Substring(0, 12))$extension"
                }
                
                $lookupResult = Lookup-RemoteFile -remoteName $alternate
                $endpoint = $lookupResult.Endpoint
                $existing = $lookupResult.Content
                
                if ($null -ne $existing -and -not (Test-SameContent -existing $existing -dataBytes $data)) {
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
                
                $response = & $Opener @requestParams
                $response.Content | ConvertFrom-Json | Out-Null
            }
            
            $pending.Remove($name)
            & $Save -State $State
        }
        catch {
            $success = $false
        }
    }
    
    return $success
}

function Get-SHA256Hash {
    param([byte[]]$Data)
    
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha256.ComputeHash($Data)
        return [BitConverter]::ToString($hashBytes).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function Get-RelativePath {
    param(
        [string]$From,
        [string]$To
    )
    
    $fromUri = New-Object System.Uri($From)
    $toUri = New-Object System.Uri($To)
    $relativeUri = $fromUri.MakeRelativeUri($toUri)
    return [System.Uri]::UnescapeDataString($relativeUri.ToString()).Replace("\", "/")
}
