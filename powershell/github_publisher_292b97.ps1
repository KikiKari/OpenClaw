#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "6c2385ed2ccac1acf0206a12a2f07846fb88a95d002a88c017a97fe5496487ab", "source_sha256": "292b977dd14f55e08a3852eccaf235d04d5f7e909ab6139a9ab2e379ae2305a1", "target_language": "powershell"}
# github_publisher.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Publish queued, provenance-checked artifacts without staging unrelated files.
#>

using namespace System.Security.Cryptography
using namespace System.Text
using namespace System.Text.Json
using namespace System.IO
using namespace System.Net

# Define LANGUAGES as an array of strings
$global:LANGUAGES = @("perl5", "powershell", "perl6", "tcl", "javascript", "ruby", "python", "lua", "shell", "go")

function Get-SHA256Hash {
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$Data
    )
    
    $sha256 = [SHA256]::Create()
    try {
        $hashBytes = $sha256.ComputeHash($Data)
        return [BitConverter]::ToString($hashBytes).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function Get-SHA256FileHash {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    $bytes = [File]::ReadAllBytes($Path)
    return Get-SHA256Hash -Data $bytes
}

function Invoke-GitClone {
    param(
        [string]$Remote,
        [string]$Branch,
        [string]$Destination
    )
    
    $gitArgs = @("clone", "--quiet", "--depth=1", "--single-branch", "--branch", $Branch, "--", $Remote, $Destination)
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "git"
    $pinfo.Arguments = ($gitArgs | ForEach-Object { "`"$_`"" }) -join " "
    $pinfo.UseShellExecute = $false
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.CreateNoWindow = $true
    
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit(300000) # 5 minutes timeout
    
    if ($p.ExitCode -ne 0) {
        throw "Git clone failed with exit code $($p.ExitCode)"
    }
}

function Get-GitRevision {
    param(
        [string]$RepoPath
    )
    
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "git"
    $pinfo.Arguments = "-C `"$RepoPath`" rev-parse HEAD"
    $pinfo.UseShellExecute = $false
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.CreateNoWindow = $true
    
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $output = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit(30000) # 30 seconds timeout
    
    if ($p.ExitCode -ne 0) {
        throw "Git rev-parse failed with exit code $($p.ExitCode)"
    }
    
    return $output.Trim()
}

function Sync-Checkout {
    <#
    .SYNOPSIS
    Reconcile a remote snapshot into the checkout without changing its Git history.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Root,
        
        [string]$Remote = "https://github.com/KikiKari/OpenClaw.git",
        
        [string]$Branch = "gateway1-abstractions"
    )
    
    $rootPath = Resolve-Path $Root
    $tempDir = New-TemporaryFile | % { Remove-Item $_; mkdir $_ }
    try {
        $snapshot = Join-Path $tempDir.FullName "repo"
        Invoke-GitClone -Remote $Remote -Branch $Branch -Destination $snapshot
        $revision = Get-GitRevision -RepoPath $snapshot
        
        $counts = @{}
        
        foreach ($language in ($global:LANGUAGES | Sort-Object)) {
            $source = Join-Path $snapshot $language
            $target = Join-Path $rootPath $language
            
            # Check if directories are symlinks (PowerShell doesn't have direct support, so we skip this check)
            
            if (Test-Path $source -PathType Leaf) {
                throw "Invalid remote language directory"
            }
            
            if (!(Test-Path $target)) {
                New-Item -ItemType Directory -Path $target | Out-Null
            }
            
            $known = @{}
            if (Test-Path $target) {
                Get-ChildItem -Path $target -File | ForEach-Object {
                    $fileHash = Get-SHA256FileHash -Path $_.FullName
                    $known[$fileHash] = $true
                }
            }
            
            $files = @()
            if (Test-Path $source) {
                $files = Get-ChildItem -Path $source -File
                # Check for invalid abstractions (symlinks or non-files)
                foreach ($file in $files) {
                    if ($file.LinkType -eq "SymbolicLink") {
                        throw "Invalid remote abstraction"
                    }
                }
            }
            
            $counts[$language] = $files.Count
            
            foreach ($item in $files) {
                $data = [File]::ReadAllBytes($item.FullName)
                $digest = Get-SHA256Hash -Data $data
                
                if ($known.ContainsKey($digest)) {
                    continue
                }
                
                $destination = Join-Path $target $item.Name
                if ((Test-Path $destination) -or (Get-Item $destination -Force).LinkType -eq "SymbolicLink") {
                    $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($item.Name)
                    $extension = [System.IO.Path]::GetExtension($item.Name)
                    $destination = Join-Path $target "$($fileNameWithoutExtension)__pool_$($digest)$($extension)"
                }
                
                try {
                    [File]::WriteAllBytes($destination, $data)
                }
                catch {
                    $existingItem = Get-Item $destination -Force
                    if (($existingItem.LinkType -eq "SymbolicLink") -or 
                        (-not (Test-Path $destination -PathType Leaf)) -or 
                        (Get-SHA256FileHash -Path $destination) -ne $digest) {
                        throw "Local abstraction conflict"
                    }
                }
                
                $known[$digest] = $true
            }
        }
        
        return @{
            Revision = $revision
            Counts = $counts
        }
    }
    finally {
        if (Test-Path $tempDir.FullName) {
            Remove-Item -Recurse -Force $tempDir.FullName
        }
    }
}

function Update-StatusCounts {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$Revision,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Counts
    )
    
    $text = [File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    $rows = @(
        "## Bestand"
        ""
        "GitHub-Stand: `$Revision$"
        ""
        "| Zielsprache | Dateien |"
        "|---|---:|"
    )
    
    foreach ($language in ($global:LANGUAGES | Sort-Object)) {
        $rows += "| $language | $($Counts[$language]) |"
    }
    
    $rows += "| **gesamt** | **$(($Counts.Values | Measure-Object -Sum).Sum)** |"
    $rows += ""
    $rows += ""
    
    $rowsText = $rows -join "`n"
    
    # Replace the section using regex
    $pattern = "(?ms)^## Bestand\n.*?(?=^## Quellen\n)"
    if ($text -match $pattern) {
        $updated = $text -replace $pattern, $rowsText
        [File]::WriteAllText($Path, $updated, [Text.Encoding]::UTF8)
    }
    else {
        throw "Status inventory section missing"
    }
}

function Add-ArtifactToQueue {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$State,
        
        [Parameter(Mandatory=$true)]
        [string]$Root,
        
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    $rootPath = Resolve-Path $Root
    $itemPath = Get-Item $Path -Force
    
    if ($itemPath.LinkType -eq "SymbolicLink") {
        throw "Artifact must not be a symlink"
    }
    
    $resolvedPath = Resolve-Path $Path
    $relative = Resolve-PathRelative -From $rootPath.Path -To $resolvedPath.Path
    
    if ($relative -ne "STATUS.md" -and ($relative.Split("\").Length -eq 0 -or 
        $global:LANGUAGES -notcontains $relative.Split("\")[0])) {
        throw "Artifact is outside a language directory"
    }
    
    if (-not $State.ContainsKey("ausstehende_veroeffentlichungen")) {
        $State["ausstehende_veroeffentlichungen"] = @{}
    }
    
    $fileContent = [File]::ReadAllBytes($Path)
    $hash = Get-SHA256Hash -Data $fileContent
    $State["ausstehende_veroeffentlichungen"][$relative] = $hash
}

function Resolve-PathRelative {
    param(
        [string]$From,
        [string]$To
    )
    
    $fromUri = New-Object Uri($From)
    $toUri = New-Object Uri($To)
    $relativeUri = $fromUri.MakeRelativeUri($toUri)
    return $relativeUri.ToString().Replace("/", "\")
}

function Publish-PendingArtifacts {
    <#
    .SYNOPSIS
    Publish queued artifacts to GitHub.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Root,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$State,
        
        [Parameter(Mandatory=$true)]
        [scriptblock]$Save,
        
        [string]$Token,
        
        [scriptblock]$Sync
    )
    
    $pending = $State.ContainsKey("ausstehende_veroeffentlichungen") ? $State["ausstehende_veroeffentlichungen"] : @{}
    
    if ($pending.GetType().Name -ne "Hashtable") {
        throw "Invalid publication queue"
    }
    
    if ($pending.Count -eq 0 -and $null -eq $Sync) {
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
    $entries = $pending.GetEnumerator() | Sort-Object { if ($_.Key -eq 'STATUS.md') { 0 } else { 1 } }
    $synced = $false
    
    foreach ($entry in $entries) {
        $name = $entry.Key
        $expected = $entry.Value
        
        try {
            $path = Join-Path $rootPath $name
            $item = Get-Item $path -Force
            
            if ($item.LinkType -eq "SymbolicLink" -or 
                (Resolve-PathRelative -From $rootPath.Path -To (Resolve-Path $path).Path) -ne $name) {
                throw "Invalid queued path"
            }
            
            $data = [File]::ReadAllBytes($path)
            if ((Get-SHA256Hash -Data $data) -ne $expected) {
                throw "Queued artifact changed"
            }
            
            if ($name -eq 'STATUS.md' -and $null -ne $Sync) {
                if (-not $success) {
                    throw "Artifact publication incomplete"
                }
                
                $syncResult = & $Sync $rootPath
                $synced = $true
                Update-StatusCounts -Path $path -Revision $syncResult.Revision -Counts $syncResult.Counts
                $data = [File]::ReadAllBytes($path)
                $expected = Get-SHA256Hash -Data $data
                $pending[$name] = $expected
                & $Save $State
            }
            
            function Lookup-RemoteFile {
                param(
                    [string]$RemoteName
                )
                
                $endpoint = "https://api.github.com/repos/KikiKari/OpenClaw/contents/$([Net.WebUtility]::UrlEncode($RemoteName))"
                $request = [Net.WebRequest]::Create("$endpoint?ref=gateway1-abstractions")
                
                foreach ($header in $headers.GetEnumerator()) {
                    $request.Headers.Add($header.Key, $header.Value)
                }
                
                try {
                    $response = $request.GetResponse()
                    try {
                        $stream = $response.GetResponseStream()
                        $reader = New-Object System.IO.StreamReader($stream)
                        $content = $reader.ReadToEnd()
                        return @{
                            Endpoint = $endpoint
                            Content = $content
                        }
                    }
                    finally {
                        $response.Close()
                    }
                }
                catch [Net.WebException] {
                    $webEx = $_.Exception
                    if ($webEx.Response -and $webEx.Response.StatusCode -eq 404) {
                        $webEx.Response.Close()
                        return @{
                            Endpoint = $endpoint
                            Content = $null
                        }
                    }
                    else {
                        throw
                    }
                }
            }
            
            function Test-SameContent {
                param(
                    [object]$Existing,
                    [byte[]]$Data
                )
                
                if ($null -eq $Existing.Content) {
                    return $false
                }
                
                try {
                    $json = ConvertFrom-Json $Existing.Content
                    if ($json.encoding -eq "base64") {
                        $decoded = [Convert]::FromBase64String($json.content)
                        return ,[byte[]]$decoded -join "," -eq ,[byte[]]$Data -join ","
                    }
                }
                catch {
                    return $false
                }
                
                return $false
            }
            
            $existing = Lookup-RemoteFile -RemoteName $name
            
            if ($name -eq 'STATUS.md' -and $null -ne $existing.Content -and -not (Test-SameContent -Existing $existing -Data $data)) {
                $json = ConvertFrom-Json $existing.Content
                $sha = $json.sha
                
                if ([string]::IsNullOrWhiteSpace($sha)) {
                    throw "Missing remote status version"
                }
                
                $body = @{
                    message = "Update abstraction status"
                    branch = "gateway1-abstractions"
                    content = [Convert]::ToBase64String($data)
                    sha = $sha
                } | ConvertTo-Json
                
                $request = [Net.WebRequest]::Create($existing.Endpoint)
                $request.Method = "PUT"
                
                foreach ($header in $headers.GetEnumerator()) {
                    $request.Headers.Add($header.Key, $header.Value)
                }
                
                $request.ContentType = "application/json"
                $bytes = [Text.Encoding]::UTF8.GetBytes($body)
                $request.ContentLength = $bytes.Length
                
                $requestStream = $request.GetRequestStream()
                $requestStream.Write($bytes, 0, $bytes.Length)
                $requestStream.Close()
                
                $response = $request.GetResponse()
                try {
                    $stream = $response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($stream)
                    $reader.ReadToEnd() | Out-Null
                }
                finally {
                    $response.Close()
                }
            }
            elseif ($null -ne $existing.Content -and -not (Test-SameContent -Existing $existing -Data $data)) {
                # Independent managers can derive different results for one
                # source. Preserve both without overwriting the remote file.
                $candidate = [System.IO.Path]::GetDirectoryName($name)
                if ([string]::IsNullOrEmpty($candidate)) {
                    $alternate = [System.IO.Path]::GetFileNameWithoutExtension($name) + "_" + $expected.Substring(0, 12) + [System.IO.Path]::GetExtension($name)
                }
                else {
                    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($name)
                    $extension = [System.IO.Path]::GetExtension($name)
                    $alternate = Join-Path $candidate "$($fileName)_$($expected.Substring(0, 12))$extension"
                }
                
                $existingAlt = Lookup-RemoteFile -RemoteName $alternate
                if ($null -ne $existingAlt.Content -and -not (Test-SameContent -Existing $existingAlt -Data $data)) {
                    throw "Remote artifact conflict"
                }
            }
            
            if ($null -eq $existing.Content) {
                $body = @{
                    message = "Publish script abstraction"
                    branch = "gateway1-abstractions"
                    content = [Convert]::ToBase64String($data)
                } | ConvertTo-Json
                
                $request = [Net.WebRequest]::Create($existing.Endpoint)
                $request.Method = "PUT"
                
                foreach ($header in $headers.GetEnumerator()) {
                    $request.Headers.Add($header.Key, $header.Value)
                }
                
                $request.ContentType = "application/json"
                $bytes = [Text.Encoding]::UTF8.GetBytes($body)
                $request.ContentLength = $bytes.Length
                
                $requestStream = $request.GetRequestStream()
                $requestStream.Write($bytes, 0, $bytes.Length)
                $requestStream.Close()
                
                $response = $request.GetResponse()
                try {
                    $stream = $response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($stream)
                    $reader.ReadToEnd() | Out-Null
                }
                finally {
                    $response.Close()
                }
            }
            
            $pending.Remove($name)
            & $Save $State
        }
        catch {
            $success = $false
        }
    }
    
    if ($null -ne $Sync -and -not $synced) {
        try {
            & $Sync $rootPath
        }
        catch {
            $success = $false
        }
    }
    
    return $success
}
